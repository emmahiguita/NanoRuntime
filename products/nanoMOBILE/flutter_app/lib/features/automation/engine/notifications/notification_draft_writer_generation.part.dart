part of 'notification_draft_writer.dart';

// QUÉ HACE: Solicita una respuesta al proveedor cloud o al runtime local disponible.
// CÓMO FUNCIONA: Usa la cancelación del cliente LLM y cuenta cada proveedor invocado.
// POR QUÉ: Una falla real devuelve ausencia de borrador, nunca texto simulado.
Future<String?> _generateDraftReply(
  RuntimeNotificationDraftWriter writer,
  _PreparedDraftPrompt prepared,
  bool localReady, {
  Future<void> Function(String response)? onCloudResponse,
}) async {
  final hasCloudPort =
      writer._cloudInferencePort != null &&
      writer._cloudInferencePort.isConfigured;
  String? cloudRaw;
  if (hasCloudPort) {
    // Cuenta solo una llamada configurada que realmente va a iniciarse.
    MessagingMetrics.increment('semanticLlmCalls');
    cloudRaw = await writer._cloudInferencePort.generate(
      prompt: prepared.prompt,
      temperature: 0.3,
      maxTokens: prepared.maxTokens,
    );
  }
  if (cloudRaw != null && cloudRaw.trim().isNotEmpty) {
    await onCloudResponse?.call(cloudRaw);
    return cloudRaw;
  }
  if (!localReady) {
    localReady = await writer
        ._ensureReady(writer._modelPath())
        .timeout(const Duration(seconds: 25), onTimeout: () => false);
    if (!localReady) return null;
  }
  // QUÉ HACE: Ejecuta la inferencia local con la sesión única de este input.
  // CÓMO FUNCIONA: El cliente aplica su timeout configurado y cancela el request en el motor.
  // POR QUÉ: Un timeout exterior de Future no cancela el POST nativo y dejaba el modelo ocupado.
  MessagingMetrics.increment('semanticLlmCalls');
  return generateWithColdRetry(
    writer._client,
    prompt: prepared.prompt,
    temperature: 0.3,
    maxTokens: prepared.maxTokens,
    sessionId: prepared.sessionId,
    // Una sola copia del sistema; el texto variable viaja aparte para reutilizar KV.
    context: prepared.systemContext.isNotEmpty ? prepared.systemContext : null,
    history: prepared.history,
    // El runtime compartido conserva su timeout amplio para Chat/Terminal;
    // WhatsApp debe ceder con un margen realista de 180s en dispositivos móviles
    // durante carga/inferencia del modelo local.
    requestTimeout: const Duration(seconds: 180),
  );
}
