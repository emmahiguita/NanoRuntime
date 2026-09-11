/// RuleEngine (T3.2) — matchea eventos contra reglas habilitadas. Puro, 0 LLM.
///
/// Reusa [evaluateTrigger]: el matching por remitente/paquete es determinista y
/// factual (viene de la notificación), nunca una decisión del modelo.
library;

import 'scheduled_rule.dart';
import 'trigger.dart';

class RuleEngine {
  const RuleEngine();

  /// Reglas habilitadas cuyo trigger dispara con [event].
  /// Ordenadas por especificidad: reglas con remitente/texto explícito van primero;
  /// las reglas universales o genéricas (sin filtro de remitente/texto) van al final.
  List<ScheduledRule> match(List<ScheduledRule> rules, TriggerEvent event) {
    final matched = <ScheduledRule>[
      for (final r in rules)
        if (r.enabled && evaluateTrigger(r.trigger, event)) r,
    ];

    matched.sort((a, b) => _specificity(b.trigger).compareTo(_specificity(a.trigger)));
    return matched;
  }

  static int _specificity(Trigger trigger) {
    if (trigger is NotificationTrigger) {
      var score = 0;
      if (trigger.packageName != null && trigger.packageName!.isNotEmpty) {
        score += 1;
      }
      if (trigger.senderMatch != null && trigger.senderMatch!.isNotEmpty) {
        score += 4;
      }
      if (trigger.textMatch != null && trigger.textMatch!.isNotEmpty) {
        score += 4;
      }
      return score;
    }
    if (trigger is TimeTrigger) {
      return 5;
    }
    return 0;
  }
}
