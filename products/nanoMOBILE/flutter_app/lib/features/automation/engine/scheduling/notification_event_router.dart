/// NotificationEventRouter — escucha eventos en vivo de notificación
/// (EventChannel `com.nanoai/notification_events`) y los enruta al RulePipeline
/// (trigger match → AutomationCoordinator). La notificación es UNTRUSTED DATA:
/// nunca se interpreta como instrucción ni autoridad.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';

import '../notifications/notification_object.dart';
import 'burst_turn_gate.dart';
import 'rule_pipeline.dart';

class NotificationEventRouter {
  NotificationEventRouter({required this.pipeline, this.gate});

  final RulePipeline pipeline;

  /// WA-TURN-01 — puerta de ráfagas por conversación (null = ruta directa
  /// legacy para pruebas).
  final BurstTurnGate? gate;
  StreamSubscription<Map<dynamic, dynamic>>? _sub;
  int _generation = 0;
  int _pendingBatches = 0;

  void start() {
    if (_sub != null) return;
    _sub = NanoRuntimeApi.instance.notificationEvents.listen(
      (m) => unawaited(_routeBatch(m)),
      onError: (Object e) {
        debugPrint('[notifications] event stream error: $e');
      },
    );
    final generation = ++_generation;
    unawaited(_coldStartReplay(generation));
  }

  Future<void> _routeBatch(Map<dynamic, dynamic> map) async {
    if (_pendingBatches >= 64) {
      debugPrint(
        '[notifications] router capacity reached; inbox retains event',
      );
      return;
    }
    _pendingBatches++;
    try {
      final events = NotificationObject.eventsFromMap(map);
      final g = gate;
      if (g == null) {
        for (final event in events) {
          await pipeline.onNotification(event);
        }
      } else {
        await pipeline.submitNotifications(events, g);
        // A replay may contain only duplicates of an admitted, unfinished burst.
        await g.drain();
      }
      await NanoRuntimeApi.instance.completeNotificationEvent(map);
    } catch (error) {
      debugPrint('[notifications] ingress deferred: $error');
    } finally {
      _pendingBatches--;
    }
  }

  /// WA-GAPS-01 — retry de arranque en frío: con la app recién arrancada (o
  /// tras un reinstall), el EventChannel solo entrega eventos EN VIVO; los
  /// mensajes que llegaron con el proceso muerto se perdían en silencio
  /// (sink nativo null → "NO PASA NADA" en dispositivo). El snapshot del
  /// listener re-emite las notificaciones ACTIVAS; el dedupe persistente
  /// (eventId determinista con messageTimestamp) bloquea las ya procesadas
  /// y deja pasar solo las nuevas. Reintenta si el listener aún no está
  /// conectado (list vacío); si hay notificaciones activas, replay y fin.
  Future<void> _coldStartReplay(int generation) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      await Future<void>.delayed(Duration(seconds: attempt == 0 ? 2 : 5));
      if (_sub == null || generation != _generation) return;
      final active = await NanoRuntimeApi.instance.listNotifications();
      if (_sub == null || generation != _generation) return;
      if (active.isEmpty) continue;
      for (final m in active) {
        unawaited(_routeBatch(m));
      }
      return;
    }
  }

  void stop() {
    _generation++;
    _sub?.cancel();
    _sub = null;
  }
}
