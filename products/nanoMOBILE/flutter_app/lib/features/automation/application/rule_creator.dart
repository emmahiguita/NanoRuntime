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
  }) {
    final rule = ScheduledRule(
      id: 'rule-${DateTime.now().millisecondsSinceEpoch}',
      trigger: trigger,
      action: action,
      message: message,
      dynamicReply: dynamicReply,
      createdAt: DateTime.now(),
    );
    _registry.add(rule);
    return rule;
  }
}

final ruleCreatorProvider = Provider<RuleCreator>(
  (ref) => RuleCreator(ref.watch(ruleRegistryProvider)),
);
