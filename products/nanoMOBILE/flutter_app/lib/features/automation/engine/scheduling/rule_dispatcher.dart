/// RuleDispatcher (T3.3 + WA-DEDUPE-03) — ejecuta una regla matcheada vía el
/// MISMO AutomationCoordinator (nunca un agente paralelo).
///
/// Para `reply` construye un goal determinista GROUNDED en la notificación
/// (remitente factual + texto autorizado de la regla) y lo pasa al coordinator,
/// que ya tiene trust → candidate-first → governance → RemoteInput → verificación.
/// El destinatario NUNCA lo decide el LLM: sale de la notificación.
///
/// Honestidad de outcomes: el estado refleja lo que el coordinator DEMOSTRÓ,
/// nunca lo que se esperaba:
/// - `completed` (objetivo verificado contra estado real) → [replyVerified].
/// - `completedUnverified` (RemoteInput aceptado, objetivo NO demostrado) →
///   [replyDispatchedUnverified], jamás "replied con éxito".
/// - `outcomeUnknown` (se agotó la espera; pudo aterrizar) → [outcomeUnknown];
///   el caller no reintenta a ciegas.
library;

import '../../domain/automation_goal.dart';
import '../../domain/automation_result.dart';
import '../governance/rule_execution_authority.dart';
import '../notifications/notification_object.dart';
import 'scheduled_rule.dart';

enum RuleOutcome {
  /// Acción notify completada (aviso local).
  notified,

  /// Acción draft preparada (sin envío).
  drafted,

  /// Reply VERIFICADO contra el estado real del objetivo.
  replyVerified,

  /// Reply despachado (RemoteInput aceptado) SIN verificación final del
  /// objetivo. No cuenta como éxito verificado.
  replyDispatchedUnverified,

  /// El caller agotó su espera; el envío pudo aterrizar o no. Nunca se
  /// reintenta a ciegas.
  outcomeUnknown,

  /// No se ejecutó: otra regla ya intentó responder a este evento.
  ignored,

  /// Falló sin efecto irreversible (ej. acción expirada, sin remitente).
  failed,
}

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

  /// true si la regla llegó a ejecutar un envío posiblemente irreversible
  /// (verificado, despachado sin verificar o con resultado desconocido).
  bool get isReplyAttempt =>
      outcome == RuleOutcome.replyVerified ||
      outcome == RuleOutcome.replyDispatchedUnverified ||
      outcome == RuleOutcome.outcomeUnknown;
}

class RuleDispatcher {
  RuleDispatcher(this._execute);

  /// Ejecuta un goal por el coordinator de producción (DIP: testeable).
  /// [options] transporta la autoridad standing de la regla (WA-AUTH-04).
  final Future<AutomationResult> Function(
    AutomationGoal goal, {
    AutomationOptions? options,
  })
  _execute;

  Future<RuleDispatchResult> dispatch(
    ScheduledRule rule,
    NotificationObject notif,
  ) async {
    switch (rule.action) {
      case RuleAction.notify:
        // T3.3: solo marca; la notificación local al usuario llega en T3.6.
        return RuleDispatchResult(
          ruleId: rule.id,
          outcome: RuleOutcome.notified,
        );

      case RuleAction.draft:
        // T3.3: solo marca; el almacenamiento de borrador llega en T3.6.
        return RuleDispatchResult(
          ruleId: rule.id,
          outcome: RuleOutcome.drafted,
        );

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
        final AutomationResult result;
        try {
          // WA-AUTH-04: la regla fue creada explícitamente por el usuario →
          // autoridad standing para su acción EXACTA. El coordinator/dispatcher
          // solo la acepta si la llamada concreta satisface tool+texto+paquete;
          // si no, la confirmación humana normal sigue igual.
          final authority = RuleExecutionAuthority.fromRule(rule);
          result = await _execute(
            AutomationGoal(
              text: 'responde a ${notif.sender} que ${rule.message}',
            ),
            options: authority == null
                ? null
                : AutomationOptions(authority: authority),
          );
        } catch (e) {
          return RuleDispatchResult(
            ruleId: rule.id,
            outcome: RuleOutcome.failed,
            reason: 'excepción en ejecución: $e',
          );
        }
        return _replyOutcome(rule.id, result);
    }
  }

  /// Mapeo honesto del estado del coordinator al outcome de la regla.
  RuleDispatchResult _replyOutcome(String ruleId, AutomationResult result) {
    final outcome = switch (result.status) {
      AutomationResultStatus.completed => RuleOutcome.replyVerified,
      AutomationResultStatus.completedUnverified =>
        RuleOutcome.replyDispatchedUnverified,
      AutomationResultStatus.outcomeUnknown => RuleOutcome.outcomeUnknown,
      // paused/denied/noPlan/cancelled: nada se envió (o el envío quedó
      // pendiente de confirmación humana). No es un aterrizaje.
      _ => RuleOutcome.failed,
    };
    return RuleDispatchResult(
      ruleId: ruleId,
      outcome: outcome,
      automationResult: result,
      reason: result.reason,
    );
  }
}
