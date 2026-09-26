part of 'notification_draft_writer.dart';

// QUÉ HACE: Coordina la generación de un borrador para un evento de notificación.
// CÓMO FUNCIONA: Verifica el motor, prepara contexto y valida el resultado del modelo.
// POR QUÉ: Si no hay salida usable, deja el turno para decisión humana.
Future<NotificationDraftResult?> _buildNotificationDraft(
  RuntimeNotificationDraftWriter writer,
  NotificationObject notification,
  String conversationId,
) async {
  try {
    final hasCloudPort =
        writer._cloudInferencePort != null &&
        writer._cloudInferencePort.isConfigured;
    var localReady = false;
    if (!hasCloudPort) {
      localReady = await writer
          ._ensureReady(writer._modelPath())
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              debugPrint(
                '[draft] ensureReady agotó 60s; sin borrador (honesto)',
              );
              return false;
            },
          );
      if (!localReady) {
        debugPrint(
          '[draft] motor local no quedó listo y sin proveedor cloud; sin borrador',
        );
        return null;
      }
    }
    debugPrint(
      '[draft:start] conv=${_shortId(conversationId)} '
      'inputChars=${notification.interpretableText.length} '
      'clientTimeoutSec=${writer._client.timeout.inSeconds}',
    );
    final context = await _resolveDraftContext(
      writer,
      notification,
      conversationId,
    );
    final prepared = _prepareDraftPrompt(
      writer,
      notification,
      conversationId,
      context,
    );
    final raw = await _generateDraftReply(writer, prepared, localReady);
    if (raw == null) return null;
    prepared.stopwatch.stop();
    debugPrint(
      '[latency:decomp] conv=${_shortId(conversationId)} '
      'genMs=${prepared.stopwatch.elapsedMilliseconds} '
      'promptChars=${prepared.prompt.length} rawChars=${raw.length} '
      'social=${prepared.isSocial}',
    );
    return _parseDraftOutput(raw, notification, conversationId);
  } on Object catch (e) {
    // Motor local no disponible o falló → sin borrador (honesto).
    // El código de causa se conserva sin volcar respuestas HTTP con posible texto privado.
    debugPrint('[draft] falló: ${_draftFailureCode(e)}');
    return null;
  }
}
