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

  void start() {
    if (_sub != null) return;
    _sub = NanoRuntimeApi.instance.notificationEvents.listen(
      (m) {
        final notif = NotificationObject.fromMap(m);
        _route(notif);
      },
      onError: (Object e) {
        debugPrint('[notifications] event stream error: $e');
      },
    );
    unawaited(_coldStartReplay());
  }

  void _route(NotificationObject notif) {
    // WA-PHYS-11: traza de evento entrante (logcat tag flutter). Sin esta
    // línea el pipeline es mudo y los fallos físicos son indiagnosticables.
    debugPrint(
      '[notify-event] ${notif.packageName} key=${notif.key} '
      'sender=${notif.sender} msg="${notif.interpretableText}"',
    );
    final g = gate;
    if (g != null) {
      // WA-TURN-01: los mensajes de una ráfaga de la misma conversación se
      // agregan en un único turno del pipeline.
      unawaited(g.submit(notif, (aggregated) => pipeline.onNotification(aggregated)));
      return;
    }
    unawaited(pipeline.onNotification(notif));
  }

  /// WA-GAPS-01 — retry de arranque en frío: con la app recién arrancada (o
  /// tras un reinstall), el EventChannel solo entrega eventos EN VIVO; los
  /// mensajes que llegaron con el proceso muerto se perdían en silencio
  /// (sink nativo null → "NO PASA NADA" en dispositivo). El snapshot del
  /// listener re-emite las notificaciones ACTIVAS; el dedupe persistente
  /// (eventId determinista con messageTimestamp) bloquea las ya procesadas
  /// y deja pasar solo las nuevas. Reintenta si el listener aún no está
  /// conectado (list vacío); si hay notificaciones activas, replay y fin.
  Future<void> _coldStartReplay() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      await Future<void>.delayed(
        Duration(seconds: attempt == 0 ? 2 : 5),
      );
      final active = await NanoRuntimeApi.instance.listNotifications();
      if (active.isEmpty) continue;
      for (final m in active) {
        _route(NotificationObject.fromMap(m));
      }
      return;
    }
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
