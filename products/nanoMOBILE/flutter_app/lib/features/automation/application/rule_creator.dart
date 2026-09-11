import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/scheduling/rule_registry.dart';
import '../engine/scheduling/scheduled_rule.dart';
import '../engine/scheduling/trigger.dart';
import 'automation_coordinator_provider.dart';

/// RuleCreator (RULES-CREATE-02) — caso de uso único de creación de reglas.
///
/// Genera id/createdAt y persiste en el MISMO [RuleRegistry] que consulta el
/// pipeline: una sola fuente de construcción. Consumido por la pantalla
/// Reglas (lenguaje natural vía TriggerParser) y por el acceso "Por hora" del
/// dashboard (hora elegida en picker) — cero lógica duplicada de creación.
class RuleCreator {
  RuleCreator(this._registry);

  final RuleRegistry _registry;

  ScheduledRule create({
    required Trigger trigger,
    required RuleAction action,
    String message = '',
    bool dynamicReply = false,
    String? mediaPath,
  }) {
    for (final existing in _registry.rules) {
      if (existing.action == action &&
          existing.message == message &&
          existing.dynamicReply == dynamicReply &&
          existing.mediaPath == mediaPath &&
          _sameTrigger(existing.trigger, trigger)) {
        if (!existing.enabled) {
          _registry.setEnabled(existing.id, true);
        }
        return existing;
      }
    }

    final rule = ScheduledRule(
      id: 'rule-${DateTime.now().millisecondsSinceEpoch}',
      trigger: trigger,
      action: action,
      message: message,
      dynamicReply: dynamicReply,
      mediaPath: mediaPath,
      createdAt: DateTime.now(),
    );
    _registry.add(rule);
    return rule;
  }

  static bool _sameTrigger(Trigger a, Trigger b) {
    if (a.runtimeType != b.runtimeType) return false;
    if (a is TimeTrigger && b is TimeTrigger) {
      return a.hour == b.hour &&
          a.minute == b.minute &&
          a.weekdays.length == b.weekdays.length &&
          a.weekdays.containsAll(b.weekdays);
    }
    if (a is NotificationTrigger && b is NotificationTrigger) {
      return a.packageName == b.packageName &&
          a.senderMatch == b.senderMatch &&
          a.textMatch == b.textMatch;
    }
    return false;
  }
}

final ruleCreatorProvider = Provider<RuleCreator>(
  (ref) => RuleCreator(ref.watch(ruleRegistryProvider)),
);
