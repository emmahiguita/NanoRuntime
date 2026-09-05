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
/// cancela a mitad (supersede pre-send = WA-CONV-03, requiere partir el
/// dispatcher); el mensaje nuevo nunca se pierde: se responde después.
///
/// Puro estado en memoria: un kill solo pierde la ventana de asentamiento
/// actual; los eventos ya persistidos (inbox/dedupe) siguen su camino.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../messaging/conversation_key.dart' show resolveConversationIdentity;
import '../notifications/notification_object.dart';
import 'rule_dispatcher.dart' show RuleDispatchResult;

/// Puerta de ráfagas por conversación. Instancia única por engine (provider).
final class BurstTurnGate {
  BurstTurnGate({
    this.settle = const Duration(milliseconds: 800),
    this.maxWait = const Duration(milliseconds: 3000),
    this.maxBurst = 6,
    this.onInbound,
    this.onTurnComplete,
  });

  /// WA-CONV-03 — notifica cada mensaje REAL entrante (incluidos los que
  /// llegan mientras un turno corre): el supersede guard incrementa la
  /// versión de la conversación con cada uno.
  final void Function(String conversationId)? onInbound;

  /// WA-STATE-01 — notifica el turno AGREGADO que terminó (conversación +
  /// notificación unida): el wiring recuerda qué producto consultó el
  /// cliente (selector determinista contra el catálogo).
  final void Function(String conversationId, NotificationObject aggregated)?
  onTurnComplete;

  /// Ventana de asentamiento tras el primer mensaje de la ráfaga.
  final Duration settle;

  /// Tope total de espera desde el primer mensaje (no añadir latencia
  /// infinita a una conversación real).
  final Duration maxWait;

  /// Máximo de mensajes unidos en un turno; el resto espera al siguiente.
  final int maxBurst;

  /// Pipeline del turno agregado. Reentrada segura por conversación
  /// (serialización aquí, nunca dos ejecuciones simultáneas del mismo chat).
  final Map<String, _Bucket> _byConversation = {};

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
        runTurn,
  ) async {
    final results = List<List<RuleDispatchResult>>.filled(
      events.length,
      const [],
    );
    // Anclar conversaciones ANTES de cualquier await: los eventos viven en
    // una lista estable durante la tanda.
    final pending = <int, _Bucket>{};
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
          onTurnComplete: onTurnComplete,
          onResolved: (members, turnResults) {
            for (final m in members) {
              results[m.index] = turnResults;
            }
          },
          onIdle: () => _byConversation.remove(key),
        ),
      );
      pending[i] = bucket;
      onInbound?.call(key.startsWith('anon:') ? '' : key);
      bucket.push(event, index: i);
    }
    await Future.wait([
      for (final b in pending.values) b.resolved,
    ]);
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
    required this.onResolved,
    required this.onIdle,
    required this.onTurnComplete,
  });

  final String key;
  final Duration settle;
  final Duration maxWait;
  final int maxBurst;
  final Future<List<RuleDispatchResult>> Function(NotificationObject)
      runTurn;
  final void Function(List<_Member> members, List<RuleDispatchResult> results)
      onResolved;

  /// WA-STATE-01 — turno agregado terminado (conversación + notificación).
  final void Function(String conversationId, NotificationObject aggregated)?
  onTurnComplete;

  /// El bucket se retira SOLO cuando quedó vacío y sin turno en curso
  /// (nunca antes: un miembro en cola huérfano colgaría su futuro).
  final void Function() onIdle;

  final List<_Member> _queue = [];
  Timer? _settleTimer;
  Timer? _deadlineTimer;
  bool _running = false;
  final Completer<void> _resolved = Completer<void>();
  late final Future<void> resolved = _resolved.future;

  void push(NotificationObject event, {required int index}) {
    final member = _Member(event, index);
    if (_running) {
      // Turno en curso: el mensaje espera y formará el próximo turno
      // (serialización; nunca se pierde).
      _queue.add(member);
      return;
    }
    if (_queue.isEmpty) {
      _deadlineTimer = Timer(maxWait, _fire);
    }
    _queue.add(member);
    if (_queue.length >= maxBurst) {
      _fire(); // ráfaga completa: no esperar más
      return;
    }
    _settleTimer?.cancel();
    _settleTimer = Timer(settle, _fire);
  }

  Future<void> _fire() async {
    _settleTimer?.cancel();
    _deadlineTimer?.cancel();
    if (_running || _queue.isEmpty) return;
    _running = true;
    final members = List<_Member>.of(_queue);
    _queue.clear();
    try {
      final aggregated = _merge(members);
      debugPrint(
        '[turn] conv=${key.substring(0, key.length > 12 ? 12 : key.length)} '
        'agregados=${members.length} '
        'texto="${_sample(aggregated.messageText)}"',
      );
      final results = await runTurn(aggregated);
      // Sin await entre la resolución y el chequeo de cola: nadie puede
      // intercalar un push a mitad (un solo hilo de eventos).
      onTurnComplete?.call(key.startsWith('anon:') ? '' : key, aggregated);
      onResolved(members, results);
      if (!_resolved.isCompleted) _resolved.complete();
      if (_queue.isEmpty) onIdle();
    } on Object catch (e) {
      debugPrint('[turn] ráfaga falló: $e');
      onResolved(members, const []);
      if (!_resolved.isCompleted) _resolved.complete();
      if (_queue.isEmpty) onIdle();
    } finally {
      _running = false;
      // Lo que llegó durante el turno arranca su propia ventana.
      if (_queue.isNotEmpty && !_deadlineTimer!.isActive) {
        _deadlineTimer = Timer(maxWait, _fire);
        _settleTimer = Timer(settle, _fire);
      }
    }
  }

  /// El turno agregado: el ÚLTIMO evento es el ancla (identidad, capacidad
  /// de reply, timestamps); el texto une los mensajes en orden.
  NotificationObject _merge(List<_Member> members) {
    final anchor = members.last.event;
    final parts = [
      for (final m in members)
        _messageText(m.event).trim(),
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

  static String _sample(String raw) {
    final single = raw.replaceAll('\n', ' · ');
    return single.length <= 120 ? single : '${single.substring(0, 120)}…';
  }
}

class _Member {
  _Member(this.event, this.index);

  final NotificationObject event;

  /// Posición del evento en la tanda original (para resolver su futuro).
  final int index;
}
