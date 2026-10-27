part of 'notification_draft_writer.dart';

/// Coordina la redacción del borrador combinando el modelo Open Source local
/// (`LiteRT-LM`) y las APIs configuradas en la nube (`Groq` / `Gemini`).
///
/// - **QUÉ HACE:** Prepara el contexto vivo (`<CONTEXTO DEL TURNO>`), decide si
///   el turno actual lo atiende primero el modelo Open Source local o la nube
///   según [CloudSynergyMode], y aplica rescate cruzado si alguno falla.
/// - **CÓMO FUNCIONA:**
///   1. En modo `hybridAssist`, `LiteRT-LM` responde turnos breves y delega
///      párrafos complejos (o borradores rechazados por `QualityGate`) a Groq/Gemini.
///   2. Si Groq/Gemini responde, `ExternalResponseExperienceLearningService`
///      guarda el ejemplo en SQLite FTS4 para que el modelo local aprenda.
/// - **POR QUÉ:** Logra que el modelo Open Source local y las APIs trabajen en
///   equipo sin duplicar flujos ni dejar al usuario sin opciones de respuesta.
Future<NotificationDraftResult?> _buildNotificationDraft(
  RuntimeNotificationDraftWriter writer,
  NotificationObject notification,
  String conversationId, {
  int queuedAtMs = 0,
}) async {
  try {
    if (PersonalConversationDiagnostic.appliesTo(conversationId) &&
        !PersonalConversationDiagnostic.includesTimestamp(
          IncomingMessage.fromNotification(notification).messageTimestamp,
        )) {
      debugPrint('[ctx:conversation] diagnostic_old_event=skipped');
      return null;
    }
    await CloudGenerativeInferenceAdapter.ensureLoaded();
    final cloudPort = writer._cloudInferencePort;
    final useCloudPrimary =
        cloudPort != null &&
        cloudPort.shouldUseCloudForTurn(messageText: notification.requestText);
    final hasCloudRescue = cloudPort != null && cloudPort.isConfigured;

    var localReady = false;
    if (!useCloudPrimary) {
      localReady = await _waitForEngineReady(
        writer,
        maxWait: const Duration(seconds: 45),
      );
      if (!localReady && !hasCloudRescue) {
        debugPrint('[draft] motor local no listo y sin API cloud configurada');
        return null;
      }
    }

    final context = await _resolveDraftContext(
      writer,
      notification,
      conversationId,
    );
    if (context.agentId == ConversationAgentId.personal) {
      await const PersonalTurnStateAccess().merge(
        conversationId,
        currentTopic: context.activeTopic,
        openLoops: OpenLoopDetector.detect(
          notification.requestText,
          nowMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }

    final preferCloudNow = useCloudPrimary || !localReady;
    final prepared = _prepareDraftPrompt(
      writer,
      notification,
      conversationId,
      context,
      includePersonaInPrompt: preferCloudNow,
    );
    debugPrint(
      '[draft:prepared] conv=${_shortId(conversationId)} '
      'promptChars=${prepared.prompt.length} historyEntries=${context.historyEntries.length} '
      'localReady=$localReady preferCloud=$preferCloudNow '
      'provider=${preferCloudNow ? (cloudPort?.providerId ?? 'cloud') : 'local'}',
    );

    final canLearnExternal =
        context.agentId == ConversationAgentId.personal &&
        context.role == ConversationAgentRole.personal &&
        writer._externalResponseLearningAllowed?.call(
              conversationId,
              notification.sender,
            ) ==
            true;

    Future<void> learnFromCloud(String response) async {
      if (!canLearnExternal) return;
      final provider = writer._cloudInferencePort?.providerId;
      final learner = writer._externalResponseLearner;
      if (provider == null || learner == null) return;
      try {
        await learner(
          input: notification.requestText,
          response: response,
          provider: provider,
        );
      } on Object catch (error) {
        debugPrint('[draft-learning] candidate skipped: ${error.runtimeType}');
      }
    }

    var raw = await _generateDraftReply(
      writer,
      prepared,
      localReady,
      useCloudFirst: preferCloudNow,
      conversationId: conversationId,
      queuedAtMs: queuedAtMs,
      allowQualityRetry: true,
      onCloudResponse: learnFromCloud,
    );
    if (raw == null) return null;

    ExecutionBudget.current?.check();
    prepared.stopwatch.stop();
    final allowPlain =
        prepared.isSocial ||
        (context.agentId == ConversationAgentId.personal &&
            context.role == ConversationAgentRole.personal);

    var result = parseNotificationDraftOutput(
      raw,
      notification,
      conversationId,
      allowPlainText: allowPlain,
    );

    // Co-piloto: si el modelo Open Source local falló QualityGate y hay API
    // de Groq/Gemini configurada en modo híbrido, la nube rescata el turno.
    if (result == null && !preferCloudNow && hasCloudRescue) {
      debugPrint('[draft:co-pilot] local rechazado -> rescate con API cloud');
      final cloudRaw = await cloudPort.generate(
        prompt: prepared.cloudPrompt,
        temperature: 0.3,
        maxTokens: prepared.maxTokens,
      );
      if (cloudRaw != null && cloudRaw.trim().isNotEmpty) {
        await learnFromCloud(cloudRaw);
        result = parseNotificationDraftOutput(
          cloudRaw,
          notification,
          conversationId,
          allowPlainText: true,
        );
      }
    }

    if (result != null &&
        context.liveEvidence.weatherRequested &&
        !context.liveEvidence.weatherAvailable) {
      return NotificationDraftResult(
        reply: result.reply,
        understanding: result.understanding.withRequiredAction(),
      );
    }
    return result;
  } on Object catch (e) {
    debugPrint('[draft] falló: ${_draftFailureCode(e)}');
    return null;
  }
}

/// Espera la disponibilidad del motor local (`LiteRT-LM`, `MNN` o `GGUF`).
Future<bool> _waitForEngineReady(
  RuntimeNotificationDraftWriter writer, {
  required Duration maxWait,
}) async {
  final modelPath = writer._modelPath();
  ExecutionBudget.current?.check();
  final backend = NeuralCatalog.backendForPath(modelPath);
  if (backend == ModelBackendType.mnn || backend == ModelBackendType.litertlm) {
    return writer
        ._ensureReady(modelPath)
        .timeout(maxWait, onTimeout: () => false);
  }
  final deadline = DateTime.now().add(maxWait);
  var delayMs = 500;
  while (DateTime.now().isBefore(deadline)) {
    ExecutionBudget.current?.check();
    final ready = await writer
        ._ensureReady(modelPath)
        .timeout(const Duration(seconds: 6), onTimeout: () => false);
    if (ready) return true;
    final remaining = deadline.difference(DateTime.now()).inMilliseconds;
    if (remaining <= 0) break;
    await Future<void>.delayed(
      Duration(milliseconds: delayMs.clamp(0, remaining)),
    );
    delayMs = (delayMs * 2).clamp(0, 4000);
  }
  return false;
}
