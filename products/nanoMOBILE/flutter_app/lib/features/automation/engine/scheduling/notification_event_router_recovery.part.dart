part of 'notification_event_router.dart';

// Recuperación separada para mantener corto el router sin cambiar su dueño.
extension NotificationEventRouterRecovery on NotificationEventRouter {
  // Reprocesa el inbox persistente al volver a primer plano sin esperar 20 s.
  void drainPendingEvents() {
    if (_sub == null) return;
    unawaited(_drainBacklog(_generation));
  }

  // Rehidrata mensajes durables y snapshots activos con deduplicación de sesión.
  Future<void> _drainBacklog(int generation) async {
    if (_isDrainingBacklog) return;
    _isDrainingBacklog = true;
    try {
      if (_sub == null || generation != _generation) return;
      // Reclama el mutex antes del await: dos pulsos no pueden drenar en paralelo.
      if (!await canRecoverNotificationBacklog()) return;
      if (_sub == null || generation != _generation) return;
      final inboxEvents = await NanoRuntimeApi.instance.claimInbox(limit: 16);
      if (_sub == null || generation != _generation) return;
      for (final event in inboxEvents) {
        if (_sub == null || generation != _generation) break;
        await _routeBatch(event, generation, source: 'durable_inbox');
      }

      // El inbox conserva identidad; el contenido se rehidrata de Android.
      final active = await NanoRuntimeApi.instance.listNotifications();
      if (_sub == null || generation != _generation) return;
      if (!await canRecoverNotificationBacklog()) return;
      for (final event in active) {
        if (_sub == null || generation != _generation) break;
        final decoded = NotificationObject.eventsFromMap(event);
        final fingerprint = decoded
            .map(
              (item) => '${item.key}:${item.messageTimestamp}:${item.postTime}',
            )
            .join('|');
        if (fingerprint.isNotEmpty &&
            _coldStartSeenKeys.contains(fingerprint)) {
          continue;
        }
        if (fingerprint.isNotEmpty) _coldStartSeenKeys.add(fingerprint);
        await _routeBatch(event, generation, source: 'active_snapshot');
      }
    } catch (error, stack) {
      NotificationEventTrace.failure('backlog', 'durable_inbox', error, stack);
    } finally {
      _isDrainingBacklog = false;
    }
  }

  // Recupera tres veces al inicio porque el listener Android puede conectar tarde.
  Future<void> _coldStartReplay(int generation) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      await Future<void>.delayed(Duration(seconds: attempt == 0 ? 2 : 5));
      if (_sub == null || generation != _generation) return;
      if (!await canRecoverNotificationBacklog()) continue;
      final inboxEvents = await NanoRuntimeApi.instance.claimInbox(limit: 32);
      if (_sub == null || generation != _generation) return;
      for (final event in inboxEvents) {
        if (_sub == null || generation != _generation) return;
        await _routeBatch(event, generation, source: 'cold_start_inbox');
      }

      final active = await NanoRuntimeApi.instance.listNotifications();
      if (_sub == null || generation != _generation) return;
      if (inboxEvents.isEmpty && active.isEmpty) continue;
      for (final event in active) {
        if (_sub == null || generation != _generation) return;
        // Evita reinyectar la misma notificación activa cada ciclo de drenado.
        final decoded = NotificationObject.eventsFromMap(event);
        final fingerprint = decoded
            .map(
              (item) => '${item.key}:${item.messageTimestamp}:${item.postTime}',
            )
            .join('|');
        if (fingerprint.isNotEmpty &&
            _coldStartSeenKeys.contains(fingerprint)) {
          debugPrint(
            '[notifications] stage=cold_start_snapshot outcome=skipped detail=already_processed',
          );
          continue;
        }
        if (fingerprint.isNotEmpty) _coldStartSeenKeys.add(fingerprint);
        await _routeBatch(event, generation, source: 'cold_start_snapshot');
      }
      return;
    }
  }
}
