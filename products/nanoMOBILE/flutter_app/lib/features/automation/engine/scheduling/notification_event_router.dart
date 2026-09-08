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
  bool _hasDeferredBatches = false;
  bool _isDrainingBacklog = false;

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
      _hasDeferredBatches = true;
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
      if (_pendingBatches <= 16 && _hasDeferredBatches) {
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
      final inboxEvents = await NanoRuntimeApi.instance.claimInbox(limit: 32);
      if (_sub == null || generation != _generation) return;
      for (final m in inboxEvents) {
        if (_sub == null || generation != _generation) break;
        await _routeBatch(m);
      }
      final active = await NanoRuntimeApi.instance.listNotifications();
      if (_sub == null || generation != _generation) return;
      for (final m in active) {
        if (_sub == null || generation != _generation) break;
        await _routeBatch(m);
      }
    } catch (e) {
      debugPrint('[notifications] backlog drain error: $e');
    } finally {
      _isDrainingBacklog = false;
    }
  }

  /// WA-GAPS-01 / WA-PROD-01 — retry de arranque en frío y recuperación de cola durable:
  /// Con la app recién arrancada (o tras un reboot/kill de ColorOS), recupera primero
  /// los eventos pendientes de la cola durable SQLite (DurableInbox) y luego re-emite
  /// las notificaciones ACTIVAS. El dedupe persistente bloquea las ya procesadas.
  Future<void> _coldStartReplay(int generation) async {
    unawaited(NanoRuntimeApi.instance.cleanupInbox());
    for (var attempt = 0; attempt < 3; attempt++) {
      await Future<void>.delayed(Duration(seconds: attempt == 0 ? 2 : 5));
      if (_sub == null || generation != _generation) return;
      final inboxEvents = await NanoRuntimeApi.instance.claimInbox(limit: 64);
      if (_sub == null || generation != _generation) return;
      if (inboxEvents.isNotEmpty) {
        for (final m in inboxEvents) {
          unawaited(_routeBatch(m));
        }
      }
      final active = await NanoRuntimeApi.instance.listNotifications();
      if (_sub == null || generation != _generation) return;
      if (inboxEvents.isEmpty && active.isEmpty) continue;
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
