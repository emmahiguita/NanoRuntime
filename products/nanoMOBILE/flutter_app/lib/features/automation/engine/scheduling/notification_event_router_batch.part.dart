part of 'notification_event_router.dart';

// QUÉ: procesa snapshots recuperados como una sola tanda.
// CÓMO: decodifica, filtra, admite y drena una vez; confirma cada mapa al final.
// POR QUÉ: el arranque anterior repetía flush, métricas y gate por notificación.
extension NotificationEventRouterBatch on NotificationEventRouter {
  List<Map<dynamic, dynamic>> _unseenSnapshots(
    List<Map<dynamic, dynamic>> maps,
  ) {
    final unseen = <Map<dynamic, dynamic>>[];
    for (final map in maps) {
      final fingerprint = NotificationObject.eventsFromMap(map)
          .map(
            (item) => '${item.key}:${item.messageTimestamp}:${item.postTime}',
          )
          .join('|');
      if (fingerprint.isNotEmpty && !_coldStartSeenKeys.add(fingerprint)) {
        continue;
      }
      unseen.add(map);
    }
    return unseen;
  }

  Future<void> _routeRecoveredMaps(
    List<Map<dynamic, dynamic>> maps,
    int generation, {
    required String source,
  }) async {
    if (maps.isEmpty || _sub == null || generation != _generation) return;
    if (!await canRecoverNotificationBacklog()) return;
    if (_sub == null || generation != _generation) return;
    if (_pendingBatches >= 64) {
      _hasDeferredBatches = true;
      return;
    }

    _pendingBatches++;
    try {
      final decoded = [
        for (final map in maps) ...NotificationObject.eventsFromMap(map),
      ];
      final valid = decoded
          .where(
            (event) => !WhatsAppStatusClassifier.shouldIgnoreFromChatHub(event),
          )
          .toList(growable: false);
      NotificationEventTrace.batch(source, decoded.length, valid.length);

      final activeGate = gate;
      if (activeGate == null) {
        for (final event in valid) {
          if (_sub == null || generation != _generation) return;
          await pipeline.onNotification(event);
        }
      } else if (valid.isNotEmpty) {
        await pipeline.submitNotifications(valid, activeGate);
        await activeGate.drain();
      }

      if (_sub == null || generation != _generation) return;
      for (final map in maps) {
        await NanoRuntimeApi.instance.completeNotificationEvent(map);
      }
      NotificationEventTrace.stage(
        'durable_inbox',
        source: source,
        outcome: 'acknowledged_batch',
        detail: 'maps=${maps.length} events=${valid.length}',
      );
    } catch (error, stack) {
      NotificationEventTrace.failure('route_batch', source, error, stack);
    } finally {
      _pendingBatches--;
    }
  }
}
