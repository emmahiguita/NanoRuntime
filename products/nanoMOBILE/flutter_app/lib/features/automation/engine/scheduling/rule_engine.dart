/// RuleEngine (T3.2) — matchea eventos contra reglas habilitadas. Puro, 0 LLM.
///
/// Reusa [evaluateTrigger]: el matching por remitente/paquete es determinista y
/// factual (viene de la notificación), nunca una decisión del modelo.
library;

import 'scheduled_rule.dart';
import 'trigger.dart';

class RuleEngine {
  const RuleEngine();

  /// Reglas habilitadas cuyo trigger dispara con [event] (en orden de registro).
  List<ScheduledRule> match(List<ScheduledRule> rules, TriggerEvent event) {
    return [
      for (final r in rules)
        if (r.enabled && evaluateTrigger(r.trigger, event)) r,
    ];
  }
}
