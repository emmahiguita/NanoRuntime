/// WA-TURN-01 — BurstTurnGate: una conversación = UN turno por ráfaga.
///
/// Un humano manda "hola", 2s después "¿tienes el negro?" y luego
/// "¿cuánto vale?". Sin puerta, cada notificación dispara su propio dispatch
/// (LLM de decenas de segundos por mensaje → respuestas fragmentadas y
/// carreras). Esta puerta agrupa por conversación:
///
///   primer mensaje → ventana de asentamiento → se unen los que lleguen →
///   UN solo turno del pipeline con el texto agregado → todos resueltos.
///
/// Además serializa: mientras un turno de la conversación corre, los
/// mensajes nuevos esperan en cola y forman el SIGUIENTE turno (nunca dos
/// pipeline concurrentes para el mismo chat). El turno en curso jamás se
/// cancela a mitad; el dispatcher descarta su borrador si llegó un mensaje
/// nuevo. Los mensajes pendientes forman el siguiente turno.
///
/// Puro estado en memoria: un kill solo pierde la ventana de asentamiento
/// actual; los eventos ya persistidos (inbox/dedupe) siguen su camino.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../messaging/conversation_key.dart' show resolveConversationIdentity;
import '../notifications/notification_object.dart';
import 'messaging_metrics.dart';
import 'rule_dispatcher.dart' show RuleDispatchResult, RuleOutcome;

/// Puerta de ráfagas por conversación. Instancia única por engine (provider).
final class BurstTurnGate {
  BurstTurnGate({
    this.settle = const Duration(milliseconds: 800),
    this.maxWait = const Duration(milliseconds: 3000),
    this.maxBurst = 64,
    this.onInbound,
    this.onTurnComplete,
  });

  /// WA-CONV-03 — notifica cada mensaje REAL entrante (incluidos los que
  /// llegan mientras un turno corre): el supersede guard incrementa la
  /// versión de la conversación con cada uno.
  final void Function(String conversationId)? onInbound;

  /// WA-STATE-01 — notifica el turno AGREGADO que terminó (conversación +
  /// notificación unida + reply real enviado): el wiring registra el turno
  /// completo (producto consultado, pregunta pendiente, cierre de tema).
  /// [dispatchedText] = texto REAL despachado por el turno ('' si no hubo
  /// reply: regla fallida, decisión negativa o sin motor).
  final FutureOr<void> Function(
    String conversationId,
    NotificationObject aggregated, {
    String dispatchedText,
  })?
  onTurnComplete;

  /// Ventana de asentamiento tras el primer mensaje de la ráfaga.
  final Duration settle;

  /// Tope total de espera desde el primer mensaje (no añadir latencia
  /// infinita a una conversación real).
  final Duration maxWait;

  /// Maximum queued fragments per conversation; overflow is explicit.
  final int maxBurst;

  /// Pipeline del turno agregado. Reentrada segura por conversación
  /// (serialización aquí, nunca dos ejecuciones simultáneas del mismo chat).
  final Map<String, _Bucket> _byConversation = {};
  final Set<Future<void>> _pending = {};
  bool _disposed = false;

  void ensureCapacity(List<NotificationObject> events) {
    if (_disposed) throw StateError('Burst gate disposed');
    final counts = <String, int>{};
    for (final event in events) {
      final key = _bucketKey(event);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final keys = {..._byConversation.keys, ...counts.keys};
    if (keys.length > 64 ||
        events.length +
                _byConversation.values.fold<int>(
                  0,
                  (n, b) => n + b._queue.length,
                ) >
            800 ||
        counts.entries.any(
          (e) =>
              e.value + (_byConversation[e.key]?._queue.length ?? 0) > maxBurst,
        )) {
      throw StateError('Burst capacity exceeded; event remains retryable');
    }
  }

  void dispose() {
    _disposed = true;
    for (final bucket in _byConversation.values.toList()) {
      bucket.dispose();
    }
    _byConversation.clear();
  }

  Future<void> drain() async {
    while (_pending.isNotEmpty) {
      await Future.wait(_pending.toList());
    }
  }

  /// Envía un evento a su conversación y resuelve cuando el turno que lo
  /// contiene terminó (resultados compartidos por toda la ráfaga).
  Future<List<RuleDispatchResult>> submit(
    NotificationObject event,
    Future<List<RuleDispatchResult>> Function(NotificationObject aggregated)
    runTurn,
  ) async {
    return (await submitAll([event], runTurn)).single;
  }

  /// Envía una tanda (p.ej. el drenado del inbox) y resuelve por evento.
  /// Los eventos de la MISMA conversación dentro de la tanda se agregan;
  /// cada futuro completa cuando terminó el turno que absorbió a su evento.
  Future<List<List<RuleDispatchResult>>> submitAll(
    List<NotificationObject> events,
    Future<List<RuleDispatchResult>> Function(NotificationObject aggregated)
    runTurn, {
    Future<void> Function(List<NotificationObject>)? beforeTurn,
  }) async {
    if (events.isEmpty) return const [];
    ensureCapacity(events);
    final results = List<List<RuleDispatchResult>>.filled(
      events.length,
      const [],
    );
    // WA-REG-01 — resolución por TANDA: cada submitAll espera que TODOS sus
    // eventos hayan sido consumidos por su turno. Antes cada bucket tenía un
    // único completer `resolved`: una tanda nueva que llegaba con el bucket
    // vivo (turno anterior en curso) esperaba un future ya completado y
    // retornaba con resultados vacíos prematuros. Cada miembro trae su
    // propia resolución: tandas distintas que comparten bucket no comparten
    // lista de resultados ni futuro.
    final batch = _Batch(events.length);
    _pending.add(batch.done.future);
    // Anclar conversaciones ANTES de cualquier await: los eventos viven en
    // una lista estable durante la tanda.
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      final key = _bucketKey(event);
      final bucket = _byConversation.putIfAbsent(
        key,
        () => _Bucket(
          key: key,
          settle: settle,
          maxWait: maxWait,
          maxBurst: maxBurst,
          runTurn: runTurn,
          beforeTurn: beforeTurn,
          onTurnComplete: onTurnComplete,
          onIdle: () => _byConversation.remove(key),
        ),
      );
      onInbound?.call(key.startsWith('anon:') ? '' : key);
      bucket.push(
        _Member(event, (turnResults) {
          results[i] = turnResults;
          batch.tick();
        }),
      );
    }
    await batch.done.future;
    _pending.remove(batch.done.future);
    return results;
  }

  String _bucketKey(NotificationObject event) {
    // Sin identidad de conversación: cada evento es su propio turno
    // inmediato (fail-closed, sin memoria compartida inventada).
    final id = resolveConversationIdentity(event).key.id;
    return id.isEmpty ? 'anon:${event.key}:${event.messageTimestamp}' : id;
  }
}

/// Una ráfaga en curso (o esperando su ventana) de una conversación.
class _Bucket {
  _Bucket({
    required this.key,
    required this.settle,
    required this.maxWait,
    required this.maxBurst,
    required this.runTurn,
    this.beforeTurn,
    required this.onIdle,
    required this.onTurnComplete,
  });

  final String key;
  final Duration settle;
  final Duration maxWait;
  final int maxBurst;
  final Future<List<RuleDispatchResult>> Function(NotificationObject) runTurn;
  final Future<void> Function(List<NotificationObject>)? beforeTurn;

  /// WA-STATE-01 — turno agregado terminado (conversación + notificación
  /// + reply real despachado, '' si no hubo).
  final FutureOr<void> Function(
    String conversationId,
    NotificationObject aggregated, {
    String dispatchedText,
  })?
  onTurnComplete;

  /// El bucket se retira SOLO cuando quedó vacío y sin turno en curso
  /// (nunca antes: un miembro en cola huérfano colgaría su futuro).
  final void Function() onIdle;

  final List<_Member> _queue = [];
  Timer? _settleTimer;
  Timer? _deadlineTimer;
  bool _running = false;
  bool _disposed = false;

  void dispose() {
    _disposed = true;
    _settleTimer?.cancel();
    _deadlineTimer?.cancel();
    for (final member in _queue) {
      member.resolve(const [
        RuleDispatchResult(
          ruleId: '',
          outcome: RuleOutcome.failed,
          reason: 'Runtime disposed before dispatch',
        ),
      ]);
    }
    _queue.clear();
  }

  // Count and text length must not close a human turn prematurely.
  // The existing deadline bounds a continuously arriving burst.
  void push(_Member member) {
    if (_queue.isEmpty) {
      _deadlineTimer = Timer(maxWait, _fire);
    }
    _queue.add(member);
    _settleTimer?.cancel();
    _settleTimer = Timer(settle, _fire);
  }

  Future<void> _fire() async {
    _settleTimer?.cancel();
    _deadlineTimer?.cancel();
    if (_disposed || _running || _queue.isEmpty) return;
    _running = true;
    final members = List<_Member>.of(_queue);
    _queue.clear();
    var executionStarted = false;
    try {
      await beforeTurn?.call(members.map((m) => m.event).toList());
      if (_disposed) throw StateError('Runtime disposed before dispatch');
      final aggregated = _merge(members);
      MessagingMetrics.turn(members.length);
      debugPrint(
        '[turn] conv=${key.substring(0, key.length > 12 ? 12 : key.length)} '
        'agregados=${members.length} '
        'texto="${_sample(aggregated.messageText)}"',
      );
      executionStarted = true;
      final results = await runTurn(aggregated);
      try {
        if (!_disposed) {
          await onTurnComplete?.call(
            key.startsWith('anon:') ? '' : key,
            aggregated,
            dispatchedText: _dispatchedReply(results),
          );
        }
      } on Object catch (error) {
        // A memory write failure cannot erase an actual send outcome.
        debugPrint('[turn] state persistence failed: $error');
      }
      for (final m in members) {
        m.resolve(results);
      }
      if (_queue.isEmpty) onIdle();
    } on Object catch (e) {
      debugPrint('[turn] ráfaga falló: $e');
      for (final m in members) {
        m.resolve([
          RuleDispatchResult(
            ruleId: '',
            outcome: executionStarted
                ? RuleOutcome.outcomeUnknown
                : RuleOutcome.failed,
            reason: 'Turn failed: $e',
          ),
        ]);
      }
      if (_queue.isEmpty) onIdle();
    } finally {
      _running = false;
      // Lo que llegó durante el turno arranca su propia ventana.
      if (_queue.isNotEmpty && !(_deadlineTimer?.isActive ?? false)) {
        _deadlineTimer = Timer(maxWait, _fire);
        _settleTimer = Timer(settle, _fire);
      }
    }
  }

  /// El turno agregado: el ÚLTIMO evento es el ancla (identidad, capacidad
  /// de reply, timestamps); el texto une los mensajes en orden.
  NotificationObject _merge(List<_Member> members) {
    final ordered = members.indexed.toList()
      ..sort((a, b) {
        int stamp(NotificationObject n) =>
            n.messageTimestamp > 0 ? n.messageTimestamp : n.postTime;
        final delta = stamp(a.$2.event).compareTo(stamp(b.$2.event));
        return delta == 0 ? a.$1.compareTo(b.$1) : delta;
      });
    final anchor = ordered.last.$2.event;
    final parts = [
      for (final m in ordered) _messageText(m.$2.event).trim(),
    ].where((t) => t.isNotEmpty);
    final joined = parts.join('\n');
    return NotificationObject(
      key: anchor.key,
      packageName: anchor.packageName,
      title: anchor.title,
      text: joined.isEmpty ? anchor.text : joined,
      messageText: joined,
      messageTimestamp: anchor.messageTimestamp,
      sender: anchor.sender,
      senderKey: anchor.senderKey,
      senderUri: anchor.senderUri,
      conversationTitle: anchor.conversationTitle,
      conversationId: anchor.conversationId,
      shortcutId: anchor.shortcutId,
      locusId: anchor.locusId,
      accountHint: anchor.accountHint,
      isGroup: anchor.isGroup,
      isSummary: anchor.isSummary,
      isTruncated: members.any((member) => member.event.isTruncated),
      postTime: anchor.postTime,
      canReply: anchor.canReply,
      remoteInputKey: anchor.remoteInputKey,
      actionIndex: anchor.actionIndex,
      actions: anchor.actions,
      ongoing: anchor.ongoing,
    );
  }

  static String _messageText(NotificationObject event) =>
      event.messageText.isNotEmpty ? event.messageText : event.text;

  /// Ronda 3 — reply REAL despachado por el turno (primer intento de reply
  /// con texto), '' si ninguno. Fuente del registro de pregunta pendiente.
  static String _dispatchedReply(List<RuleDispatchResult> results) {
    for (final r in results) {
      if (r.isReplyAttempt && r.dispatchedText.isNotEmpty) {
        return r.dispatchedText;
      }
    }
    return '';
  }

  static String _sample(String raw) {
    final single = raw.replaceAll('\n', ' · ');
    return single.length <= 120 ? single : '${single.substring(0, 120)}…';
  }
}

class _Member {
  _Member(this.event, this.resolve);

  final NotificationObject event;

  /// Resuelve el futuro de ESTE evento con los resultados del turno que lo
  /// absorbió. Cada miembro trae su propia resolución (WA-REG-01): tandas
  /// distintas que comparten bucket no comparten lista de resultados.
  final void Function(List<RuleDispatchResult> results) resolve;
}

/// WA-REG-01 — una tanda de submitAll: se completa cuando TODOS sus eventos
/// fueron resueltos por sus turnos (pueden caer en turnos distintos si la
/// ráfaga se partió). Reemplaza al completer único por bucket, que resolvía
/// prematuramente las tandas que llegaban con un turno anterior en curso.
class _Batch {
  _Batch(this.count);

  /// Eventos totales de la tanda.
  final int count;

  int _resolved = 0;
  final Completer<void> done = Completer<void>();

  /// Un evento de la tanda resolvió su turno. Al llegar al total, la tanda
  /// completa su futuro (idempotente: un turno nunca resuelve dos veces a un
  /// miembro).
  void tick() {
    _resolved++;
    if (_resolved >= count && !done.isCompleted) {
      done.complete();
    }
  }
}
