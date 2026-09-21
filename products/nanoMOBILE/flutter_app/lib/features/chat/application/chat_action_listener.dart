import '../../../core/models/chat_models.dart';

/// Contrato de notificación para actualizaciones de estado durante la
/// ejecución de turnos de chat e inferencia LLM.
abstract interface class ChatActionListener {
  void onStreamingText(String text);
  void onMessageAppended(ChatMessage message);

  /// Añade una llamada de herramienta visible sin cerrar el turno: la ronda
  /// LLM continúa y la UI debe mantener [ChatState.generating] activo.
  void onToolTraceAppended(ChatMessage message);
  void onInferenceSuccess({
    required ChatMessage aiMessage,
    required double? liveTps,
    required TurnMetrics? turnMetrics,
  });
  void onEngineError({
    required String errorText,
    required bool degraded,
    required bool engineOnline,
  });
  void onTurnError(String text);
  void onEngineReady();
  void onToolPaused(String? tool, String? description);
}
