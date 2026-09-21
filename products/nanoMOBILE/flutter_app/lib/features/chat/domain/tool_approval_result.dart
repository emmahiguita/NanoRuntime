import '../../../core/models/chat_models.dart';

/// Modelo de dominio inmutable que representa el resultado de pausar o continuar
/// la ejecución de una herramienta tras la interacción o confirmación humana.
///
/// **QUÉ HACE:**
/// Encapsula las acciones derivadas de la aprobación de una herramienta:
/// mensajes a registrar, necesidad de reanudar el LLM y traza acumulada.
///
/// **CÓMO FUNCIONA:**
/// Es un Value Object puro sin lógica mutable consumido por `ChatToolCoordinator`
/// y `ChatToolApprovalUseCase`.
///
/// **POR QUÉ:**
/// Desacopla el estado de aprobación del tool caller, permitiendo que la capa
/// de aplicación reaccione sin acoplarse a widgets ni a la lógica interna de Riverpod.
class ToolApprovalResult {
  final ChatMessage? completedMessage;
  final bool shouldResumeGeneration;
  final String? resumeUserText;
  final List<String>? resumeTrace;
  final String? pendingTool;
  final String? pendingToolDescription;

  const ToolApprovalResult({
    this.completedMessage,
    this.shouldResumeGeneration = false,
    this.resumeUserText,
    this.resumeTrace,
    this.pendingTool,
    this.pendingToolDescription,
  });
}
