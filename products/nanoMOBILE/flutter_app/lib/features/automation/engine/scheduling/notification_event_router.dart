// notification_event_router.dart
//
// QUÉ HACE:
// Escucha eventos de notificaciones en tiempo real desde el EventChannel nativo
// (`com.nanoai/notification_events`) y los enruta de forma controlada hacia el `RulePipeline`.
//
// CÓMO FUNCIONA:
// - Controla la concurrencia mediante `_pendingBatches` y amortigua ráfagas en `BurstTurnGate`.
// - Maneja el arranque en frío recuperando eventos no procesados de la cola durable `DurableInbox`.
// - Soporta detención determinista (`stop`) esperando la cancelación de la suscripción nativa
//   e invalidando cualquier replay o callback en vuelo mediante un token de generación creciente.
//
// POR QUÉ:
// Resuelve la carrera de apagado y la saturación ciega de admisión (AUT-P2-15), garantizando
// que los eventos no se pierdan ni se admitan de forma zombi tras desmontar el router (< 200 líneas).

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

  /// Puerta de agregación de ráfagas por conversación (BurstTurnGate).
  final BurstTurnGate? gate;
  StreamSubscription<Map<dynamic, dynamic>>? _sub;
  int _generation = 0;
  int _pendingBatches = 0;
  bool _hasDeferredBatches = false;
  bool _isDrainingBacklog = false;

  /// Inicia la escucha activa de eventos nativos y el replay de arranque en frío.
  void start() {
    if (_sub != null) return;
    final generation = ++_generation;
    _sub = NanoRuntimeApi.instance.notificationEvents.listen(
      (m) {
        if (_sub == null || generation != _generation) return;
        unawaited(_routeBatch(m, generation));
      },
      onError: (Object e) {
        debugPrint('[notifications] error en flujo de eventos: $e');
      },
    );
    unawaited(_coldStartReplay(generation));
  }

  /// Procesa un lote individual de notificaciones respetando la capacidad máxima del sistema.
  Future<void> _routeBatch(Map<dynamic, dynamic> map, int generation) async {
    if (_sub == null || generation != _generation) return;

    if (_pendingBatches >= 64) {
      _hasDeferredBatches = true;
      debugPrint('[notifications] capacidad máxima alcanzada (64); evento retenido en DurableInbox');
      return;
    }

    _pendingBatches++;
    try {
      final events = NotificationObject.eventsFromMap(map);
      final g = gate;
      if (g == null) {
        for (final event in events) {
          if (_sub == null || generation != _generation) return;
          await pipeline.onNotification(event);
        }
      } else {
        await pipeline.submitNotifications(events, g);
        await g.drain();
      }
      if (_sub != null && generation == _generation) {
        await NanoRuntimeApi.instance.completeNotificationEvent(map);
      }
    } catch (error) {
      debugPrint('[notifications] ingreso de notificación diferido: $error');
    } finally {
      _pendingBatches--;
      if (_pendingBatches <= 16 && _hasDeferredBatches && _sub != null && generation == _generation) {
        _hasDeferredBatches = false;
        unawaited(_drainBacklog(_generation));
      }
    }
  }

  /// Drena eventos pendientes de la base de datos DurableInbox cuando la cola recupera capacidad.
  Future<void> _drainBacklog(int generation) async {
    if (_isDrainingBacklog) return;
    _isDrainingBacklog = true;
    try {
      if (_sub == null || generation != _generation) return;
      final inboxEvents = await NanoRuntimeApi.instance.claimInbox(limit: 16);
      if (_sub == null || generation != _generation) return;
      for (final m in inboxEvents) {
        if (_sub == null || generation != _generation) break;
        await _routeBatch(m, generation);
      }
      final active = await NanoRuntimeApi.instance.listNotifications();
      if (_sub == null || generation != _generation) return;
      for (final m in active) {
        if (_sub == null || generation != _generation) break;
        await _routeBatch(m, generation);
      }
    } catch (e) {
      debugPrint('[notifications] error drenando backlog: $e');
    } finally {
      _isDrainingBacklog = false;
    }
  }

  /// Recuperación serializada en frío de eventos pendientes en SQLite al iniciar el runtime.
  Future<void> _coldStartReplay(int generation) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      await Future<void>.delayed(Duration(seconds: attempt == 0 ? 2 : 5));
      if (_sub == null || generation != _generation) return;

      final inboxEvents = await NanoRuntimeApi.instance.claimInbox(limit: 32);
      if (_sub == null || generation != _generation) return;

      for (final m in inboxEvents) {
        if (_sub == null || generation != _generation) return;
        await _routeBatch(m, generation);
      }

      final active = await NanoRuntimeApi.instance.listNotifications();
      if (_sub == null || generation != _generation) return;
      if (inboxEvents.isEmpty && active.isEmpty) continue;

      for (final m in active) {
        if (_sub == null || generation != _generation) return;
        await _routeBatch(m, generation);
      }
      return;
    }
  }

  /// Detención determinista y asíncrona del router, cancelando la suscripción nativa.
  Future<void> stop() async {
    _generation++;
    final sub = _sub;
    _sub = null;
    try {
      await sub?.cancel();
    } catch (_) {}

    // Espera hasta 1.5s para que los batches en vuelo terminen limpiamente
    for (var i = 0; i < 15 && _pendingBatches > 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Método de conveniencia sincrónico para teardown en callbacks de frameworks.
  void dispose() => unawaited(stop());
}
