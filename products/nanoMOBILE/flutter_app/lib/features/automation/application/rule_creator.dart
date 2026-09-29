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
    List<ScheduledMessageRecipient> recipients = const [],
  }) {
    for (final existing in _registry.rules) {
      if (existing.action == action &&
          existing.message == message &&
          existing.dynamicReply == dynamicReply &&
          existing.mediaPath == mediaPath &&
          _sameRecipients(existing.recipients, recipients) &&
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
      recipients: List.unmodifiable(recipients),
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
          a.timeZoneId == b.timeZoneId &&
          a.recurring == b.recurring &&
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

  static bool _sameRecipients(
    List<ScheduledMessageRecipient> a,
    List<ScheduledMessageRecipient> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].number != b[i].number || a[i].name != b[i].name) return false;
    }
    return true;
  }
}

final ruleCreatorProvider = Provider<RuleCreator>(
  (ref) => RuleCreator(ref.watch(ruleRegistryProvider)),
);
