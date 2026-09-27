// notification_event_router.dart
//
// QUÉ HACE:
// Escucha eventos de notificaciones en tiempo real desde el EventChannel nativo
// (`com.nanoai/notification_events`) y los enruta de forma controlada hacia el `RulePipeline`.
//
// CÓMO FUNCIONA:
// - Controla la concurrencia mediante `_pendingBatches` y amortigua ráfagas en `BurstTurnGate`.
// - Filtra difusiones de estados y reacciones a historias con `WhatsAppStatusClassifier`.
// - Maneja el arranque en frío recuperando eventos no procesados de la cola durable `DurableInbox`.
// - Invalida callbacks en vuelo por generación y espera el cierre antes de soltar estado.
//
// POR QUÉ:
// Previene que reacciones o difusiones de estados disparen respuestas automáticas erróneas (<200 líneas).

library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';

import '../notifications/notification_object.dart';
import '../platform/whatsapp_status_classifier.dart';
import 'burst_turn_gate.dart';
import 'notification_event_trace.dart';
import 'rule_pipeline.dart';

class NotificationEventRouter {
  NotificationEventRouter({required this.pipeline, this.gate});

  final RulePipeline pipeline;
  final BurstTurnGate? gate;
  StreamSubscription<Map<dynamic, dynamic>>? _sub;
  int _generation = 0;
  int _pendingBatches = 0;
  bool _hasDeferredBatches = false;
  bool _isDrainingBacklog = false;

  Timer? _periodicDrainTimer;

  void start() {
    if (_sub != null) return;
    final generation = ++_generation;
    NotificationEventTrace.stage('stream', source: 'event_channel', outcome: 'subscribing', detail: 'generation=$generation');
    _sub = NanoRuntimeApi.instance.notificationEvents.listen((m) {
      if (_sub == null || generation != _generation) return;
      unawaited(_routeBatch(m, generation, source: 'event_channel'));
    }, onError: (Object e, StackTrace stack) =>
        NotificationEventTrace.failure('stream', 'event_channel', e, stack));
    NotificationEventTrace.stage('stream', source: 'event_channel', outcome: 'subscribed', detail: 'generation=$generation');
    unawaited(_coldStartReplay(generation));
    // Drenado periódico de resiliencia: si un evento quedó en DurableInbox mientras
    // la app estaba suspendida o en background, lo recupera y procesa sin demora.
    _periodicDrainTimer?.cancel();
    _periodicDrainTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_sub != null && generation == _generation && _pendingBatches == 0) {
        unawaited(_drainBacklog(generation));
      }
    });
  }

  Future<void> _routeBatch(
    Map<dynamic, dynamic> map,
    int generation, {
    required String source,
  }) async {
    if (_sub == null || generation != _generation) return;

    if (_pendingBatches >= 64) {
      _hasDeferredBatches = true;
      debugPrint(
        '[notifications] capacidad máxima alcanzada (64); evento retenido',
      );
      return;
    }

    _pendingBatches++;
    try {
      final events = NotificationObject.eventsFromMap(map);
      // Excluir estados e historias de WhatsApp antes de admitir al pipeline
      final validEvents = events
          .where((e) => !WhatsAppStatusClassifier.shouldIgnoreFromChatHub(e))
          .toList();
      NotificationEventTrace.batch(source, events.length, validEvents.length);
      if (source != 'active_snapshot') {
        for (final event in validEvents) {
          if (NotificationEventTrace.isWhatsApp(event)) NotificationEventTrace.event(event, source, 'admitted');
        }
      }
      if (validEvents.isEmpty && events.isNotEmpty) {
        NotificationEventTrace.stage('rule_pipeline', source: source, outcome: 'not_called', detail: 'reason=all_filtered');
      }

      final g = gate;
      if (g == null) {
        for (final event in validEvents) {
          if (_sub == null || generation != _generation) return;
          if (NotificationEventTrace.isWhatsApp(event)) NotificationEventTrace.event(event, source, 'pipeline_started');
          await pipeline.onNotification(event);
          if (NotificationEventTrace.isWhatsApp(event)) NotificationEventTrace.event(event, source, 'pipeline_returned');
        }
      } else if (validEvents.isNotEmpty) {
        NotificationEventTrace.stage('burst_gate', source: source, outcome: 'submitting', detail: 'events=${validEvents.length}');
        await pipeline.submitNotifications(validEvents, g);
        await g.drain();
        NotificationEventTrace.stage('burst_gate', source: source, outcome: 'drained');
      }
      if (_sub != null && generation == _generation) {
        await NanoRuntimeApi.instance.completeNotificationEvent(map);
        NotificationEventTrace.stage('durable_inbox', source: source, outcome: 'acknowledged');
      }
    } catch (error, stack) {
      NotificationEventTrace.failure('route_deferred', source, error, stack);
    } finally {
      _pendingBatches--;
      if (_pendingBatches <= 16 &&
          _hasDeferredBatches &&
          _sub != null &&
          generation == _generation) {
        _hasDeferredBatches = false;
        unawaited(_drainBacklog(_generation));
      }
    }
  }

  Future<void> _drainBacklog(int generation) async {
    if (_isDrainingBacklog) return;
    _isDrainingBacklog = true;
    try {
      if (_sub == null || generation != _generation) return;
      final inboxEvents = await NanoRuntimeApi.instance.claimInbox(limit: 16);
      if (_sub == null || generation != _generation) return;
      for (final m in inboxEvents) {
        if (_sub == null || generation != _generation) break;
        await _routeBatch(m, generation, source: 'durable_inbox');
      }
      // Revisa también notificaciones activas porque el inbox conserva solo su identidad;
      // el contenido real se rehidrata desde Android antes de procesar el evento.
      final active = await NanoRuntimeApi.instance.listNotifications();
      if (_sub == null || generation != _generation) return;
      for (final m in active) {
        if (_sub == null || generation != _generation) break;
        await _routeBatch(m, generation, source: 'active_snapshot');
      }
    } catch (e, stack) {
      NotificationEventTrace.failure('backlog', 'durable_inbox', e, stack);
    } finally {
      _isDrainingBacklog = false;
    }
  }

  Future<void> _coldStartReplay(int generation) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      await Future<void>.delayed(Duration(seconds: attempt == 0 ? 2 : 5));
      if (_sub == null || generation != _generation) return;

      final inboxEvents = await NanoRuntimeApi.instance.claimInbox(limit: 32);
      if (_sub == null || generation != _generation) return;

      for (final m in inboxEvents) {
        if (_sub == null || generation != _generation) return;
        await _routeBatch(m, generation, source: 'cold_start_inbox');
      }

      final active = await NanoRuntimeApi.instance.listNotifications();
      if (_sub == null || generation != _generation) return;
      if (inboxEvents.isEmpty && active.isEmpty) continue;

      for (final m in active) {
        if (_sub == null || generation != _generation) return;
        await _routeBatch(m, generation, source: 'cold_start_snapshot');
      }
      return;
    }
  }

  /// Cancela la fuente primero; los lotes ya iniciados observan la generación
  /// inválida y terminan sin despachar ni reactivar el drenado del backlog.
  Future<void> stop() async {
    _generation++;
    _periodicDrainTimer?.cancel();
    _periodicDrainTimer = null;
    final subscription = _sub;
    _sub = null;
    _hasDeferredBatches = false;
    try {
      await subscription?.cancel();
    } catch (error, stack) {
      NotificationEventTrace.failure('stream_cancel', 'event_channel', error, stack);
    }

    // No se falsea el contador: cada lote conserva su `finally`. La espera
    // acotada permite teardown limpio sin dejar bloqueado el ciclo de Flutter.
    for (var attempt = 0; attempt < 15 && _pendingBatches > 0; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
