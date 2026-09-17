import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../../../../core/services/llm_engine_client.dart';

/// Respuesta tipada devuelta por el puente de agentes de navegación.
class ReverseAgentResponse {
  final bool ok;
  final String provider;
  final String response;
  final String? error;
  final String source;
  final String requestedProvider;
  final String actualProvider;
  final String actualBackend;

  const ReverseAgentResponse({
    required this.ok,
    required this.provider,
    required this.response,
    this.error,
    this.source = 'bridge',
    this.requestedProvider = '',
    this.actualProvider = '',
    this.actualBackend = 'remote_provider',
  });

  factory ReverseAgentResponse.failure(
    String provider,
    String error, {
    String actualBackend = 'none',
  }) {
    return ReverseAgentResponse(
      ok: false,
      provider: provider,
      response: '',
      error: error,
      source: 'error',
      requestedProvider: provider,
      actualProvider: '',
      actualBackend: actualBackend,
    );
  }

  factory ReverseAgentResponse.fromJson(Map<String, dynamic> json) {
    final prov = json['provider'] as String? ?? 'unknown';
    return ReverseAgentResponse(
      ok: json['ok'] == true,
      provider: prov,
      response: json['response'] as String? ?? '',
      error: json['error'] as String?,
      source: json['source'] as String? ?? 'bridge',
      requestedProvider: json['requested_provider'] as String? ?? prov,
      actualProvider: json['actual_provider'] as String? ?? prov,
      actualBackend: json['actual_backend'] as String? ?? 'remote_provider',
    );
  }
}

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
  Future<bool> ensureBridgeRunning() async {
    final healthy = await checkHealth();
    if (healthy) return true;

    if (!Platform.isAndroid) return false;

    try {
      const baseDir = '/data/data/dev.nanoai.mobile/files/nano';
      const nodeBin = '$baseDir/usr/bin/node';
      const bridgeJs = '$baseDir/home/mobile_bridge.js';
      const libDir = '$baseDir/usr/lib';

      final scriptFile = File(bridgeJs);
      if (!scriptFile.existsSync()) return false;

      await Process.start(
        nodeBin,
        [bridgeJs],
        environment: {'LD_LIBRARY_PATH': libDir},
        mode: ProcessStartMode.detached,
      );

      await Future.delayed(const Duration(milliseconds: 1000));
      return await checkHealth();
    } catch (e) {
      debugPrint('[reverse_agent_client] Error iniciando mobile_bridge.js: $e');
      return false;
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
