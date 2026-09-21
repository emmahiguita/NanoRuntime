import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../../../../core/services/llm_engine_client.dart';

import 'reverse_agent_response.dart';

export 'reverse_agent_response.dart';

/// Cliente HTTP loopback para comunicarse con `reverse-agent-bridge` (SRP).
///
/// Permite delegar tareas a modelos web (Gemini, ChatGPT, DeepSeek, Claude)
/// que se ejecutan silenciosamente en segundo plano (headless con Playwright)
/// y devuelven la respuesta formateada directamente a Nano.
class ReverseAgentClient {
  final String baseUrl;
  final HttpClient Function()? _clientFactory;

  const ReverseAgentClient({
    this.baseUrl = 'http://127.0.0.1:8800',
    HttpClient Function()? clientFactory,
  }) : _clientFactory = clientFactory;

  HttpClient _createClient() {
    final factory = _clientFactory;
    final client = factory != null ? factory() : HttpClient();
    client.connectionTimeout = const Duration(seconds: 5);
    return client;
  }

  /// Verifica si el servidor del puente está activo y respondiendo.
  Future<bool> checkHealth() async {
    final client = _createClient();
    try {
      final uri = Uri.parse('$baseUrl/api/health');
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 3));
      final res = await req.close().timeout(const Duration(seconds: 3));
      if (res.statusCode != 200) return false;
      final body = await res.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['ok'] == true;
    } catch (_) {
      return false;
    } finally {
      client.close();
    }
  }

  /// Obtiene la lista de proveedores disponibles en el puente.
  Future<List<String>> getProviders() async {
    final client = _createClient();
    try {
      final uri = Uri.parse('$baseUrl/api/providers');
      final req = await client.getUrl(uri).timeout(const Duration(seconds: 5));
      final res = await req.close().timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return const [];
      final body = await res.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final list = data['providers'] as List<dynamic>?;
      return list?.map((e) => e.toString()).toList() ?? const [];
    } catch (_) {
      return const [];
    } finally {
      client.close();
    }
  }

  /// Inicia el proceso en segundo plano de `mobile_bridge.js` si está en Android y no responde.
  /// Previene procesos zombi terminando cualquier instancia huérfana anterior mediante su PID.
  Future<bool> ensureBridgeRunning() async {
    final healthy = await checkHealth();
    if (healthy) return true;

    if (!Platform.isAndroid) return false;

    try {
      const baseDir = '/data/data/dev.nanoai.mobile/files/nano';
      const nodeBin = '$baseDir/usr/bin/node';
      const bridgeJs = '$baseDir/home/mobile_bridge.js';
      const libDir = '$baseDir/usr/lib';
      final pidFile = File('$baseDir/tmp/mobile_bridge.pid');

      final scriptFile = File(bridgeJs);
      if (!scriptFile.existsSync()) return false;

      // Limpieza de procesos zombi previos si existían
      if (pidFile.existsSync()) {
        try {
          final oldPid = int.tryParse(pidFile.readAsStringSync().trim());
          if (oldPid != null && oldPid > 0) {
            Process.killPid(oldPid, ProcessSignal.sigkill);
          }
        } catch (_) {}
        try {
          pidFile.deleteSync();
        } catch (_) {}
      }

      final proc = await Process.start(
        nodeBin,
        [bridgeJs],
        environment: {'LD_LIBRARY_PATH': libDir},
        mode: ProcessStartMode.detached,
      );

      // Guardar PID del nuevo proceso supervisado
      try {
        if (!pidFile.parent.existsSync()) {
          pidFile.parent.createSync(recursive: true);
        }
        pidFile.writeAsStringSync('${proc.pid}');
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 1000));
      return await checkHealth();
    } catch (e) {
      debugPrint('[reverse_agent_client] Error iniciando mobile_bridge.js: $e');
      return false;
    }
  }

  /// Detiene el proceso del puente si fue iniciado previamente para evitar fugas de RAM.
  Future<void> stopBridge() async {
    const baseDir = '/data/data/dev.nanoai.mobile/files/nano';
    final pidFile = File('$baseDir/tmp/mobile_bridge.pid');
    if (pidFile.existsSync()) {
      try {
        final pid = int.tryParse(pidFile.readAsStringSync().trim());
        if (pid != null && pid > 0) {
          Process.killPid(pid, ProcessSignal.sigterm);
          await Future.delayed(const Duration(milliseconds: 200));
          Process.killPid(pid, ProcessSignal.sigkill);
        }
      } catch (_) {}
      try {
        pidFile.deleteSync();
      } catch (_) {}
    }
  }

  /// Consulta al modelo en el navegador en segundo plano (headless).
  Future<ReverseAgentResponse> query({
    required String provider,
    required String prompt,
    bool headless = true,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    // Intentar auto-iniciar el puente móvil si no está corriendo
    await ensureBridgeRunning();

    final client = _createClient();
    try {
      final uri = Uri.parse('$baseUrl/api/prompt');
      final req = await client
          .postUrl(uri)
          .timeout(const Duration(seconds: 10));
      req.headers.contentType = ContentType.json;

      final payload = jsonEncode({
        'provider': provider,
        'prompt': prompt,
        'headless': headless,
        'timeoutMs': timeout.inMilliseconds,
      });

      req.write(payload);
      final res = await req.close().timeout(timeout);
      final body = await res.transform(utf8.decoder).join();

      if (res.statusCode == 200) {
        final data = jsonDecode(body) as Map<String, dynamic>;
        return ReverseAgentResponse.fromJson(data);
      }

      final errorJson = jsonDecode(body) as Map<String, dynamic>?;
      final errorMsg =
          errorJson?['error'] as String? ?? 'HTTP ${res.statusCode}';
      return ReverseAgentResponse.failure(provider, errorMsg);
    } on TimeoutException {
      return ReverseAgentResponse.failure(
        provider,
        'Tiempo de espera agotado esperando la respuesta del navegador (${timeout.inSeconds}s).',
      );
    } on SocketException {
      // El servidor local no está activo → fallback a conocimiento web / síntesis (sin API key).
      return _queryFallback(provider: provider, prompt: prompt);
    } catch (e) {
      return ReverseAgentResponse.failure(
        provider,
        'Error de comunicación con el puente de navegación: $e',
      );
    } finally {
      client.close();
    }
  }

  /// Fallback hacia el motor LLM local honesto cuando el puente de navegador no está activo.
  Future<ReverseAgentResponse> _queryFallback({
    required String provider,
    required String prompt,
  }) async {
    // 1. Intentar Motor IA Local en el propio dispositivo Android (GGUF / nanortime)
    try {
      final localClient = LLMEngineClient();
      final isOnline = await localClient.isOnline(
        attempts: 1,
        requestTimeout: const Duration(seconds: 2),
      );
      if (isOnline) {
        final formattedPrompt =
            'System: Responde la siguiente consulta de forma clara, directa y concisa en español.\n\nUser: $prompt\n\nAssistant:';
        final localResult = await localClient.generate(
          prompt: formattedPrompt,
          maxTokens: 512,
        );
        final cleanText = localResult.text.trim();
        if (cleanText.isNotEmpty) {
          return ReverseAgentResponse(
            ok: true,
            provider: 'local_llm',
            response: cleanText,
            source: 'llm_local',
            requestedProvider: provider,
            actualProvider: 'qwen2.5-local',
            actualBackend: 'local_llm',
          );
        }
      }
    } catch (e) {
      debugPrint('[reverse_agent_client] error en motor local LLM: $e');
    }

    // 2. Si el motor local no está disponible o falla, declarar honestamente la falla sin simulación.
    return ReverseAgentResponse.failure(
      provider,
      'El puente de navegación no está disponible en 127.0.0.1:8800 y el motor local no pudo responder.',
      actualBackend: 'none',
    );
  }
}
