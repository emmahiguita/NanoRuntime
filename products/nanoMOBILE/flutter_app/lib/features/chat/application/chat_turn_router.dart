import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/application/automation_feedback_presenter.dart';
import 'package:nanoai/features/automation/domain/automation_goal.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/engine/planning/linux_voice_command_parser.dart';

import '../../browser_ai/application/browser_ai_gateway.dart';
import 'chat_control_intent.dart';
import 'web_ai_turn_router.dart';

import '../../../core/models/chat_models.dart';
import '../../../core/services/native_conversational_router.dart';
import '../domain/chat_turn_route_result.dart';

/// Enrutador determinista que procesa comandos locales y tareas factuales sin LLM.
///
/// **QUÉ HACE:**
/// Evalúa el mensaje del usuario antes de invocar la inferencia generativa pesada.
///
/// **CÓMO FUNCIONA:**
/// Inspecciona de forma priorizada cancelaciones, herramientas `@`, comandos Linux,
/// flujos en caché, catálogo estático, cross-app y router reactivo nativo.
///
/// **POR QUÉ:**
/// El LLM nunca debe realizar trabajo que un flujo determinista o local pueda resolver.
/// Esto ahorra batería, elimina alucinaciones y responde en <5ms.
class ChatTurnRouter {
  const ChatTurnRouter();

  Future<ChatTurnRouteResult> tryRoute({
    required String text,
    required AutomationCoordinator coordinator,
    required bool engineOnline,
    required String? activeModelPath,
    required String? lastLinuxFilePath,
    BrowserAiGateway? browserAiGateway,
  }) async {
    // 0. Consultas directas a Web AI (ChatGPT, DeepSeek, Gemini, etc.)
    if (browserAiGateway != null) {
      final webAiRes = await const WebAiTurnRouter().tryRoute(
        text: text,
        gateway: browserAiGateway,
      );
      if (webAiRes != null) return webAiRes;
    }

    // 1. Cancelación determinista inmediata
    if (ChatControlIntent.isCancellation(text)) {
      coordinator.cancelCurrent();
      return ChatTurnRouteResult.completed(
        ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: ChatControlIntent.cancellationReply(text),
          timestamp: DateTime.now(),
        ),
      );
    }

    // 2. Comandos `@` (ejecución directa de herramientas)
    if (AgentToolDispatcher.isToolCommand(text)) {
      final result = await coordinator.runCommand(text);
      return ChatTurnRouteResult.completed(
        ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: automationUserFacingReason(result),
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
        ),
      );
    }

    // 3. Comandos Linux deterministas (list/write/read)
    final linuxCmd = const LinuxVoiceCommandParser().parse(
      text,
      lastFilePath: lastLinuxFilePath,
    );
    if (linuxCmd != null) {
      String linuxText;
      String? newFilePath = lastLinuxFilePath;
      if (linuxCmd.call.tool == 'linux.writeFile') {
        final result = await coordinator.execute(
          AutomationGoal(text: text, expectation: linuxCmd.expectation),
          plan: [linuxCmd.call],
        );
        if (result.isVerifiedSuccess) {
          newFilePath = linuxCmd.call.text;
          linuxText =
              'Creé ${linuxCmd.call.text} y verifiqué su contenido (existe y contiene el texto).';
        } else {
          linuxText =
              'No se pudo crear ${linuxCmd.call.text}: ${automationUserFacingReason(result.reason)}';
        }
      } else {
        final outcome = await coordinator.runTool(linuxCmd.call);
        linuxText = outcome.feedback;
      }
      return ChatTurnRouteResult.completed(
        ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: linuxText,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
          source: MessageSource.device,
        ),
        lastLinuxFilePath: newFilePath,
      );
    }

    // 4. Flujos verificados en caché (C7->C8)
    final deterministic = await coordinator.tryDeterministic(text);
    if (deterministic != null) {
      final flowResult = deterministic.result;
      if (flowResult.plan.pauseIndex != null) {
        return ChatTurnRouteResult.pausePlan(
          plan: deterministic.steps,
          pauseIndex: flowResult.plan.pauseIndex,
          confirmation: flowResult.plan.confirmation,
          pauseTool: flowResult.plan.pauseCall?.tool,
          pauseDescription: automationUserFacingReason(flowResult.plan.summary),
        );
      }
      final feedback = [
        'Objetivo resuelto por flujo verificado (sin LLM):',
        automationUserFacingReason(flowResult.plan.summary),
        '[goal] ${flowResult.goal.reason}',
      ].join('\n');
      return ChatTurnRouteResult.completed(
        ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: feedback,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
          source: MessageSource.device,
        ),
      );
    }

    // 5. Catálogo estático conocido
    final known = await coordinator.tryKnownFlow(text);
    if (known != null) {
      if (known.result.isPaused) {
        return ChatTurnRouteResult.pausePlan(
          plan: known.steps,
          pauseIndex: known.result.pauseIndex,
          confirmation: known.result.confirmation,
          pauseTool: known.result.pauseTool,
          pauseDescription: automationUserFacingReason(known.result.reason),
        );
      }
      return ChatTurnRouteResult.completed(
        _deviceExecutionMessage(known.result),
      );
    }

    // 6. Tareas semánticas Cross-App
    final crossApp = await coordinator.tryCrossApp(text);
    if (crossApp != null) {
      if (crossApp.result.isPaused && crossApp.result.confirmation != null) {
        return ChatTurnRouteResult.pauseTask(
          taskGoal: text,
          confirmation: crossApp.result.confirmation!,
          pauseTool: crossApp.result.pauseTool,
          pauseDescription: automationUserFacingReason(crossApp.result.reason),
        );
      }
      return ChatTurnRouteResult.completed(
        _deviceExecutionMessage(crossApp.result),
      );
    }

    // 7. Enrutador conversacional reactivo nativo
    final hasActiveModel = engineOnline && activeModelPath != null;
    final nativeRes = const NativeConversationalRouter().tryResolve(
      text,
      hasModel: hasActiveModel,
    );
    if (nativeRes != null) {
      return ChatTurnRouteResult.completed(
        ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: nativeRes.text,
          timestamp: DateTime.now(),
          source: nativeRes.source,
          suggestions: nativeRes.suggestions,
          status: MessageStatus.sent,
        ),
      );
    }

    return const ChatTurnRouteResult.notHandled();
  }

  static ChatMessage _deviceExecutionMessage(
    AutomationResult result,
  ) => ChatMessage(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    sender: MessageSender.ai,
    text:
        'Ejecutado en el dispositivo (sin LLM):\n${automationUserFacingReason(result.reason)}',
    timestamp: DateTime.now(),
    source: MessageSource.device,
    status:
        const {
          AutomationResultStatus.denied,
          AutomationResultStatus.noPlan,
          AutomationResultStatus.failed,
          AutomationResultStatus.outcomeUnknown,
          AutomationResultStatus.cancelled,
        }.contains(result.status)
        ? MessageStatus.error
        : MessageStatus.sent,
  );
}
