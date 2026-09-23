/// QUÉ HACE:
/// Enruta deterministamente turnos de usuario evaluando herramientas locales,
/// comandos Linux, flujos cacheados y el Cerebro Universal de instrucciones compuestas.
///
/// CÓMO FUNCIONA:
/// Prioriza cancelaciones, llamadas `@`, comandos Linux, descomposición semántica universal
/// (Data Studio, Catálogo, Alertas) y flujos nativos antes de invocar la inferencia generativa.
///
/// POR QUÉ:
/// Garantiza respuestas instantáneas en <5ms para tareas deterministas y ejecuta
/// órdenes compuestas multidominio sin alucinaciones de LLM (< 200 líneas).
library;

import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/application/automation_feedback_presenter.dart';
import 'package:nanoai/features/automation/domain/automation_goal.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/engine/planning/linux_voice_command_parser.dart';
import 'package:nanoai/features/automation/engine/universal/universal_instruction_contract.dart';
import 'package:nanoai/features/automation/engine/universal/universal_instruction_coordinator.dart';
import 'package:nanoai/features/automation/engine/universal/universal_instruction_parser.dart';

import '../../browser_ai/application/browser_ai_gateway.dart';
import 'chat_control_intent.dart';
import 'web_ai_turn_router.dart';

import '../../../core/models/chat_models.dart';
import '../../../core/services/native_conversational_router.dart';
import '../domain/chat_turn_route_result.dart';

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
    // 0. Consultas directas a Web AI (ChatGPT, DeepSeek, etc.)
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
      return ChatTurnRouteResult.completed(ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: ChatControlIntent.cancellationReply(text),
        timestamp: DateTime.now(),
      ));
    }

    // 2. Comandos `@` directos
    if (AgentToolDispatcher.isToolCommand(text)) {
      final result = await coordinator.runCommand(text);
      return ChatTurnRouteResult.completed(ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: automationUserFacingReason(result),
        timestamp: DateTime.now(),
        status: MessageStatus.sent,
      ));
    }

    // 3. Comandos Linux deterministas
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
          linuxText = 'Creé ${linuxCmd.call.text} y verifiqué su contenido.';
        } else {
          linuxText = 'No se pudo crear ${linuxCmd.call.text}: ${automationUserFacingReason(result.reason)}';
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

    // 4. Cerebro Universal: Instrucciones compuestas multidominio
    final contract = const UniversalInstructionParser().parse(
      text: text,
      lastLinuxFilePath: lastLinuxFilePath,
    );
    if (contract.executionMode != InstructionExecutionMode.conversationalOnly &&
        contract.obligations.length >= 2) {
      final execRes = await const UniversalInstructionCoordinator().executeContract(contract: contract);
      return ChatTurnRouteResult.completed(
        ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: execRes.userMessage,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
          suggestions: execRes.responseOptions,
          source: MessageSource.device,
        ),
      );
    }

    // 5. Flujos verificados en caché
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
      return ChatTurnRouteResult.completed(
        ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: 'Objetivo resuelto:\n${automationUserFacingReason(flowResult.plan.summary)}',
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
          source: MessageSource.device,
        ),
      );
    }

    // 6. Catálogo estático y tareas Cross-App
    final known = await coordinator.tryKnownFlow(text);
    if (known != null) {
      return ChatTurnRouteResult.completed(_deviceExecutionMessage(known.result));
    }
    final crossApp = await coordinator.tryCrossApp(text);
    if (crossApp != null) {
      return ChatTurnRouteResult.completed(_deviceExecutionMessage(crossApp.result));
    }

    // 7. Enrutador conversacional reactivo nativo
    final hasActiveModel = engineOnline && activeModelPath != null;
    final nativeRes = const NativeConversationalRouter().tryResolve(
      text,
      hasModel: hasActiveModel,
    );
    if (nativeRes != null) {
      return ChatTurnRouteResult.completed(ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        sender: MessageSender.ai,
        text: nativeRes.text,
        timestamp: DateTime.now(),
        source: nativeRes.source,
        suggestions: nativeRes.suggestions,
        status: MessageStatus.sent,
      ));
    }

    return const ChatTurnRouteResult.notHandled();
  }

  static ChatMessage _deviceExecutionMessage(AutomationResult result) => ChatMessage(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    sender: MessageSender.ai,
    text: 'Ejecutado en el dispositivo:\n${automationUserFacingReason(result.reason)}',
    timestamp: DateTime.now(),
    source: MessageSource.device,
    status: (result.status == AutomationResultStatus.completed ||
            result.status == AutomationResultStatus.completedUnverified)
        ? MessageStatus.sent
        : MessageStatus.error,
  );
}
