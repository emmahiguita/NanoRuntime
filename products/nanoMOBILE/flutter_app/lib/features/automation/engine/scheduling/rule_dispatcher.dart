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

import 'package:flutter/foundation.dart' show debugPrint;

import '../../domain/automation_goal.dart';
import '../../domain/automation_result.dart';
import '../../personal_agent/application/conversation_decision_engine.dart';
import '../../personal_agent/domain/conversation_decision.dart';
import '../governance/rule_execution_authority.dart';
import '../language/language_assist.dart' show LanguageAssistService;
import '../language/pragmatic_fast_path.dart' show PragmaticFastPath;
import '../messaging/conversation_key.dart'
    show resolveConversationIdentity, ConversationIdentity;
import '../notifications/conversation_understanding.dart';
import '../notifications/notification_draft_writer.dart'
    show NotificationDraftSource;
import '../notifications/notification_object.dart';
import 'scheduled_rule.dart';
import '../messaging/reply_capability.dart';
import '../messaging/incoming_message.dart';
import '../../personal_agent/domain/conversation_autonomy_mode.dart';
import 'messaging_metrics.dart';
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
    // PERSONA-DECISION-02 — decisión determinista antes de despachar un
    // draft dinámico. null = sin motor de decisión (rutas legacy/tests):
    // el reply conserva el comportamiento histórico.
    ConversationDecisionEngine? decisionEngine,
    // Contexto de la decisión por notificación (PERSONA-HANDOFF-03 lo
    // alimentará con el ownership durable). null = contexto por defecto.
    ConversationDecisionContext Function(NotificationObject)? decisionContext,
    // A07/A09 — fast path pragmático: speech acts triviales sin LLM. null =
    // rutas legacy/tests: siempre LLM (paridad histórica).
    PragmaticFastPath? fastPath,
    // A12 — política térmica: estado PowerManager leído justo antes de la
    // inferencia; severe+ suprime el LLM (jamás la seguridad). null = rutas
    // legacy/tests sin gate térmico.
    Future<int> Function()? thermalStatus,
  }) : _draftSource = draftSource,
       _notifyLocal = notifyLocal,
       _shareMedia = shareMedia,
       _supersedeGuard = supersedeGuard,
       _replyDelay = replyDelay,
       _decisionEngine = decisionEngine,
       _decisionContext = decisionContext,
       _fastPath = fastPath,
       _thermalStatus = thermalStatus;

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

  /// PERSONA-DECISION-02 — motor de decisión determinista (señales
  /// verificables, jamás confianza del LLM). null = rutas legacy sin
  /// decisión (paridad histórica).
  final ConversationDecisionEngine? _decisionEngine;

  /// PERSONA-HANDOFF-03 — contexto de decisión por notificación (ownership
  /// durable). null = contexto por defecto.
  final ConversationDecisionContext Function(NotificationObject)?
  _decisionContext;

  /// A07 — fast path pragmático (saludo/agradecimiento puros sin LLM).
  final PragmaticFastPath? _fastPath;

  /// A12 — estado térmico del sistema; severe+ suprime la inferencia.
  final Future<int> Function()? _thermalStatus;

  /// Constante Android THERMAL_STATUS_CRITICAL: de aquí para arriba el LLM
  /// queda suprimido para proteger el dispositivo (4 = CRITICAL, 5 = EMERGENCY).
  static const _thermalSevere = 4;

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
    NotificationObject notif, {
    int? capturedConversationVersion,
    bool Function()? isStillAllowed,
  }) async {
    bool permitsSideEffect() {
      if (notif.isTruncated) return false;
      if (!(isStillAllowed?.call() ?? true)) return false;
      final context = _decisionContext?.call(notif);
      if (context == null) return true; // Standalone callers retain governance.
      return !context.humanOwnsConversation &&
          context.autonomyMode != ConversationAutonomyMode.disabled &&
          context.autonomyMode != ConversationAutonomyMode.suggestions &&
          context.identityConfidence >=
              ConversationIdentity.safeToWriteThreshold;
    }

    if ((rule.action == RuleAction.reply ||
            rule.action == RuleAction.sendMedia) &&
        !permitsSideEffect()) {
      return RuleDispatchResult(
        ruleId: rule.id,
        outcome: RuleOutcome.ignored,
        reason: 'regla, autonomía, identidad u ownership no permite envío',
      );
    }
    if (capturedConversationVersion != null &&
        _supersedeGuard != null &&
        _supersedeGuard.versionOf(resolveConversationIdentity(notif).key.id) !=
            capturedConversationVersion) {
      return RuleDispatchResult(
        ruleId: rule.id,
        outcome: RuleOutcome.ignored,
        reason: 'turno superado antes de ejecutar la regla',
      );
    }
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
        final conversationId = resolveConversationIdentity(notif).key.id;
        final conversationVersion =
            capturedConversationVersion ??
            supersedeGuard?.versionOf(conversationId) ??
            0;
        // P1-FIX — traza TEMPORAL del invariante 1 INPUT = 1 TURN: un input
        // lógico abre UN turno con su event/key/versión; las trazas de draft,
        // decision y dispatch cuelgan de este par input+version.
        debugPrint(
          '[turn] conv=${_shortId(conversationId)} '
          'input="${_sample(notif.text)}" event=${notif.key} '
          'version=$conversationVersion',
        );
        // WA-AGENT-09 — reply dinámico: la regla no fija texto; el motor
        // local redacta con el historial factual de la conversación. Sin
        // motor/borrador → failed honesto, jamás respuesta genérica.
        var text = rule.message;
        if (text.trim().isEmpty && rule.dynamicReply) {
          final draftSource = _draftSource;
          final decisionEngine = _decisionEngine;
          final ConversationUnderstanding understanding;

          // A07/A09 — fast path determinista ANTES del LLM: speech act
          // trivial de alta confianza sin referente (saludo/agradecimiento
          // puros). El reply determinista pasa IGUAL por la decisión
          // (eco, call-center, wrong-turn...): no es autoridad propia.
          final fast = await _fastPath?.resolve(
            text: notif.text,
            conversationId: conversationId,
          );
          if (fast != null) {
            text = fast.reply;
            understanding = fast.understanding;
            debugPrint(
              '[fastpath] conv=${_shortId(conversationId)} act=${fast.act} '
              'input="${_sample(notif.text)}"',
            );
          } else {
            // A12 — thermal CRITICAL+: suprimir la inferencia opcional. El
            // turno muere honesto (failed, jamás reply inventado); el
            // backoff del dedupe reintenta cuando el sistema se enfríe.
            final thermal = await _thermalStatus?.call();
            if (thermal != null && thermal >= _thermalSevere) {
              return RuleDispatchResult(
                ruleId: rule.id,
                outcome: RuleOutcome.failed,
                reason:
                    'thermal $thermal (critical+): inferencia LLM suprimida '
                    'sin fast path aplicable',
              );
            }
            if (draftSource == null) {
              return RuleDispatchResult(
                ruleId: rule.id,
                outcome: RuleOutcome.failed,
                reason: 'regla dinámica sin motor de redacción disponible',
              );
            }
            final draft = await draftSource(notif);
            if (draft == null || !draft.hasReply) {
              return RuleDispatchResult(
                ruleId: rule.id,
                outcome: RuleOutcome.failed,
                reason: 'regla dinámica: el motor local no produjo borrador',
              );
            }
            // A10 — output language pass: correcciones seguras y
            // deterministas (puntuación duplicada, espacios accidentales).
            // STYLE != ERROR: jamás se tocan acentos ni vocabulario.
            final cleaned = LanguageAssistService.safeCleanOutput(draft.reply);
            if (cleaned.trim().isEmpty) {
              return RuleDispatchResult(
                ruleId: rule.id,
                outcome: RuleOutcome.failed,
                reason: 'borrador sin contenido tras limpieza de salida',
              );
            }
            text = cleaned.trim();
            understanding = draft.understanding;
          }

          final currentVersion = supersedeGuard == null
              ? 0
              : supersedeGuard.versionOf(conversationId);
          if (supersedeGuard != null && currentVersion != conversationVersion) {
            MessagingMetrics.superseded();
            // P1-FIX — traza TEMPORAL del invariante: captured = versión al
            // abrir el turno, current = versión al terminar el draft.
            debugPrint(
              '[supersede] conv=${_shortId(conversationId)} '
              'captured=$conversationVersion current=$currentVersion '
              'stage=postDraft input="${_sample(notif.text)}"',
            );
            return RuleDispatchResult(
              ruleId: rule.id,
              outcome: RuleOutcome.ignored,
              reason:
                  'turno superado: llegó un mensaje nuevo durante el borrador',
            );
          }
          // PERSONA-DECISION-02 — FACTS → DECISION → SEND: antes de
          // construir el goal, el engine determinista decide con las señales
          // verificables del entendimiento (del LLM O del fast path).
          // No-autoSend = nada sale (la aprobación humana llega en
          // PERSONA-HANDOFF/TOOLS).
          if (decisionEngine != null) {
            final decision = decisionEngine.decide(
              understanding: understanding,
              context:
                  _decisionContext?.call(notif) ??
                  const ConversationDecisionContext(),
            );
            if (!decision.autoSend) {
              debugPrint(
                '[decision] ${decision.disposition.name} '
                'conf=${decision.confidence.toStringAsFixed(2)} | '
                '${decision.reasons.join('; ')}',
              );
              return RuleDispatchResult(
                ruleId: rule.id,
                outcome: RuleOutcome.failed,
                reason:
                    'decisión automática ${decision.disposition.name}: '
                    '${decision.reasons.join('; ')}',
              );
            }
          }
        } else if (text.trim().isEmpty) {
          return RuleDispatchResult(
            ruleId: rule.id,
            outcome: RuleOutcome.failed,
            reason: 'regla sin mensaje de respuesta',
          );
        }
        final capability = ReplyCapabilityRef.fromNotification(notif);
        if (capability == null || !capability.isUsable) {
          return RuleDispatchResult(
            ruleId: rule.id,
            outcome: RuleOutcome.failed,
            reason: 'notificación sin capacidad RemoteInput observada válida',
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
            supersedeGuard.versionOf(conversationId) != conversationVersion) {
          MessagingMetrics.superseded();
          // P1-FIX — traza TEMPORAL del invariante: el reply ya no vale.
          debugPrint(
            '[supersede] conv=${_shortId(conversationId)} '
            'captured=$conversationVersion '
            'current=${supersedeGuard.versionOf(conversationId)} '
            'stage=preSend input="${_sample(notif.text)}"',
          );
          return RuleDispatchResult(
            ruleId: rule.id,
            outcome: RuleOutcome.ignored,
            reason: 'turno superado antes del envío',
          );
        }
        if (!permitsSideEffect()) {
          return RuleDispatchResult(
            ruleId: rule.id,
            outcome: RuleOutcome.ignored,
            reason: 'control humano o política cambió durante el borrador',
          );
        }
        // P1-FIX — traza TEMPORAL del invariante 1 INPUT = 1 DECISION:
        // dispatch cierra el turno con el MISMO input que lo abrió.
        debugPrint(
          '[dispatch] conv=${_shortId(conversationId)} '
          'input="${_sample(notif.text)}" reply="${_sample(text)}" '
          'version=$conversationVersion',
        );
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
            options: AutomationOptions(
              authority: authority,
              replyCapability: capability,
              replyText: text,
              incomingEventId: IncomingMessage.fromNotification(notif).eventId,
              isCurrent: () =>
                  permitsSideEffect() &&
                  (supersedeGuard == null ||
                      supersedeGuard.versionOf(conversationId) ==
                          conversationVersion),
            ),
          );
        } catch (e) {
          return RuleDispatchResult(
            ruleId: rule.id,
            outcome: RuleOutcome.failed,
            reason: 'excepción en ejecución: $e',
          );
        }
        final outcome = _replyOutcome(rule.id, result, dispatchedText: text);
        if (!outcome.isReplyAttempt &&
            supersedeGuard != null &&
            supersedeGuard.versionOf(conversationId) != conversationVersion) {
          return RuleDispatchResult(
            ruleId: rule.id,
            outcome: RuleOutcome.ignored,
            reason: 'turno superado durante la preparación del envío',
          );
        }
        if (outcome.outcome == RuleOutcome.replyVerified ||
            outcome.outcome == RuleOutcome.replyDispatchedUnverified) {
          MessagingMetrics.increment('draftsSent');
          MessagingMetrics.emit();
        }
        return outcome;

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
            outcome: launched ? RuleOutcome.mediaLaunched : RuleOutcome.failed,
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

  /// P1-FIX — muestra acotada del input/reply para trazas físicas (200
  /// chars, una línea: el texto completo con saltos inundaba el logcat).
  static String _sample(String raw) {
    final single = raw.replaceAll('\n', ' ').trim();
    return single.length <= 200 ? single : single.substring(0, 200);
  }

  /// P1-FIX — hash corto del id de conversación para la traza.
  static String _shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);
}
