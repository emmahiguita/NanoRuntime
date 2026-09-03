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

import 'package:flutter/foundation.dart' show debugPrint;

import '../messaging/incoming_message.dart';
import '../notifications/notification_object.dart';
import 'event_dedupe_store.dart';
import 'notification_event_adapter.dart';
import 'rule_dispatcher.dart';
import 'rule_engine.dart';
import 'rule_registry.dart';
import 'scheduled_rule.dart';

class RulePipeline {
  RulePipeline({
    required RuleRegistry registry,
    required RuleEngine engine,
    required EventDedupeStore dedupe,
    required RuleDispatcher dispatcher,
  }) : _registry = registry,
       _engine = engine,
       _dedupe = dedupe,
       _dispatcher = dispatcher;

  final RuleRegistry _registry;
  final RuleEngine _engine;
  final EventDedupeStore _dedupe;
  final RuleDispatcher _dispatcher;

  /// Procesa una notificación entrante: pasa la puerta de deduplicación,
  /// matchea reglas habilitadas y ejecuta. Devuelve los resultados (vacío =
  /// sin regla que disparó o evento bloqueado por la puerta).
  Future<List<RuleDispatchResult>> onNotification(
    NotificationObject notif,
  ) async {
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
      case DedupeVerdict.bounceback:
      case DedupeVerdict.cooldown:
        return const [];
    }

    final results = <RuleDispatchResult>[];
    var replyAttempted = false;
    for (final rule in matched) {
      final r = await _dispatchOne(
        rule,
        notif,
        conversationId,
        nowMs,
        replyAttempted: replyAttempted,
      );
      results.add(r);
      replyAttempted = replyAttempted || r.isReplyAttempt;

      if (r.isReplyAttempt) {
        // Texto del envío con posible aterrizaje: servirá para ignorar el eco
        // que la app origen publique después ("Tú: ...").
        _dedupe.recordVerifiedOutbound(
          conversationId,
          rule.message,
          atMs: nowMs,
        );
      }
      // Registrar el disparo para cooldown de regla (T3.6). El evento fallado
      // no cuenta como disparo: el siguiente evento real puede reintentar.
      if (r.isReplyAttempt || r.outcome == RuleOutcome.notified) {
        _registry.markFired(rule.id, DateTime.now());
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
    return results;
  }

  /// Despacha UNA regla con sus guardas de evento: nunca dos respuestas al
  /// mismo evento (dos reglas reply matcheadas = solo la primera ejecuta).
  Future<RuleDispatchResult> _dispatchOne(
    ScheduledRule rule,
    NotificationObject notif,
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
