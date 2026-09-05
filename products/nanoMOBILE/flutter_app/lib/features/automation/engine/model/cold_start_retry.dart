/// Retry único honesto para arranque en frío del motor local.
///
/// La primera llamada tras arrancar el motor devuelve a veces texto vacío en
/// ~45ms (warm-up, evidencia WA-PHYS-EMM): un reintento convierte ese fallo
/// en respuesta real. Solo se reintenta si la salida fue vacía Y rápida
/// (< [threshold]): vacío tras generación larga = fallo honesto, no frío.
/// Las excepciones NO se reintentan aquí — las maneja cada consumidor.
/// [sessionId] pasa a las dos llamadas (KV cache por conversación,
/// WA-CONVERSATION-01): el retry conserva la sesión del borrador.
library;

import 'package:flutter/foundation.dart';

import '../../../../core/services/llm_engine_client.dart'
    show LLMEngineClient;

Future<String> generateWithColdRetry(
  LLMEngineClient client, {
  required String prompt,
  required double temperature,
  required int maxTokens,
  String? sessionId,
  Duration threshold = const Duration(seconds: 3),
}) async {
  final stopwatch = Stopwatch()..start();
  final first = await client.generate(
    prompt: prompt,
    temperature: temperature,
    maxTokens: maxTokens,
    sessionId: sessionId,
  );
  final firstText = first.text.trim();
  if (firstText.isNotEmpty || stopwatch.elapsed >= threshold) {
    return firstText;
  }
  debugPrint('[draft] reintento por arranque en frío');
  final second = await client.generate(
    prompt: prompt,
    temperature: temperature,
    maxTokens: maxTokens,
    sessionId: sessionId,
  );
  return second.text.trim();
}
