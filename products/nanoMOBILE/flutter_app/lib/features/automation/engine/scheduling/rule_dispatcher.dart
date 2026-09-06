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
import '../messaging/conversation_key.dart' show resolveConversationIdentity;
import '../notifications/notification_draft_writer.dart'
    show NotificationDraftSource;
import '../notifications/notification_object.dart';
import 'scheduled_rule.dart';
import 'turn_supersede_guard.dart';

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

  /// WA-MEDIA-01 — WhatsApp se abrió con el archivo+contacto+caption.
  /// La actividad se LANZÓ; el tap final de envío es del usuario. No es un
  /// envío verificado.
  mediaLaunched,

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
    Future<bool> Function(String path, String contact, String caption)?
    shareMedia,
    TurnSupersedeGuard? supersedeGuard,
    Duration Function()? replyDelay,
  }) : _draftSource = draftSource,
       _notifyLocal = notifyLocal,
       _shareMedia = shareMedia,
       _supersedeGuard = supersedeGuard,
       _replyDelay = replyDelay;

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

  /// WA-MEDIA-01 — apertura real de WhatsApp con archivo. null = sin canal
  /// (tests): la regla media falla honesta, sin efecto local.
  final Future<bool> Function(String path, String contact, String caption)?
  _shareMedia;

  /// WA-CONV-03 — guard de supersede por conversación. null = sin puerta
  /// (tests/rutas legacy): el reply dinámico conserva el comportamiento
  /// histórico.
  final TurnSupersedeGuard? _supersedeGuard;

  /// WA-DELAY-01 — pausa "humana" antes del envío (closure en vivo sobre
  /// settings, como el estilo). null/zero = despacho inmediato. La pausa
  /// ocurre DESPUÉS del borrador y ANTES de la verificación supersede: si
  /// llega un mensaje nuevo durante la espera, el turno queda superado y el
  /// reply jamás se envía.
  final Duration Function()? _replyDelay;

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

      case RuleAction.sendMedia:
        // WA-MEDIA-01 — igual que reply: sin notificación entrante no hay
        // contacto factual. Jamás se envía a un destinatario inventado.
        return RuleDispatchResult(
          ruleId: rule.id,
          outcome: RuleOutcome.failed,
          reason:
              'trigger por hora sin remitente — '
              'para enviar un archivo usa un trigger de notificación',
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
        // WA-CONV-03 — versión de la conversación al empezar el reply: si
        // llega un mensaje nuevo mientras Nano redacta o antes de ejecutar,
        // el turno quedó superado y el draft viejo jamás se envía.
        final supersedeGuard = _supersedeGuard;
        final conversationVersion = supersedeGuard == null
            ? 0
            : supersedeGuard.versionOf(
                resolveConversationIdentity(notif).key.id,
              );
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
          if (supersedeGuard != null &&
              supersedeGuard.versionOf(
                    resolveConversationIdentity(notif).key.id,
                  ) !=
                  conversationVersion) {
            return RuleDispatchResult(
              ruleId: rule.id,
              outcome: RuleOutcome.failed,
              reason:
                  'turno superado: llegó un mensaje nuevo durante el borrador',
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
        // WA-DELAY-01 — pausa "humana" opcional. El borrador ya está listo;
        // se espera ANTES de la verificación supersede para que un mensaje
        // nuevo durante la espera descarte el reply (nunca se envía algo
        // superado). Sin guard → la pausa no invalida (rutas legacy).
        final replyDelay = _replyDelay;
        if (replyDelay != null) {
          final delay = replyDelay();
          if (delay > Duration.zero) {
            await Future<void>.delayed(delay);
          }
        }
        if (supersedeGuard != null &&
            supersedeGuard.versionOf(
                  resolveConversationIdentity(notif).key.id,
                ) !=
                conversationVersion) {
          return RuleDispatchResult(
            ruleId: rule.id,
            outcome: RuleOutcome.failed,
            reason: 'turno superado antes del envío',
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

      case RuleAction.sendMedia:
        // WA-MEDIA-01 — Camino A: abre WhatsApp con el archivo del catálogo,
        // el remitente FACTUAL de la notificación como contacto y el texto
        // de la regla como caption. El contacto nunca lo decide el LLM.
        final mediaPath = rule.mediaPath;
        if (mediaPath == null || mediaPath.trim().isEmpty) {
          return RuleDispatchResult(
            ruleId: rule.id,
            outcome: RuleOutcome.failed,
            reason: 'regla de archivo sin archivo adjunto',
          );
        }
        if (notif.sender.isEmpty) {
          return RuleDispatchResult(
            ruleId: rule.id,
            outcome: RuleOutcome.failed,
            reason: 'notificación sin remitente',
          );
        }
        final shareMedia = _shareMedia;
        if (shareMedia == null) {
          return RuleDispatchResult(
            ruleId: rule.id,
            outcome: RuleOutcome.failed,
            reason: 'sin canal de envío de archivos disponible',
          );
        }
        try {
          final launched = await shareMedia(
            mediaPath,
            notif.sender,
            rule.message,
          );
          return RuleDispatchResult(
            ruleId: rule.id,
            // Honesto: WhatsApp abierto ≠ archivo enviado. El tap final es
            // del usuario.
            outcome: launched
                ? RuleOutcome.mediaLaunched
                : RuleOutcome.failed,
            reason: launched ? '' : 'la app de destino no aceptó el archivo',
            dispatchedText: rule.message,
          );
        } catch (e) {
          return RuleDispatchResult(
            ruleId: rule.id,
            outcome: RuleOutcome.failed,
            reason: 'excepción en envío de archivo: $e',
          );
        }
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
