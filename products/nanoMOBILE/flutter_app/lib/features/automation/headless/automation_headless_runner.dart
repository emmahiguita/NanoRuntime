/// WA-PROD-01 — runtime headless de automatización (Variante 1 aprobada).
///
/// Se ejecuta DENTRO del AutomationRuntimeService (Android) sobre un
/// FlutterEngine sin UI: el MISMO main() de la app detecta el canal
/// `com.nanoai/headless` (pre-registrado por Kotlin ANTES de ejecutar Dart) y,
/// en vez de runApp(), corre este bootstrap.
///
/// El cerebro Dart se REUSA íntegro vía el grafo Riverpod del módulo (un solo
/// pipeline, nunca un motor paralelo): settings → stores hidratados (barrera)
/// → RulePipeline → drenado del DurableInbox nativo (claim/complete) →
/// journal. El router de eventos vivos y el ticker de hora también arrancan:
/// mientras el engine vive, los mensajes que llegan se procesan igual que con
/// la UI abierta.
library;

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart';
import 'package:nanoai/features/automation/engine/notifications/notification_object.dart';

const _headlessChannel = MethodChannel('com.nanoai/headless');

/// ¿Este engine es el runtime headless del servicio? El canal solo existe en
/// el AutomationRuntimeService; en el engine de la UI la invocación falla
/// (MissingPluginException) y devuelve false.
Future<bool> isHeadlessAutomationEngine() async {
  try {
    return await _headlessChannel
            .invokeMethod<bool>('isHeadless')
            .timeout(const Duration(milliseconds: 1500)) ==
        true;
  } on Object {
    return false;
  }
}

/// WA-PROD-01 — punto de entrada headless (ver doc de librería).
Future<void> runAutomationHeadless() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  try {
    // WA-PROD-02 — barrera global: el MISMO futuro que espera el
    // RulePipeline antes de cada evento (una sola fuente de verdad).
    await container.read(automationStoresHydratedProvider);
    debugPrint('[headless] stores hidratados — drenando inbox');

    // Router de eventos vivos + ticker de hora: mientras el engine viva el
    // comportamiento es el mismo que con la UI abierta.
    container.read(notificationEventRouterProvider);
    container.read(timeTickSchedulerProvider);

    final pipeline = container.read(rulePipelineProvider);

    // Drenado: claim (Kotlin reserva + rehidrata desde notificaciones
    // ACTIVAS; contenido jamás persistido) → pipeline → complete. Dos pasadas
    // vacías con asentamiento = idle → finish (el service para y libera).
    var emptyPasses = 0;
    while (emptyPasses < 2) {
      final rows = await _claimRows();
      if (rows.isEmpty) {
        emptyPasses++;
        if (emptyPasses < 2) {
          await Future<void>.delayed(const Duration(seconds: 4));
        }
        continue;
      }
      emptyPasses = 0;
      for (final row in rows) {
        final payload = row['notification'];
        if (payload is Map) {
          try {
            final notif = NotificationObject.fromMap(payload);
            await pipeline.onNotification(notif);
          } on Object catch (error) {
            // Un evento fallido jamás tumba el drenado; el pipeline ya
            // registró el estado honesto del intento.
            debugPrint('[headless] evento fallido: $error');
          }
        }
        final eventId = row['eventId'];
        if (eventId is String && eventId.isNotEmpty) {
          try {
            await _headlessChannel.invokeMethod<void>('complete', {
              'eventId': eventId,
            });
          } on Object {
            // El service pudo detenerse (UI attach): la fila RESERVED se
            // re-reclama vieja en el próximo wake (stale + dedupe).
          }
        }
      }
    }
    debugPrint('[headless] idle — pidiendo parada limpia');
  } on Object catch (error) {
    debugPrint('[headless] error fatal: $error');
  } finally {
    try {
      await _headlessChannel.invokeMethod<void>('finish');
    } on Object {
      // engine ya destruido: nada que pedir.
    }
    container.dispose();
  }
}

Future<List<Map<dynamic, dynamic>>> _claimRows() async {
  try {
    final raw = await _headlessChannel.invokeListMethod<dynamic>('claim', {
      'limit': 10,
    });
    return [
      for (final r in raw ?? const [])
        if (r is Map) Map<dynamic, dynamic>.from(r),
    ];
  } on Object catch (error) {
    debugPrint('[headless] claim falló: $error');
    return const [];
  }
}
