/// RuleDispatcher (T3.3) — ejecuta una regla matcheada vía el MISMO
/// AutomationCoordinator (nunca un agente paralelo).
///
/// Para `reply` construye un goal determinista GROUNDED en la notificación
/// (remitente factual + texto autorizado de la regla) y lo pasa al coordinator,
/// que ya tiene trust → candidate-first → governance → RemoteInput → verificación.
/// El destinatario NUNCA lo decide el LLM: sale de la notificación.
library;

import '../../domain/automation_goal.dart';
import '../../domain/automation_result.dart';
import '../notifications/notification_object.dart';
import 'scheduled_rule.dart';

enum RuleOutcome { notified, drafted, replied, failed }

class RuleDispatchResult {
  final String ruleId;
  final RuleOutcome outcome;

  /// Resultado del coordinator para `reply` (null en notify/draft/failed).
  final AutomationResult? automationResult;
  final String reason;

  const RuleDispatchResult({
    required this.ruleId,
    required this.outcome,
    this.automationResult,
    this.reason = '',
  });
}

class RuleDispatcher {
  RuleDispatcher(this._execute);

  /// Ejecuta un goal por el coordinator de producción (DIP: testeable).
  final Future<AutomationResult> Function(AutomationGoal goal) _execute;

  Future<RuleDispatchResult> dispatch(
    ScheduledRule rule,
    NotificationObject notif,
  ) async {
    switch (rule.action) {
      case RuleAction.notify:
        // T3.3: solo marca; la notificación local al usuario llega en T3.6.
        return RuleDispatchResult(ruleId: rule.id, outcome: RuleOutcome.notified);

      case RuleAction.draft:
        // T3.3: solo marca; el almacenamiento de borrador llega en T3.6.
        return RuleDispatchResult(ruleId: rule.id, outcome: RuleOutcome.drafted);

      case RuleAction.reply:
        if (rule.message.isEmpty) {
          return RuleDispatchResult(
            ruleId: rule.id,
            outcome: RuleOutcome.failed,
            reason: 'regla sin mensaje de respuesta',
          );
        }
        if (notif.sender.isEmpty) {
          return RuleDispatchResult(
            ruleId: rule.id,
            outcome: RuleOutcome.failed,
            reason: 'notificación sin remitente',
          );
        }
        final result = await _execute(
          AutomationGoal(text: 'responde a ${notif.sender} que ${rule.message}'),
        );
        final ok = result.status == AutomationResultStatus.completed ||
            result.status == AutomationResultStatus.completedUnverified;
        return RuleDispatchResult(
          ruleId: rule.id,
          outcome: ok ? RuleOutcome.replied : RuleOutcome.failed,
          automationResult: result,
          reason: result.reason,
        );
    }
  }
}
