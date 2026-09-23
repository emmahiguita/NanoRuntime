// reverse_agent_client.dart
//
// QUÉ HACE:
// Cliente HTTP loopback para consultar modelos en navegadores headless a través de `mobile_bridge.js`,
// con fallback al motor LLM local honesto cuando el puente no está disponible.
//
// CÓMO FUNCIONA:
// - Supervisa el proceso mediante `MobileBridgeProcessSupervisor` para asegurar que el puente corra.
// - Realiza peticiones POST a `/api/prompt` y procesa la respuesta devuelta por los proveedores web.
// - Provee métodos explícitos para comprobar salud (`checkHealth`) y detener el puente (`stopBridge`).
//
// POR QUÉ:
// Mantiene desacoplada la comunicación HTTP del ciclo de vida del subproceso (SOLID - SRP),
// previene procesos zombi y respeta estrictamente el límite de 200 líneas.

library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import '../../../../core/services/llm_engine_client.dart';
import 'mobile_bridge_process_supervisor.dart';
import 'reverse_agent_response.dart';

export 'reverse_agent_response.dart';

/// Cliente HTTP loopback para comunicarse con `reverse-agent-bridge`.
class ReverseAgentClient {
  final String baseUrl;
  final HttpClient Function()? _clientFactory;
  final MobileBridgeProcessSupervisor _supervisor;

  const ReverseAgentClient({
    this.baseUrl = 'http://127.0.0.1:8800',
    HttpClient Function()? clientFactory,
    MobileBridgeProcessSupervisor supervisor = const MobileBridgeProcessSupervisor(),
  })  : _clientFactory = clientFactory,
        _supervisor = supervisor;

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

  /// Inicia el subproceso supervisado si está en Android y aún no responde.
  Future<bool> ensureBridgeRunning() => _supervisor.ensureRunning(checkHealth);

  /// Detiene el proceso del puente de forma segura para evitar procesos huérfanos.
  Future<void> stopBridge() => _supervisor.stop();

  /// Consulta al modelo en el navegador en segundo plano (headless).
  Future<ReverseAgentResponse> query({
    required String provider,
    required String prompt,
    bool headless = true,
    Duration timeout = const Duration(minutes: 3),
  }) async {
    await ensureBridgeRunning();

    final client = _createClient();
    try {
      final uri = Uri.parse('$baseUrl/api/prompt');
      final req = await client.postUrl(uri).timeout(const Duration(seconds: 10));
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
      final errorMsg = errorJson?['error'] as String? ?? 'HTTP ${res.statusCode}';
      return ReverseAgentResponse.failure(provider, errorMsg);
    } on TimeoutException {
      return ReverseAgentResponse.failure(
        provider,
        'Tiempo de espera agotado esperando la respuesta del navegador (${timeout.inSeconds}s).',
      );
    } on SocketException {
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

  /// Fallback hacia el motor LLM local cuando el puente de navegador no está activo.
  Future<ReverseAgentResponse> _queryFallback({
    required String provider,
    required String prompt,
  }) async {
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

    return ReverseAgentResponse.failure(
      provider,
      'El puente de navegación no está disponible en 127.0.0.1:8800 y el motor local no pudo responder.',
      actualBackend: 'none',
    );
  }
}
