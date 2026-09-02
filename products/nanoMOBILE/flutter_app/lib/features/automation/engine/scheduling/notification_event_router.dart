/// NotificationEventRouter — escucha eventos en vivo de notificación
/// (EventChannel `com.nanoai/notification_events`) y los enruta al RulePipeline
/// (trigger match → AutomationCoordinator). La notificación es UNTRUSTED DATA:
/// nunca se interpreta como instrucción ni autoridad.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';

import '../notifications/notification_object.dart';
import 'rule_pipeline.dart';

class NotificationEventRouter {
  NotificationEventRouter({required this.pipeline});

  final RulePipeline pipeline;
  StreamSubscription<Map<dynamic, dynamic>>? _sub;

  void start() {
    if (_sub != null) return;
    _sub = NanoRuntimeApi.instance.notificationEvents.listen(
      (m) {
        final notif = NotificationObject.fromMap(m);
        // WA-PHYS-11: traza de evento entrante (logcat tag flutter). Sin esta
        // línea el pipeline es mudo y los fallos físicos son indiagnosticables.
        debugPrint(
          '[notify-event] ${notif.packageName} key=${notif.key} '
          'sender=${notif.sender} msg="${notif.interpretableText}"',
        );
        unawaited(pipeline.onNotification(notif));
      },
      onError: (Object e) {
        debugPrint('[notifications] event stream error: $e');
      },
    );
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}
