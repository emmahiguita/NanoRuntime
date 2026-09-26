part of 'notification_draft_writer.dart';

// QUÉ HACE: Deduplica eventos repetidos y encola turnos nuevos por input.
// CÓMO FUNCIONA: Registra solo metadatos, descarta turnos obsoletos y libera la cola.
// POR QUÉ: Evita respuestas cruzadas sin exponer mensajes privados en Logcat.
Future<NotificationDraftResult?> _enqueueNotificationDraft(
  RuntimeNotificationDraftWriter writer,
  NotificationObject notification,
) async {
  if (!writer._llmAllowed()) return null;
  final conversationId = resolveConversationIdentity(notification).key.id;
  final flightKey =
      '$conversationId|${RuntimeNotificationDraftWriter._flightFingerprint(notification)}';
  final inFlight = RuntimeNotificationDraftWriter._inFlight[flightKey];
  if (inFlight != null) {
    debugPrint(
      '[draft:flight] HIT conv=${_shortId(conversationId)} '
      'inputChars=${notification.text.length}',
    );
    return inFlight;
  }
  debugPrint(
    '[draft:flight] MISS conv=${_shortId(conversationId)} '
    'inputChars=${notification.text.length}',
  );
  if (RuntimeNotificationDraftWriter._queueDepth >=
      RuntimeNotificationDraftWriter._maxQueueDepth) {
    debugPrint('[draft:queue] full; no generation admitted');
    return null;
  }
  RuntimeNotificationDraftWriter._queueDepth++;
  MessagingMetrics.queueDepth(RuntimeNotificationDraftWriter._queueDepth);
  debugPrint(
    '[draft:queue] depth=${RuntimeNotificationDraftWriter._queueDepth}',
  );

  RuntimeNotificationDraftWriter._latestFlightKeyByConv[conversationId] =
      flightKey;
  final arrivedAt = DateTime.now();

  final future = RuntimeNotificationDraftWriter._draftTail.then((_) async {
    // AUT-P1-08: Coalescing por conversación — si llegó un mensaje nuevo
    // mientras este esperaba en cola, se descarta el borrador obsoleto.
    if (RuntimeNotificationDraftWriter._latestFlightKeyByConv[conversationId] !=
        flightKey) {
      debugPrint(
        '[draft:coalesce] superseded conv=${_shortId(conversationId)} '
        'inputChars=${notification.text.length}',
      );
      return null;
    }
    // AUT-P1-08: Deadline de frescura — si pasaron más de 45s esperando en cola,
    // la notificación está desactualizada y se descarta limpiamente.
    if (DateTime.now().difference(arrivedAt).inSeconds > 45) {
      debugPrint(
        '[draft:deadline] expired (>45s in queue) conv=${_shortId(conversationId)}',
      );
      return null;
    }
    return _buildNotificationDraft(writer, notification, conversationId);
  });
  RuntimeNotificationDraftWriter._draftTail = future.then<void>(
    (_) {},
    onError: (Object _) {},
  );

  RuntimeNotificationDraftWriter._inFlight[flightKey] = future;
  try {
    return await future;
  } finally {
    RuntimeNotificationDraftWriter._queueDepth--;
    if (identical(
      RuntimeNotificationDraftWriter._inFlight[flightKey],
      future,
    )) {
      RuntimeNotificationDraftWriter._inFlight.remove(flightKey);
    }
    if (RuntimeNotificationDraftWriter._latestFlightKeyByConv[conversationId] ==
        flightKey) {
      RuntimeNotificationDraftWriter._latestFlightKeyByConv.remove(
        conversationId,
      );
    }
  }
}
