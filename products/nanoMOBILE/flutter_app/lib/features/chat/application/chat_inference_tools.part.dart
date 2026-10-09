part of 'chat_inference_coordinator.dart';

/// QUÉ: procesa una ronda de herramientas conservando permisos y cancelación.
/// CÓMO: devuelve feedback real o indica que la ronda pausó/terminó, sin inferir otra vez.
/// POR QUÉ: el orquestador mantiene la recursión; esta unidad no duplica navegación ni tools.
extension _ChatInferenceTools on ChatInferenceCoordinator {
  Future<({bool handled, String? feedback})> _handleToolReply({
    required String response,
    required String text,
    required List<String> trace,
    required int generationId,
    required bool Function() isMounted,
    required void Function(ChatMessage) onToolTraceAppended,
    required void Function(String?, String?) onToolPaused,
    required void Function(String) onError,
  }) async {
    final calls = AgentToolProtocol.extractToolCalls(response);
    if (calls.isEmpty ||
        (trace.length ~/ 2) >= ChatToolCoordinator.maxToolRounds) {
      return (handled: false, feedback: null);
    }
    const stopped = (handled: true, feedback: null);
    onToolTraceAppended(
      ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: response,
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      ),
    );
    final before = await tools.worldFingerprint();
    if (!streamSession.isGenerationCurrent(generationId, isMounted())) {
      return stopped;
    }
    final result = await coordinator.execute(
      AutomationGoal(text: text),
      plan: calls,
    );
    if (!streamSession.isGenerationCurrent(generationId, isMounted())) {
      return stopped;
    }
    if (result.isPaused && result.confirmation != null) {
      toolCoordinator.pausePlan(
        plan: calls,
        pauseIndex: result.pauseIndex,
        confirmation: result.confirmation,
        userText: text,
        trace: trace,
        callText: response,
      );
      onToolPaused(result.pauseTool, automationUserFacingReason(result.reason));
      return stopped;
    }
    final feedback = automationUserFacingReason(result.reason);
    final after = await tools.worldFingerprint();
    if (!streamSession.isGenerationCurrent(generationId, isMounted())) {
      return stopped;
    }
    if (toolCoordinator.isStalledToolRound(
      calls: calls,
      before: before,
      after: after,
      feedback: feedback,
    )) {
      onError(
        '[loopDetected] La misma herramienta devolvió el mismo resultado sin cambios.',
      );
      return stopped;
    }
    final lease = streamSession.activeStream;
    if (lease != null) streamSession.releaseStream(lease, 'entre rondas');
    return (handled: true, feedback: feedback);
  }
}
