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

part 'notification_event_router_recovery.part.dart';

class NotificationEventRouter {
  NotificationEventRouter({required this.pipeline, this.gate});

  final RulePipeline pipeline;
  final BurstTurnGate? gate;
  StreamSubscription<Map<dynamic, dynamic>>? _sub;
  int _generation = 0;
  int _pendingBatches = 0;
  bool _hasDeferredBatches = false;
  bool _isDrainingBacklog = false;

  // FIX-2: set de fingerprints de snapshots activos ya procesados en esta
  // sesión del router. Evita que _drainBacklog re-inyecte las mismas
  // notificaciones activas (que no tienen inbox eventId) en bucle cada 20s.
  final Set<String> _coldStartSeenKeys = {};

  Timer? _periodicDrainTimer;

  void start() {
    if (_sub != null) return;
    final generation = ++_generation;
    NotificationEventTrace.stage(
      'stream',
      source: 'event_channel',
      outcome: 'subscribing',
      detail: 'generation=$generation',
    );
    _sub = NanoRuntimeApi.instance.notificationEvents.listen(
      (m) {
        if (_sub == null || generation != _generation) return;
        unawaited(_routeBatch(m, generation, source: 'event_channel'));
      },
      onError: (Object e, StackTrace stack) =>
          NotificationEventTrace.failure('stream', 'event_channel', e, stack),
    );
    NotificationEventTrace.stage(
      'stream',
      source: 'event_channel',
      outcome: 'subscribed',
      detail: 'generation=$generation',
    );
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
          if (NotificationEventTrace.isWhatsApp(event))
            NotificationEventTrace.event(event, source, 'admitted');
        }
      }
      if (validEvents.isEmpty && events.isNotEmpty) {
        NotificationEventTrace.stage(
          'rule_pipeline',
          source: source,
          outcome: 'not_called',
          detail: 'reason=all_filtered',
        );
      }

      final g = gate;
      if (g == null) {
        for (final event in validEvents) {
          if (_sub == null || generation != _generation) return;
          if (NotificationEventTrace.isWhatsApp(event))
            NotificationEventTrace.event(event, source, 'pipeline_started');
          await pipeline.onNotification(event);
          if (NotificationEventTrace.isWhatsApp(event))
            NotificationEventTrace.event(event, source, 'pipeline_returned');
        }
      } else if (validEvents.isNotEmpty) {
        NotificationEventTrace.stage(
          'burst_gate',
          source: source,
          outcome: 'submitting',
          detail: 'events=${validEvents.length}',
        );
        await pipeline.submitNotifications(validEvents, g);
        await g.drain();
        NotificationEventTrace.stage(
          'burst_gate',
          source: source,
          outcome: 'drained',
        );
      }
      if (_sub != null && generation == _generation) {
        await NanoRuntimeApi.instance.completeNotificationEvent(map);
        NotificationEventTrace.stage(
          'durable_inbox',
          source: source,
          outcome: 'acknowledged',
        );
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

  /// Cancela el canal y espera los lotes activos antes de liberar el router.
  Future<void> stop() async {
    _generation++;
    _periodicDrainTimer?.cancel();
    _periodicDrainTimer = null;
    _coldStartSeenKeys.clear();
    final subscription = _sub;
    _sub = null;
    _hasDeferredBatches = false;
    try {
      await subscription?.cancel();
    } catch (error, stack) {
      NotificationEventTrace.failure(
        'stream_cancel',
        'event_channel',
        error,
        stack,
      );
    }
    for (var attempt = 0; attempt < 15 && _pendingBatches > 0; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
