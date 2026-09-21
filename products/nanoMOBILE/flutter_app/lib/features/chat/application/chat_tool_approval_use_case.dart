import 'package:nanoai/features/automation/application/automation_coordinator.dart';

import '../../../core/models/chat_models.dart';
import 'chat_action_listener.dart';
import 'chat_send_use_case.dart';
import 'chat_stream_session.dart';
import 'chat_tool_coordinator.dart';

/// Caso de uso que procesa las decisiones del usuario ante herramientas en pausa.
///
/// **QUÉ HACE:**
/// Gestiona la aprobación o el rechazo de herramientas que requieren confirmación humana
/// antes de realizar escrituras externas o cambios irreversibles.
///
/// **CÓMO FUNCIONA:**
/// - Si el usuario **aprueba**: reanuda el plan desde el paso autorizado o la tarea Cross-App,
///   y reanuda la inferencia con el resultado en el trace.
/// - Si el usuario **rechaza**: descarta la ejecución y reanuda el turno informando al modelo
///   de la cancelación de la herramienta.
///
/// **POR QUÉ:**
/// Cumple con la política de gobernanza y consentimiento explícito sin mezclar la lógica
/// de aprobación con el caso de uso de envío general (Principio de Responsabilidad Única - SRP).
class ChatToolApprovalUseCase {
  final AutomationCoordinator coordinator;
  final ChatToolCoordinator toolCoordinator;
  final ChatStreamSession streamSession;
  final ChatSendUseCase sendUseCase;

  const ChatToolApprovalUseCase({
    required this.coordinator,
    required this.toolCoordinator,
    required this.streamSession,
    required this.sendUseCase,
  });

  /// Ejecuta la aprobación del paso de herramienta o tarea semántica pendiente.
  Future<void> approve({
    required String activeModel,
    required String sessionId,
    required bool Function() isMounted,
    required List<ChatMessage> Function() getMessages,
    required ChatActionListener listener,
    required void Function() onSetGenerating,
  }) async {
    final res = await toolCoordinator.approvePending(coordinator: coordinator);
    if (res == null || !isMounted()) return;

    if (res.pendingTool != null) {
      listener.onToolPaused(res.pendingTool, res.pendingToolDescription);
      return;
    }

    if (res.completedMessage != null) {
      listener.onMessageAppended(res.completedMessage!);
      return;
    }

    if (res.shouldResumeGeneration && res.resumeUserText != null) {
      onSetGenerating();
      await sendUseCase.resumeInference(
        text: res.resumeUserText!,
        trace: res.resumeTrace ?? const [],
        attachments: const [],
        generationId: streamSession.beginGeneration(),
        activeModel: activeModel,
        sessionId: sessionId,
        isMounted: isMounted,
        getMessages: getMessages,
        listener: listener,
      );
    }
  }

  /// Ejecuta el rechazo del paso de herramienta pendiente por parte del usuario.
  Future<void> reject({
    required String? pendingTool,
    required String activeModel,
    required String sessionId,
    required bool Function() isMounted,
    required List<ChatMessage> Function() getMessages,
    required ChatActionListener listener,
    required void Function() onSetGenerating,
  }) async {
    final rejected = toolCoordinator.rejectPending(pendingTool);
    if (rejected == null || !isMounted()) return;

    onSetGenerating();
    await sendUseCase.resumeInference(
      text: rejected.userText,
      trace: rejected.trace,
      attachments: const [],
      generationId: streamSession.beginGeneration(),
      activeModel: activeModel,
      sessionId: sessionId,
      isMounted: isMounted,
      getMessages: getMessages,
      listener: listener,
    );
  }
}
