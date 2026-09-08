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
    ])
      name: 0,
  };
  static Map<String, int> get snapshot => Map.unmodifiable(_counts);
  static void increment(String name, [int amount = 1]) =>
      _counts[name] = (_counts[name] ?? 0) + amount;
  static void queueDepth(int depth) {
    if (depth > _counts['maxQueueDepth']!) _counts['maxQueueDepth'] = depth;
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
