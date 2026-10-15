/// LOOP-1-TELEMETRY — registro por turno de inferencia, SIN PII.
///
/// Mide qué consume cada turno antes de tocar comportamiento (LOOP 1 del
/// plan Nano Personal V2): hash corto de conversación, request_id,
/// timestamps (queue/inference/cancel), prompt chars, tokens reales si el
/// motor los reporta (si no, estimación conservadora chars/3.5),
/// prefill_ms/decode_ms, queue_wait_ms, superseded y used/discarded.
///
/// Jamás se registra texto de mensajes, respuestas, nombres, teléfonos,
/// cookies ni tokens de sesión. Proceso-local (muere con el engine) igual
/// que [MessagingMetrics]; ring buffer acotado.
library;

import 'package:flutter/foundation.dart' show debugPrint;

/// Muestra inmutable de un turno de inferencia.
final class InferenceTurnSample {
  final String conversationHash;
  final String requestId;
  final int promptChars;
  final int historyEntries;
  final int queuedAtMs;
  final int inferenceStartMs;
  final int inferenceEndMs;
  final int prefillMs;
  final int decodeMs;
  final int generatedTokens;
  final int queueWaitMs;
  final int cancelRequestedAtMs;
  final int cancelCompletedAtMs;
  final bool superseded;
  final bool resultUsed;

  const InferenceTurnSample({
    required this.conversationHash,
    required this.requestId,
    required this.promptChars,
    required this.historyEntries,
    required this.queuedAtMs,
    required this.inferenceStartMs,
    required this.inferenceEndMs,
    required this.prefillMs,
    required this.decodeMs,
    required this.generatedTokens,
    required this.queueWaitMs,
    required this.cancelRequestedAtMs,
    required this.cancelCompletedAtMs,
    required this.superseded,
    required this.resultUsed,
  });

  int get totalMs =>
      inferenceEndMs > inferenceStartMs ? inferenceEndMs - inferenceStartMs : 0;

  /// Tokens reales si el motor los reportó; si no, estimación conservadora.
  int get estimatedPromptTokens => (promptChars / 3.5).ceil();
}

/// Registro process-local de telemetría de inferencia (sin contenido).
abstract final class InferenceTelemetry {
  static const int _maxSamples = 200;
  static final List<InferenceTurnSample> _samples = [];
  static final Map<String, int> _counts = {
    for (final name in [
      'samples',
      'cancellations',
      'superseded',
      'discarded',
      'used',
    ])
      name: 0,
  };
  static final Map<String, int> _pending = {}; // requestId -> queuedAtMs

  static void begin({
    required String conversationId,
    required String requestId,
    required int promptChars,
    required int historyEntries,
    required int queuedAtMs,
  }) {
    final hash = conversationId.isEmpty
        ? '-'
        : conversationId.hashCode.toRadixString(16).padLeft(8, '0');
    _pending[requestId] = queuedAtMs;
    _samples.add(
      InferenceTurnSample(
        conversationHash: hash,
        requestId: requestId,
        promptChars: promptChars,
        historyEntries: historyEntries,
        queuedAtMs: queuedAtMs,
        inferenceStartMs: DateTime.now().millisecondsSinceEpoch,
        inferenceEndMs: 0,
        prefillMs: 0,
        decodeMs: 0,
        generatedTokens: 0,
        queueWaitMs: 0,
        cancelRequestedAtMs: 0,
        cancelCompletedAtMs: 0,
        superseded: false,
        resultUsed: false,
      ),
    );
    _counts['samples'] = (_counts['samples'] ?? 0) + 1;
    _trim();
  }

  static void complete({
    required String requestId,
    int prefillMs = 0,
    int decodeMs = 0,
    int generatedTokens = 0,
  }) {
    final queuedAt = _pending.remove(requestId);
    final idx = _indexOf(requestId);
    if (idx < 0) return;
    final prev = _samples[idx];
    final now = DateTime.now().millisecondsSinceEpoch;
    final queueWait = queuedAt != null && prev.inferenceStartMs > queuedAt
        ? prev.inferenceStartMs - queuedAt
        : 0;
    final completed = _with(
      prev,
      inferenceEndMs: now,
      prefillMs: prefillMs,
      decodeMs: decodeMs,
      generatedTokens: generatedTokens,
      queueWaitMs: queueWait,
    );
    _samples[idx] = completed;
    debugPrint(
      '[inf-telemetry] end req=${prev.requestId.substring(0, 10)} '
      'conv=${prev.conversationHash} total=${completed.totalMs}ms '
      'prefill=$prefillMs decode=$decodeMs queueWait=$queueWait '
      'gen=$generatedTokens chars=${prev.promptChars} '
      'estTok=${prev.estimatedPromptTokens}',
    );
  }

  static void markCancelRequested(String requestId) {
    final idx = _indexOf(requestId);
    if (idx < 0) return;
    _samples[idx] = _with(
      _samples[idx],
      cancelRequestedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _counts['cancellations'] = (_counts['cancellations'] ?? 0) + 1;
  }

  static void markCancelCompleted(String requestId) {
    final idx = _indexOf(requestId);
    if (idx < 0) return;
    final prev = _samples[idx];
    _samples[idx] = _with(
      prev,
      cancelRequestedAtMs: prev.cancelRequestedAtMs,
      cancelCompletedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static void markSuperseded(String requestId) {
    // Cuenta SIEMPRE: un turno coalescido antes de inferir no tiene
    // requestId pero igual es trabajo evitado.
    _counts['superseded'] = (_counts['superseded'] ?? 0) + 1;
    final idx = _indexOf(requestId);
    if (idx < 0) return;
    _samples[idx] = _with(_samples[idx], superseded: true);
  }

  static void markUsed(String requestId) {
    final idx = _indexOf(requestId);
    if (idx < 0) return;
    _samples[idx] = _with(_samples[idx], resultUsed: true);
    _counts['used'] = (_counts['used'] ?? 0) + 1;
  }

  static void markDiscarded(String requestId) {
    _counts['discarded'] = (_counts['discarded'] ?? 0) + 1;
  }

  /// Resumen agregado sin contenido (para load tests LOOP 13-15).
  static Map<String, int> summary() {
    if (_samples.isEmpty) return const {};
    int p(List<int> values, double q) {
      final sorted = List<int>.from(values)..sort();
      return sorted.isEmpty ? 0 : sorted[((sorted.length - 1) * q).round()];
    }

    final totals = _samples.map((s) => s.totalMs).where((t) => t > 0).toList();
    final prefills = _samples
        .map((s) => s.prefillMs)
        .where((t) => t > 0)
        .toList();
    final decodes = _samples
        .map((s) => s.decodeMs)
        .where((t) => t > 0)
        .toList();
    final waits = _samples
        .map((s) => s.queueWaitMs)
        .where((t) => t > 0)
        .toList();
    final chars = _samples
        .map((s) => s.promptChars)
        .where((t) => t > 0)
        .toList();
    int avg(List<int> values) =>
        values.isEmpty ? 0 : values.reduce((a, b) => a + b) ~/ values.length;
    return {
      'samples': _samples.length,
      'avgPromptChars': avg(chars),
      'avgTotalMs': avg(totals),
      'p50TotalMs': p(totals, 0.5),
      'p95TotalMs': p(totals, 0.95),
      'avgPrefillMs': avg(prefills),
      'avgDecodeMs': avg(decodes),
      'avgQueueWaitMs': avg(waits),
      'cancellations': _counts['cancellations'] ?? 0,
      'superseded': _counts['superseded'] ?? 0,
      'used': _counts['used'] ?? 0,
      'discarded': _counts['discarded'] ?? 0,
    };
  }

  static void reset() {
    _samples.clear();
    _pending.clear();
    for (final k in _counts.keys.toList()) {
      _counts[k] = 0;
    }
  }

  static int _indexOf(String requestId) =>
      _samples.indexWhere((s) => s.requestId == requestId);

  static InferenceTurnSample _with(
    InferenceTurnSample s, {
    int? inferenceEndMs,
    int? prefillMs,
    int? decodeMs,
    int? generatedTokens,
    int? queueWaitMs,
    int? cancelRequestedAtMs,
    int? cancelCompletedAtMs,
    bool? superseded,
    bool? resultUsed,
  }) => InferenceTurnSample(
    conversationHash: s.conversationHash,
    requestId: s.requestId,
    promptChars: s.promptChars,
    historyEntries: s.historyEntries,
    queuedAtMs: s.queuedAtMs,
    inferenceStartMs: s.inferenceStartMs,
    inferenceEndMs: inferenceEndMs ?? s.inferenceEndMs,
    prefillMs: prefillMs ?? s.prefillMs,
    decodeMs: decodeMs ?? s.decodeMs,
    generatedTokens: generatedTokens ?? s.generatedTokens,
    queueWaitMs: queueWaitMs ?? s.queueWaitMs,
    cancelRequestedAtMs: cancelRequestedAtMs ?? s.cancelRequestedAtMs,
    cancelCompletedAtMs: cancelCompletedAtMs ?? s.cancelCompletedAtMs,
    superseded: superseded ?? s.superseded,
    resultUsed: resultUsed ?? s.resultUsed,
  );

  static void _trim() {
    while (_samples.length > _maxSamples) {
      _samples.removeAt(0);
    }
  }
}
