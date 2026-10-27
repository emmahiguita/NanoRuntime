part of 'chat_inference_coordinator.dart';

/// QUÉ: prepara evidencia y crea el mensaje final sin duplicar la ejecución de tools.
/// CÓMO: reutiliza el mismo proveedor de reloj/clima que Nano Personal.
/// POR QUÉ: una charla no consulta IP ni descarga catálogos innecesarios.
extension _ChatInferenceContext on ChatInferenceCoordinator {
  Future<String> _buildTurnSystem({
    required String text,
    required List<ChatMessage> history,
    required String activeModel,
    required String sessionId,
    required String memoryContext,
  }) async {
    final needsTools = ChatContextBuilder.requiresToolCatalog(text);
    final contexts = await Future.wait<Object>([
      needsTools
          ? mcpContextFor?.call(text) ?? Future.value('')
          : Future.value(''),
      skillContextFor?.call(text) ?? Future.value(''),
      RuntimePersonalLiveContext().resolve(
        text,
        history
            .where((message) => message.sender == MessageSender.user)
            .map((message) => message.text)
            .toList(),
        scopeId: 'internal|$sessionId',
      ),
    ]);
    final liveEvidence = contexts[2] as PersonalLiveEvidence;
    return ChatSystemPrompt.build(
      registry: tools.registry,
      modelName: activeModel,
      now: DateTime.now(),
      device: DeviceInfo.read(),
      memoryContext: memoryContext,
      includeTools: needsTools,
      mcpContext: contexts[0] as String,
      skillContext: contexts[1] as String,
      ambientContext: liveEvidence.block,
    );
  }

  // Solo convierte salida real; no fabrica mensajes ni corrige slang con plantillas.
  ChatMessage? _completedMessage(String text, double? tps) {
    final clean = StreamSanitizer.sanitize(text);
    if (clean.trim().isEmpty || !PersonalLanguagePolicy.accepts(clean)) {
      return null;
    }
    return ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sender: MessageSender.ai,
      text: clean,
      timestamp: DateTime.now(),
      tps: tps,
      suggestions: ChatSuggestionEngine.derive(clean),
      status: MessageStatus.sent,
    );
  }
}
