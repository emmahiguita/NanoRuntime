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
import '../notifications/notification_draft_writer.dart'
    show NotificationDraftSource;
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

  /// Texto REAL que se intentó enviar (fijo de la regla o borrador LLM
  /// dinámico). Lo consume el pipeline para dedupe de eco y memoria honesta;
  /// vacío cuando no hubo texto (regla dinámica sin motor disponible).
  final String dispatchedText;

  const RuleDispatchResult({
    required this.ruleId,
    required this.outcome,
    this.automationResult,
    this.reason = '',
    this.dispatchedText = '',
  });

  /// true si la regla llegó a ejecutar un envío posiblemente irreversible
  /// (verificado, despachado sin verificar o con resultado desconocido).
  bool get isReplyAttempt =>
      outcome == RuleOutcome.replyVerified ||
      outcome == RuleOutcome.replyDispatchedUnverified ||
      outcome == RuleOutcome.outcomeUnknown;
}

class RuleDispatcher {
  RuleDispatcher(
    this._execute, {
    NotificationDraftSource? draftSource,
    Future<bool> Function(String title, String body)? notifyLocal,
  }) : _draftSource = draftSource,
       _notifyLocal = notifyLocal;

  /// Ejecuta un goal por el coordinator de producción (DIP: testeable).
  /// [options] transporta la autoridad standing de la regla (WA-AUTH-04).
  final Future<AutomationResult> Function(
    AutomationGoal goal, {
    AutomationOptions? options,
  })
  _execute;

  /// WA-AGENT-09 — redacción contextual para reglas reply dinámicas. null =
  /// sin motor: la regla dinámica falla honesta, jamás responde genérico.
  final NotificationDraftSource? _draftSource;

  /// NOTIFY-01 — aviso local real para RuleAction.notify. null = sin canal
  /// (tests): el outcome sigue siendo notified, sin efecto local.
  final Future<bool> Function(String title, String body)? _notifyLocal;

  /// TRIG-01 — ejecuta una regla SIN notificación entrante (triggers de hora
  /// y, a futuro, conectividad/batería). Sin remitente factual no hay reply
  /// posible: falla honesto, jamás responde a un destinatario inventado.
  Future<RuleDispatchResult> dispatchScheduled(ScheduledRule rule) async {
    switch (rule.action) {
      case RuleAction.notify:
        final notifyLocal = _notifyLocal;
        if (notifyLocal == null) {
          return RuleDispatchResult(
            ruleId: rule.id,
            outcome: RuleOutcome.notified,
          );
        }
        final body = rule.message.isEmpty
            ? 'La regla "${rule.id}" disparó a esta hora.'
            : rule.message;
        final ok = await notifyLocal('Nano: recordatorio', body);
        return RuleDispatchResult(
          ruleId: rule.id,
          outcome: ok ? RuleOutcome.notified : RuleOutcome.failed,
          reason: ok ? '' : 'el aviso local no se pudo publicar',
        );

      case RuleAction.draft:
        return RuleDispatchResult(
          ruleId: rule.id,
          outcome: RuleOutcome.drafted,
        );

      case RuleAction.reply:
        return RuleDispatchResult(
          ruleId: rule.id,
          outcome: RuleOutcome.failed,
          reason:
              'trigger por hora sin remitente — '
              'para responder usa un trigger de notificación',
        );
    }
  }

  Future<RuleDispatchResult> dispatch(
    ScheduledRule rule,
    NotificationObject notif,
  ) async {
    switch (rule.action) {
      case RuleAction.notify:
        final notifyLocal = _notifyLocal;
        if (notifyLocal == null) {
          return RuleDispatchResult(
            ruleId: rule.id,
            outcome: RuleOutcome.notified,
          );
        }
        final title = notif.sender.isEmpty
            ? 'Nano: mensaje nuevo'
            : 'Nano: ${notif.sender}';
        final body = notif.text.isEmpty
            ? 'Un mensaje activó la regla ${rule.id}.'
            : notif.text;
        final ok = await notifyLocal(title, body);
        return RuleDispatchResult(
          ruleId: rule.id,
          outcome: ok ? RuleOutcome.notified : RuleOutcome.failed,
          reason: ok ? '' : 'el aviso local no se pudo publicar',
        );

      case RuleAction.draft:
        // T3.3: solo marca; el almacenamiento de borrador llega en T3.6.
        return RuleDispatchResult(
          ruleId: rule.id,
          outcome: RuleOutcome.drafted,
        );

      case RuleAction.reply:
        if (notif.sender.isEmpty) {
          return RuleDispatchResult(
            ruleId: rule.id,
            outcome: RuleOutcome.failed,
            reason: 'notificación sin remitente',
          );
        }
        // WA-AGENT-09 — reply dinámico: la regla no fija texto; el motor
        // local redacta con el historial factual de la conversación. Sin
        // motor/borrador → failed honesto, jamás respuesta genérica.
        var text = rule.message;
        if (text.trim().isEmpty && rule.dynamicReply) {
          final draftSource = _draftSource;
          if (draftSource == null) {
            return RuleDispatchResult(
              ruleId: rule.id,
              outcome: RuleOutcome.failed,
              reason: 'regla dinámica sin motor de redacción disponible',
            );
          }
          final draft = await draftSource(notif);
          if (draft == null || draft.trim().isEmpty) {
            return RuleDispatchResult(
              ruleId: rule.id,
              outcome: RuleOutcome.failed,
              reason: 'regla dinámica: el motor local no produjo borrador',
            );
          }
          text = draft.trim();
        } else if (text.trim().isEmpty) {
          return RuleDispatchResult(
            ruleId: rule.id,
            outcome: RuleOutcome.failed,
            reason: 'regla sin mensaje de respuesta',
          );
        }
        final AutomationResult result;
        try {
          // WA-AUTH-04: la regla fue creada explícitamente por el usuario →
          // autoridad standing para su acción EXACTA (o su reply dinámico).
          // El coordinator/dispatcher solo la acepta si la llamada concreta
          // satisface tool+texto+paquete; si no, la confirmación humana
          // normal sigue igual.
          final authority = RuleExecutionAuthority.fromRule(rule);
          result = await _execute(
            AutomationGoal(text: 'responde a ${notif.sender} que $text'),
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
        return _replyOutcome(rule.id, result, dispatchedText: text);
    }
  }

  /// Mapeo honesto del estado del coordinator al outcome de la regla.
  RuleDispatchResult _replyOutcome(
    String ruleId,
    AutomationResult result, {
    String dispatchedText = '',
  }) {
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
      dispatchedText: dispatchedText,
    );
  }
}
