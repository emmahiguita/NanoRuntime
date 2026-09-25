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

  void start() {
    if (_sub != null) return;
    final generation = ++_generation;
    _sub = NanoRuntimeApi.instance.notificationEvents.listen((m) {
      if (_sub == null || generation != _generation) return;
      unawaited(_routeBatch(m, generation));
    }, onError: (Object e) => debugPrint('[notifications] error en flujo: $e'));
    unawaited(_coldStartReplay(generation));
  }

  Future<void> _routeBatch(Map<dynamic, dynamic> map, int generation) async {
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

      final g = gate;
      if (g == null) {
        for (final event in validEvents) {
          if (_sub == null || generation != _generation) return;
          await pipeline.onNotification(event);
        }
      } else if (validEvents.isNotEmpty) {
        await pipeline.submitNotifications(validEvents, g);
        await g.drain();
      }
      if (_sub != null && generation == _generation) {
        await NanoRuntimeApi.instance.completeNotificationEvent(map);
      }
    } catch (error) {
      debugPrint('[notifications] ingreso de notificación diferido: $error');
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

  /// Cancela la fuente primero; los lotes ya iniciados observan la generación
  /// inválida y terminan sin despachar ni reactivar el drenado del backlog.
  Future<void> stop() async {
    _generation++;
    final subscription = _sub;
    _sub = null;
    _hasDeferredBatches = false;
    try {
      await subscription?.cancel();
    } catch (error) {
      debugPrint('[notifications] error cancelando flujo: $error');
    }

    // No se falsea el contador: cada lote conserva su `finally`. La espera
    // acotada permite teardown limpio sin dejar bloqueado el ciclo de Flutter.
    for (var attempt = 0; attempt < 15 && _pendingBatches > 0; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
