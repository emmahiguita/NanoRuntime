part of 'notification_draft_writer.dart';

// QUÉ HACE: Solicita una respuesta al proveedor cloud o al runtime local disponible.
// CÓMO FUNCIONA: Usa la cancelación del cliente LLM y cuenta cada proveedor invocado.
// POR QUÉ: Una falla real devuelve ausencia de borrador, nunca texto simulado.
Future<String?> _generateDraftReply(
  RuntimeNotificationDraftWriter writer,
  _PreparedDraftPrompt prepared,
  bool localReady, {
  Future<void> Function(String response)? onCloudResponse,
  // LOOP-1-TELEMETRY — correlación del turno (sin contenido).
  String conversationId = '',
  int queuedAtMs = 0,
}) async {
  ExecutionBudget.current?.check();
  final cloudPort = writer._cloudInferencePort;
  final hasCloudPort = cloudPort != null && cloudPort.isConfigured;
  String? cloudRaw;
  if (hasCloudPort) {
    // Cuenta solo una llamada configurada que realmente va a iniciarse.
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
        prompt: prepared.prompt,
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
      rethrow;
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
  // QUÉ HACE: Ejecuta la inferencia local con la sesión única de este input.
  // CÓMO FUNCIONA: El cliente aplica su timeout configurado y cancela el request en el motor.
  // POR QUÉ: Un timeout exterior de Future no cancela el POST nativo y dejaba el modelo ocupado.
  final budget =
      ExecutionBudget.current ?? ExecutionBudget(const Duration(seconds: 180));
  // QUÉ: limita ambas inferencias al mismo plazo, nunca dos esperas completas.
  // CÓMO: conserva el cliente, sampler, sesión e historial real de este chat.
  // POR QUÉ: corregir estilo no debe dejar trabajo nativo sin límite ni mezclar chats.
  Duration remaining() => budget.remaining;
  // LOOP-1-TELEMETRY — el request_id del TURNO correlaciona la primera
  // llamada local; retries (frío/estilo) conservan ids propios del cliente.
  final turnRequestId = LLMEngineClient.newRequestId();
  var turnRequestIdUsed = false;
  var lastRequestId = turnRequestId;
  Future<String> generate(String system) {
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
    lastRequestId = reqId;
    // La zona también limita el retry de arranque frío y registra su cancelación.
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

  final raw = await generate(prepared.systemContext);
  // QUÉ: permite una sola regeneración real del estilo rechazado observado en Emm.
  // CÓMO: reutiliza la misma guarda; no añade el borrador rechazado al historial.
  // POR QUÉ: retener sin intentar otra redacción hacía parecer apagado al agente.
  // Negocios/cloud y problemas factuales o de permisos NO entran en este reintento.
  if (hasCloudPort ||
      !prepared.isSocial ||
      !ConversationDecisionGuards.isCallCenterPhrase(raw) ||
      remaining() <= Duration.zero) {
    if (raw.trim().isNotEmpty) {
      InferenceTelemetry.markUsed(turnRequestId);
    } else {
      InferenceTelemetry.markDiscarded(turnRequestId);
    }
    return raw;
  }
  debugPrint('[draft:quality] callcenter=detected retry=1');
  try {
    final revised = await generate(
      '${prepared.systemContext}\n'
      'La redacción anterior se rechazó por sonar a atención al cliente. '
      'Redacta de nuevo para una conversación personal: responde al mensaje '
      'actual, sin ofrecer asistencia ni añadir preguntas de servicio. '
      'No inventes el estado del dueño. No expliques esta revisión.',
    );
    debugPrint(
      '[draft:quality] retry=completed '
      'callcenter=${ConversationDecisionGuards.isCallCenterPhrase(revised)}',
    );
    // El parser y todas las guardas de envío siguen validando la salida nueva.
    if (revised.trim().isEmpty) {
      InferenceTelemetry.markDiscarded(lastRequestId);
      InferenceTelemetry.markUsed(turnRequestId);
      return raw;
    }
    InferenceTelemetry.markDiscarded(turnRequestId);
    InferenceTelemetry.markUsed(lastRequestId);
    return revised;
  } on Object catch (error) {
    budget.check();
    if (raw.trim().isNotEmpty) InferenceTelemetry.markUsed(turnRequestId);
    debugPrint(
      '[draft:quality] retry=failed cause=${_draftFailureCode(error)}',
    );
    // Conserva el borrador real para revisión; jamás crea una respuesta fija.
    return raw;
  }
}
