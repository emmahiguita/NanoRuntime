/// RulePipeline (T3.2-T3.3 + WA-DEDUPE-03) — el glue WhatsApp-first:
///
///   NotificationObject (real)
///     → NotificationEvent (adapter, matching de reglas)
///     → IncomingMessage + EventDedupeStore.reserve (puerta T3.6)
///     → RuleEngine.match (determinista)
///     → RuleDispatcher.dispatch (coordinator, nunca agente paralelo)
///     → record estado terminal + markFired
///
/// Este es el punto de entrada que el NotificationListenerService nativo llama
/// cuando llega una notificación de com.whatsapp.
///
/// La puerta de idempotencia se cierra SIEMPRE antes de despachar: un evento
/// repetido, el eco de nuestra propia respuesta o una ráfaga en cooldown jamás
/// llegan a ejecutar una regla (T3.6: un mensaje lógico → a lo sumo un intento
/// de respuesta posiblemente irreversible).
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../messaging/conversation_key.dart';
import '../messaging/conversation_memory.dart';
import '../messaging/incoming_message.dart';
import '../notifications/notification_object.dart';
import 'contact_rate_limiter.dart';
import 'event_dedupe_store.dart';
import 'notification_event_adapter.dart';
import '../storage/automation_db_store_client.dart';
import 'rule_dispatcher.dart';
import 'rule_engine.dart';
import 'rule_registry.dart';
import 'scheduled_rule.dart';
import 'trigger.dart' show TickEvent;
import 'turn_supersede_guard.dart';

class RulePipeline {
  RulePipeline({
    required RuleRegistry registry,
    required RuleEngine engine,
    required EventDedupeStore dedupe,
    required ConversationMemoryStore memory,
    required RuleDispatcher dispatcher,
    required ContactRateLimiter rateLimiter,
    Future<void>? readiness,
    TurnSupersedeGuard? supersedeGuard,
  }) : _registry = registry,
       _engine = engine,
       _dedupe = dedupe,
       _memory = memory,
       _dispatcher = dispatcher,
       _rateLimiter = rateLimiter,
       _readiness = readiness,
       _supersedeGuard = supersedeGuard;

  final RuleRegistry _registry;
  final RuleEngine _engine;
  final EventDedupeStore _dedupe;

  /// WA-PROD-02 — barrera de hidratación (futuro compartido con el provider):
  /// ningún evento/tick se decide antes de que los stores terminaron su carga.
  /// Se espera UNA sola vez por instancia.
  Future<void>? _readiness;

  /// WA-CONV-03 — versión por conversación: incrementa con cada mensaje REAL
  /// que entra al pipeline (rutas sin gate; el gate ya lo hace en su push).
  final TurnSupersedeGuard? _supersedeGuard;

  /// WA-ECHO-01 — ventana en la que un eco "Tú:" se considera de NUESTRO
  /// envío reciente (3 min: WhatsApp publica el eco segundos después; un
  /// texto idéntico legítimo del cliente mucho más tarde no debe confundirse).
  static const _echoWindowMs = 180000;

  Future<void> _waitReady() async {
    final ready = _readiness;
    if (ready != null) {
      _readiness = null;
      await ready;
    }
  }

  /// RATE-01 — límite duro de respuestas por conversación (ventana).
  final ContactRateLimiter _rateLimiter;

  /// WA-MEM-08 — memoria aislada por conversación (escritura honesta).
  final ConversationMemoryStore _memory;
  final RuleDispatcher _dispatcher;

  /// Procesa una notificación entrante: pasa la puerta de deduplicación,
  /// matchea reglas habilitadas y ejecuta. Devuelve los resultados (vacío =
  /// sin regla que disparó o evento bloqueado por la puerta).
  Future<List<RuleDispatchResult>> onNotification(
    NotificationObject notif,
  ) async {
    await _waitReady();
    // WA-EVLOG-01 — bitácora local append-only (best-effort, jamás interrumpe).
    unawaited(
      AutomationDbStoreClient.instance.appendPipelineEvent(
        conversationId: resolveConversationIdentity(notif).key.id,
        kind: 'received',
        detail:
            'pkg=${notif.packageName} ev=${notif.key.length > 16 ? notif.key.substring(0, 16) : notif.key}',
      ),
    );
    final event = const NotificationEventAdapter().fromNotification(notif);
    final matched = _engine.match(_registry.rules, event);
    // WA-PHYS-11: traza física (logcat tag flutter). Reglas cargadas + veredicto
    // + resultados: sin esto los fallos en dispositivo son indiagnosticables.
    debugPrint(
      '[rules] cargadas=${_registry.rules.length} '
      'matcheadas=${matched.length} (${event.packageName}/${event.sender})',
    );
    if (matched.isEmpty) return const [];

    // WA-DEDUPE-03 — puerta ANTES del dispatch. El veredicto no-proceed ya
    // quedó persistido por el store (eco/cooldown registran su `ignored`;
    // duplicate conserva el estado del evento original): nada que re-anotar.
    final message = IncomingMessage.fromNotification(notif);
    final conversationId = message.conversation.key.id;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final verdict = _dedupe.reserve(
      message.eventId,
      conversationId: conversationId,
      text: message.text,
      atMs: nowMs,
    );
    debugPrint(
      '[rules] verdict=${verdict.name} evt=${message.eventId.substring(4, 16)}',
    );
    switch (verdict) {
      case DedupeVerdict.proceed:
        break;
      case DedupeVerdict.duplicate:
      case DedupeVerdict.cooldown:
        return const [];

      case DedupeVerdict.bounceback:
        // WA-ECHO-01 — el eco "Tú: <texto>" de la app origen es evidencia
        // LOCAL de que el envío aterrizó en el hilo de la conversación
        // (NO demuestra entrega al destinatario). Si el texto coincide con
        // nuestro último outbound reciente, queda registrado en la bitácora.
        try {
          // memoryFor jamás devuelve lista vacía: entries.last es seguro
          // cuando la memoria existe.
          final memory = _memory.memoryFor(conversationId);
          final candidate = memory == null
              ? null
              : memory.entries.lastWhere(
                  (e) =>
                      e.kind ==
                          ConversationMemoryEntryKind.outboundDispatched ||
                      e.kind == ConversationMemoryEntryKind.outboundVerified ||
                      e.kind == ConversationMemoryEntryKind.effectUnknown,
                  orElse: () => memory.entries.last,
                );
          final isRecentEcho =
              candidate != null &&
              candidate.atMs > 0 &&
              nowMs - candidate.atMs < _echoWindowMs &&
              normalizeDedupeText(candidate.text) ==
                  normalizeDedupeText(message.text);
          if (isRecentEcho) {
            unawaited(
              AutomationDbStoreClient.instance.appendPipelineEvent(
                conversationId: conversationId,
                kind: 'echo',
                detail: 'eco local observado del envío reciente',
              ),
            );
          }
        } on Object {
          // El eco se ignora igual; la bitácora es best-effort.
        }
        return const [];
    }

    // WA-PROD-02.2 — la reserva queda DURABLE antes de cualquier dispatch:
    // un kill entre este punto y el envío deja la puerta persistida; el
    // replay del próximo wake devuelve duplicate (jamás doble envío).
    try {
      await _dedupe.flush();
    } on Object catch (e) {
      // Persistencia best-effort: si la escritura falló el dispatch sigue
      // (comportamiento histórico), pero el fallo queda traceable.
      debugPrint('[rules] flush dedupe falló: $e');
    }
    // WA-CONV-03 — este mensaje REAL incrementa la versión del turno (el
    // dispatcher captura DESPUÉS de este punto; el gate ya incrementó por
    // cada inbound en la ruta con ráfagas).
    _supersedeGuard?.bump(conversationId);

    final results = <RuleDispatchResult>[];
    var replyAttempted = false;
    var replyText = '';
    var replyRuleId = '';
    for (final rule in matched) {
      final r = await _dispatchOne(
        rule,
        notif,
        message.conversation.key,
        conversationId,
        nowMs,
        replyAttempted: replyAttempted,
      );
      results.add(r);
      replyAttempted = replyAttempted || r.isReplyAttempt;

      if (r.isReplyAttempt) {
        // Texto del envío con posible aterrizaje: servirá para ignorar el eco
        // que la app origen publique después ("Tú: ..."). WA-AGENT-09: el
        // texto real (fijo o borrador LLM) viaja en el resultado del dispatch.
        final sentText = r.dispatchedText.isNotEmpty
            ? r.dispatchedText
            : rule.message;
        _dedupe.recordVerifiedOutbound(conversationId, sentText, atMs: nowMs);
        replyText = sentText;
        replyRuleId = rule.id;
      }
      // Registrar el disparo para cooldown de regla (T3.6). El evento fallado
      // no cuenta como disparo: el siguiente evento real puede reintentar.
      // WA-RULES-UI-02 — el outcome real viaja al registry (estado visible
      // en la pantalla Reglas). mediaLaunched cuenta: WhatsApp se abrió.
      if (r.isReplyAttempt ||
          r.outcome == RuleOutcome.notified ||
          r.outcome == RuleOutcome.mediaLaunched) {
        _registry.markFired(
          rule.id,
          DateTime.now(),
          outcome: r.outcome.name,
        );
      }
    }

    final terminal = _terminalState(results);
    _dedupe.record(
      message.eventId,
      terminal,
      atMs: nowMs,
      reason: _terminalReason(results),
    );
    debugPrint(
      '[rules] terminal=$terminal resultados='
      '${results.map((r) => r.outcome.name).join(',')} '
      'razones="${results.map((r) => r.reason).join(' | ')}"',
    );

    // WA-MEM-08 — memoria por conversación con honestidad de estado. El
    // inbound se registra como observación; el outbound SOLO con su estado
    // real (verified/dispatched/effectUnknown), jamás como éxito inventado.
    if (message.conversation.key.id.isNotEmpty) {
      _memory.appendInbound(message, atMs: nowMs);
      if (replyAttempted && replyText.isNotEmpty) {
        final kind = switch (terminal) {
          DedupeEventState.replyVerified =>
            ConversationMemoryEntryKind.outboundVerified,
          DedupeEventState.replyDispatched =>
            ConversationMemoryEntryKind.outboundDispatched,
          DedupeEventState.outcomeUnknown =>
            ConversationMemoryEntryKind.effectUnknown,
          _ => null,
        };
        if (kind != null) {
          _memory.appendOutbound(
            conversationId,
            replyText,
            kind: kind,
            ruleId: replyRuleId,
            atMs: nowMs,
          );
        }
      }
    }
    // WA-EVLOG-01 — terminal honesto del evento en la bitácora local.
    unawaited(
      AutomationDbStoreClient.instance.appendPipelineEvent(
        conversationId: conversationId,
        kind: 'terminal',
        detail:
            '${terminal.name} r=${results.map((r) => r.outcome.name).join(',')}',
      ),
    );
    return results;
  }

  /// TRIG-01 — tick de reloj (TimeTickScheduler): matchea reglas de hora
  /// habilitadas y las ejecuta SIN notificación entrante. Sin puerta de dedupe
  /// (el tick de cada minuto es único por construcción) y sin reply (no hay
  /// remitente: el dispatcher falla honesto en ese caso).
  Future<List<RuleDispatchResult>> onTick(TickEvent event) async {
    await _waitReady();
    final matched = _engine.match(_registry.rules, event);
    final hhmm =
        '${event.now.hour.toString().padLeft(2, '0')}:'
        '${event.now.minute.toString().padLeft(2, '0')}';
    debugPrint(
      '[rules] tick $hhmm cargadas=${_registry.rules.length} '
      'matcheadas=${matched.length}',
    );
    final results = <RuleDispatchResult>[];
    for (final rule in matched) {
      final r = await _dispatcher.dispatchScheduled(rule);
      results.add(r);
      // Registrar el disparo para cooldown de regla: solo efectos reales
      // (aviso publicado o borrador); el reply fallado no cuenta.
      // WA-RULES-UI-02 — outcome real para el estado de la pantalla Reglas.
      if (r.outcome == RuleOutcome.notified ||
          r.outcome == RuleOutcome.drafted) {
        _registry.markFired(rule.id, event.now, outcome: r.outcome.name);
      }
    }
    if (results.isNotEmpty) {
      debugPrint(
        '[rules] tick resultados='
        '${results.map((r) => r.outcome.name).join(',')} '
        'razones="${results.map((r) => r.reason).join(' | ')}"',
      );
    }
    return results;
  }

  /// Despacha UNA regla con sus guardas de evento: nunca dos respuestas al
  /// mismo evento (dos reglas reply matcheadas = solo la primera ejecuta).
  Future<RuleDispatchResult> _dispatchOne(
    ScheduledRule rule,
    NotificationObject notif,
    ConversationKey key,
    String conversationId,
    int nowMs, {
    required bool replyAttempted,
  }) async {
    if (rule.action == RuleAction.reply) {
      if (replyAttempted) {
        return RuleDispatchResult(
          ruleId: rule.id,
          outcome: RuleOutcome.ignored,
          reason: 'otra regla ya intentó responder a este evento',
        );
      }
      // RATE-01 — puerta de saturación ANTES del envío. El intento permitido
      // queda registrado en la ventana (el canal paga el costo aunque el
      // envío luego falle); el bloqueado jamás llega al dispatcher.
      final allowed = await _rateLimiter.allowReply(
        key,
        at: DateTime.fromMillisecondsSinceEpoch(nowMs),
      );
      if (!allowed) {
        final p = _rateLimiter.policy;
        return RuleDispatchResult(
          ruleId: rule.id,
          outcome: RuleOutcome.ignored,
          reason:
              'rate limit per-contacto '
              '(máx ${p.maxRepliesPerWindow}/${p.window.inMinutes}min)',
        );
      }
      // Marca el intento de escritura como EN VUELO antes de ejecutar: un
      // segundo evento de la misma conversación que entre a mitad de la
      // ejecución cae en cooldown aunque el primero aún no haya terminado.
      _dedupe.markReplyPending(conversationId, nowMs);
    }
    return _dispatcher.dispatch(rule, notif);
  }

  /// Estado terminal del evento agregando los outcomes de TODAS las reglas:
  /// gana el resultado más fuerte (un intento verificado opaca un notify).
  DedupeEventState _terminalState(List<RuleDispatchResult> results) {
    if (results.any((r) => r.outcome == RuleOutcome.replyVerified)) {
      return DedupeEventState.replyVerified;
    }
    if (results.any(
      (r) => r.outcome == RuleOutcome.replyDispatchedUnverified,
    )) {
      return DedupeEventState.replyDispatched;
    }
    if (results.any((r) => r.outcome == RuleOutcome.outcomeUnknown)) {
      return DedupeEventState.outcomeUnknown;
    }
    if (results.any((r) => r.outcome == RuleOutcome.failed)) {
      return DedupeEventState.failed;
    }
    if (results.any((r) => r.outcome == RuleOutcome.notified)) {
      return DedupeEventState.notified;
    }
    if (results.any((r) => r.outcome == RuleOutcome.drafted)) {
      return DedupeEventState.drafted;
    }
    return DedupeEventState.ignored;
  }

  String _terminalReason(List<RuleDispatchResult> results) {
    for (final r in results) {
      if (r.reason.isNotEmpty) return r.reason;
    }
    return '';
  }
}
