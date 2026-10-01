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
      // FIX-1: cuando el motor está en degraded (model_loaded=false), hacer
      // poll con backoff exponencial hasta 20s antes de caer al fallback.
      // Antes retornaba null al primer intento fallido, causando que todos los
      // mensajes del cold_start_snapshot fallaran mientras el modelo cargaba.
      localReady = await _waitForEngineReady(
        writer,
        maxWait: const Duration(seconds: 20),
      );
      if (!localReady) {
        debugPrint(
          '[draft] motor local no listo tras espera; delegando al fallback conversacional',
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
      // Cloud recibe el prompt completo; local recibe la personalidad por contexto.
      includePersonaInPrompt: hasCloudPort,
    );
    // QUÉ HACE: deja trazas de tamaño y ruta sin escribir el mensaje ni el prompt.
    // CÓMO FUNCIONA: compara historial, persona, prompt y proveedor antes de inferir.
    // POR QUÉ: separa prefill lento, contexto excesivo y proveedor sin configurar.
    debugPrint(
      '[draft:prepared] conv=${_shortId(conversationId)} '
      'promptChars=${prepared.prompt.length} historyEntries=${context.historyEntries.length} '
      'historyChars=${context.history.length} personaChars=${prepared.persona.length} '
      'systemChars=${prepared.systemContext.length} maxTokens=${prepared.maxTokens} '
      'nativeHistoryTurns=${prepared.history?.length ?? 0} '
      'social=${prepared.isSocial} localReady=$localReady cloudConfigured=$hasCloudPort '
      'provider=${writer._cloudInferencePort?.providerId ?? 'local'}',
    );
    // Solo se capturan respuestas cloud del agente personal con consentimiento explícito.
    final canLearnExternal =
        context.agentId == ConversationAgentId.personal &&
        context.role == ConversationAgentRole.personal &&
        writer._externalResponseLearningAllowed?.call(
              conversationId,
              notification.sender,
            ) ==
            true;
    final raw = await _generateDraftReply(
      writer,
      prepared,
      localReady,
      onCloudResponse: canLearnExternal
          ? (response) async {
              final provider = writer._cloudInferencePort?.providerId;
              final learner = writer._externalResponseLearner;
              if (provider == null || learner == null) return;
              try {
                await learner(
                  input: notification.interpretableText,
                  response: response,
                  provider: provider,
                );
              } on Object catch (error) {
                // El guardado es secundario: un fallo local no descarta el borrador válido.
                debugPrint(
                  '[draft-learning] candidate not stored: ${error.runtimeType}',
                );
              }
            }
          : null,
    );
    if (raw == null) return null;
    prepared.stopwatch.stop();
    debugPrint(
      '[latency:decomp] conv=${_shortId(conversationId)} '
      'genMs=${prepared.stopwatch.elapsedMilliseconds} '
      'promptChars=${prepared.prompt.length} rawChars=${raw.length} '
      'social=${prepared.isSocial}',
    );
    return _parseDraftOutput(
      raw,
      notification,
      conversationId,
      allowPlainText: prepared.isSocial,
    );
  } on Object catch (e) {
    // Motor local no disponible o falló → sin borrador (honesto).
    // El código de causa se conserva sin volcar respuestas HTTP con posible texto privado.
    debugPrint('[draft] falló: ${_draftFailureCode(e)}');
    return null;
  }
}

/// FIX-1: Poll con backoff exponencial esperando que el motor pase de
/// degraded a ready (model_loaded=true). Intervalos: 500ms → 1s → 2s → 4s
/// (tope), reintentando hasta agotar [maxWait].
/// Retorna true en cuanto el motor responde con readiness, false si se agota.
Future<bool> _waitForEngineReady(
  RuntimeNotificationDraftWriter writer, {
  required Duration maxWait,
}) async {
  final deadline = DateTime.now().add(maxWait);
  var delayMs = 500;
  while (DateTime.now().isBefore(deadline)) {
    final ready = await writer
        ._ensureReady(writer._modelPath())
        .timeout(const Duration(seconds: 6), onTimeout: () => false);
    if (ready) return true;
    final remaining = deadline.difference(DateTime.now()).inMilliseconds;
    if (remaining <= 0) break;
    final wait = delayMs.clamp(0, remaining);
    debugPrint('[draft] motor degraded — reintentando en ${wait}ms');
    await Future<void>.delayed(Duration(milliseconds: wait));
    delayMs = (delayMs * 2).clamp(0, 4000);
  }
  return false;
}
