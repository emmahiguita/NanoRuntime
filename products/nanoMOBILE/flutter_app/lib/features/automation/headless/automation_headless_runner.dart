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
  final heartbeat = Timer.periodic(const Duration(seconds: 30), (_) {
    unawaited(
      _headlessChannel
          .invokeMethod<void>('heartbeat')
          .catchError((Object _) {}),
    );
  });
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
    final gate = container.read(burstTurnGateProvider);

    // Drenado: claim (Kotlin reserva + rehidrata desde notificaciones
    // ACTIVAS; contenido jamás persistido) → BurstTurnGate (ráfagas por
    // conversación → UN turno agregado) → pipeline → complete. Dos pasadas
    // vacías con asentamiento = idle → finish (el service para y libera).
    // Errores de canal o DB no se confunden con inbox vacío (reintenta hasta 3 veces).
    var emptyPasses = 0;
    var consecutiveErrors = 0;
    while (emptyPasses < 2 && consecutiveErrors < 3) {
      final claim = await _claimRows();
      if (claim is _ClaimFailure) {
        consecutiveErrors++;
        debugPrint(
          '[headless] error en claim (${claim.code}) — '
          'reintento $consecutiveErrors/3 con espera',
        );
        await Future<void>.delayed(const Duration(seconds: 3));
        continue;
      }
      consecutiveErrors = 0;
      final rows = (claim as _ClaimSuccess).rows;
      if (rows.isEmpty) {
        emptyPasses++;
        if (emptyPasses < 2) {
          await Future<void>.delayed(const Duration(seconds: 4));
        }
        continue;
      }
      emptyPasses = 0;
      final notifications = [
        for (final row in rows)
          if (row['notification'] is Map)
            ...NotificationObject.eventsFromMap(row['notification'] as Map),
      ];
      if (notifications.isNotEmpty) {
        try {
          await pipeline.submitNotifications(notifications, gate);
        } on Object catch (error) {
          debugPrint('[headless] tanda fallida: $error');
          rethrow; // Do not acknowledge an inbox batch whose admission failed.
        }
      }
      // A live sink may already own this batch's events; wait before ACK.
      await pipeline.drain(gate);
      for (final row in rows) {
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
    container.read(notificationEventRouterProvider).stop();
    await pipeline.drain(gate);
    debugPrint(
      consecutiveErrors >= 3
          ? '[headless] deteniendo por errores consecutivos en reclamo'
          : '[headless] idle — pidiendo parada limpia',
    );
  } on Object catch (error) {
    debugPrint('[headless] error fatal: $error');
  } finally {
    heartbeat.cancel();
    try {
      await _headlessChannel.invokeMethod<void>('finish');
    } on Object {
      // engine ya destruido: nada que pedir.
    }
    container.dispose();
  }
}

sealed class _ClaimResult {
  const _ClaimResult();
}

class _ClaimSuccess extends _ClaimResult {
  final List<Map<dynamic, dynamic>> rows;
  const _ClaimSuccess(this.rows);
}

class _ClaimFailure extends _ClaimResult {
  final String code;
  final String? message;
  const _ClaimFailure({required this.code, this.message});
}

Future<_ClaimResult> _claimRows() async {
  try {
    final raw = await _headlessChannel.invokeListMethod<dynamic>('claim', {
      'limit': 64,
    });
    return _ClaimSuccess([
      for (final r in raw ?? const [])
        if (r is Map) Map<dynamic, dynamic>.from(r),
    ]);
  } on PlatformException catch (e) {
    debugPrint('[headless] claim falló (${e.code}): ${e.message}');
    return _ClaimFailure(code: e.code, message: e.message);
  } on Object catch (error) {
    debugPrint('[headless] claim falló inesperado: $error');
    return _ClaimFailure(code: 'UNKNOWN', message: error.toString());
  }
}
