import 'package:flutter/foundation.dart' show debugPrint;

/// Process-local counters; no message content or contact identifiers.
abstract final class MessagingMetrics {
  static final Map<String, int> _counts = {
    for (final name in [
      'notificationsObserved',
      'notificationsEligible',
      'duplicatesDropped',
      'noiseDropped',
      'burstsCreated',
      'fragmentsPerBurst',
      'logicalTurns',
      'semanticLlmCalls',
      'draftsSuperseded',
      'draftsSent',
      'staleDraftsDropped',
      'maxQueueDepth',
      'lastBatchLatencyMs',
      'p95BatchLatencyMs',
    ])
      name: 0,
  };
  static final List<int> _latencies = [];

  static Map<String, int> get snapshot => Map.unmodifiable(_counts);
  static void increment(String name, [int amount = 1]) =>
      _counts[name] = (_counts[name] ?? 0) + amount;
  static void queueDepth(int depth) {
    if (depth > _counts['maxQueueDepth']!) _counts['maxQueueDepth'] = depth;
  }

  /// Calcula el percentil 95 (P95) de las últimas muestras de latencia en ms.
  static int get p95LatencyMs {
    if (_latencies.isEmpty) return 0;
    final sorted = List<int>.from(_latencies)..sort();
    final idx = ((sorted.length - 1) * 0.95).round();
    return sorted[idx];
  }

  /// Registra la latencia de una tanda procesada en ms.
  static void recordBatchLatency(int ms) {
    if (_latencies.length >= 100) _latencies.removeAt(0);
    _latencies.add(ms);
    _counts['lastBatchLatencyMs'] = ms;
    _counts['p95BatchLatencyMs'] = p95LatencyMs;
    emit();
  }

  static void turn(int fragments) {
    increment('burstsCreated');
    increment('logicalTurns');
    _counts['fragmentsPerBurst'] = fragments;
    emit();
  }

  static void superseded() {
    increment('draftsSuperseded');
    increment('staleDraftsDropped');
    emit();
  }

  static void emit() => debugPrint('[messaging-metrics] $_counts');
}
