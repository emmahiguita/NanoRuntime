part of 'notification_draft_writer.dart';

/// Ejecuta la llamada de generación en la API Cloud (`Groq`/`Gemini`) o en el
/// motor Open Source local (`LiteRT-LM`) sin destruir el KV-cache con reintentos
/// innecesarios.
///
/// - **QUÉ HACE:** Solicita el borrador al proveedor correspondiente y registra
///   la telemetría real del turno.
/// - **CÓMO FUNCIONA:** Si [useCloudFirst] es `true`, invoca primero el puerto
///   multi-API (`Groq` -> `Gemini`); de lo contrario, usa `LiteRT-LM` local
///   manteniendo estable el `systemContext` para no invalidar el KV-cache.
/// - **POR QUÉ:** Evita el doble prefill de 10–12 segundos que ocurría cuando
///   falsos positivos forzaban una segunda generación completa.
Future<String?> _generateDraftReply(
  RuntimeNotificationDraftWriter writer,
  _PreparedDraftPrompt prepared,
  bool localReady, {
  bool useCloudFirst = false,
  Future<void> Function(String response)? onCloudResponse,
  String conversationId = '',
  int queuedAtMs = 0,
  String? systemOverride,
  bool allowQualityRetry = true,
}) async {
  ExecutionBudget.current?.check();
  final cloudPort = writer._cloudInferencePort;
  final shouldTryCloud =
      useCloudFirst && cloudPort != null && cloudPort.isConfigured;
  String? cloudRaw;
  if (shouldTryCloud) {
    MessagingMetrics.increment('semanticLlmCalls');
    final cloudRequestId = LLMEngineClient.newRequestId();
    final cloudQueuedAt = queuedAtMs > 0
        ? queuedAtMs
        : DateTime.now().millisecondsSinceEpoch;
    InferenceTelemetry.begin(
      conversationId: conversationId,
      requestId: cloudRequestId,
      promptChars: prepared.prompt.length,
      historyEntries: prepared.history?.length ?? 0,
      queuedAtMs: cloudQueuedAt,
    );
    try {
      cloudRaw = await cloudPort.generate(
        prompt: prepared.cloudPrompt,
        temperature: 0.3,
        maxTokens: prepared.maxTokens,
      );
      InferenceTelemetry.complete(requestId: cloudRequestId);
      if (cloudRaw != null && cloudRaw.trim().isNotEmpty) {
        InferenceTelemetry.markUsed(cloudRequestId);
      } else {
        InferenceTelemetry.markDiscarded(cloudRequestId);
      }
    } on Object {
      InferenceTelemetry.complete(requestId: cloudRequestId);
      InferenceTelemetry.markDiscarded(cloudRequestId);
    }
  }
  if (cloudRaw != null && cloudRaw.trim().isNotEmpty) {
    ExecutionBudget.current?.check();
    await onCloudResponse?.call(cloudRaw);
    return cloudRaw;
  }
  if (!localReady) {
    localReady = await writer
        ._ensureReady(writer._modelPath())
        .timeout(const Duration(seconds: 25), onTimeout: () => false);
    if (!localReady) return null;
  }

  final budget =
      ExecutionBudget.current ?? ExecutionBudget(const Duration(seconds: 180));
  Duration remaining() => budget.remaining;
  final turnRequestId = LLMEngineClient.newRequestId();
  var turnRequestIdUsed = false;

  Future<String> generateLocal(String system) {
    ExecutionBudget.current?.check();
    final timeout = remaining();
    if (timeout <= Duration.zero) {
      throw TimeoutException('Plazo de redacción local agotado');
    }
    MessagingMetrics.increment('semanticLlmCalls');
    final reqId = turnRequestIdUsed
        ? LLMEngineClient.newRequestId()
        : turnRequestId;
    final wait = turnRequestIdUsed ? 0 : queuedAtMs;
    turnRequestIdUsed = true;
    return budget.run(
      () => generateWithColdRetry(
        writer._client,
        prompt: prepared.prompt,
        temperature: 0.3,
        maxTokens: prepared.maxTokens,
        sessionId: prepared.sessionId,
        context: system.isNotEmpty ? system : null,
        history: prepared.history,
        requestTimeout: timeout,
        requestId: reqId,
        queuedAtMs: wait,
      ),
    );
  }

  final systemContext = systemOverride ?? prepared.systemContext;
  final raw = await generateLocal(systemContext);
  if (raw.trim().isNotEmpty) {
    InferenceTelemetry.markUsed(turnRequestId);
  } else {
    InferenceTelemetry.markDiscarded(turnRequestId);
  }
  return raw;
}
