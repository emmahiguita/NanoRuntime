import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/application/automation_feedback_presenter.dart';
import 'package:nanoai/features/automation/domain/automation_goal.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';
import 'package:nanoai/features/automation/engine/planning/linux_voice_command_parser.dart';
import 'package:nanoai/features/automation/engine/universal/universal_instruction_contract.dart';
import 'package:nanoai/features/automation/engine/universal/universal_instruction_coordinator.dart';

import '../../../core/models/chat_models.dart';
import '../domain/chat_turn_route_result.dart';

// QUÉ HACE:
// Ejecuta de forma determinista comandos Linux, contratos del Cerebro Universal y flujos en caché.
//
// CÓMO FUNCIONA:
// - Desacopla la invocación de herramientas del enrutamiento semántico.
// - Realiza verificaciones locales directas sin requerir alucinaciones de LLM.
//
// POR QUÉ:
// Aplica principios SOLID (Single Responsibility Principle) manteniendo los archivos
// bajo 140 líneas y eliminando cuellos de botella en la inferencia conversacional.
class ChatTurnPipelineExecutor {
  const ChatTurnPipelineExecutor();

  /// QUÉ HACE: Ejecuta un comando Linux determinista verificado.
  Future<ChatTurnRouteResult> executeLinux({
    required String text,
    required ParsedLinuxCommand linuxCmd,
    required AutomationCoordinator coordinator,
    required String? lastLinuxFilePath,
  }) async {
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

  /// QUÉ HACE: Ejecuta contratos multidominio del Cerebro Universal de Nano.
  Future<ChatTurnRouteResult> executeUniversal({
    required UniversalInstructionContract contract,
  }) async {
    final execRes = await const UniversalInstructionCoordinator()
        .executeContract(contract: contract);
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

  /// QUÉ HACE: Evalúa flujos en caché, catálogo estático y operaciones cross-app.
  Future<ChatTurnRouteResult?> tryCachedFlows({
    required String text,
    required AutomationCoordinator coordinator,
  }) async {
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
          text:
              'Objetivo resuelto:\n${automationUserFacingReason(flowResult.plan.summary)}',
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
          source: MessageSource.device,
        ),
      );
    }

    final known = await coordinator.tryKnownFlow(text);
    if (known != null) {
      return ChatTurnRouteResult.completed(
        deviceExecutionMessage(known.result),
      );
    }
    final crossApp = await coordinator.tryCrossApp(text);
    if (crossApp != null) {
      return ChatTurnRouteResult.completed(
        deviceExecutionMessage(crossApp.result),
      );
    }
    return null;
  }

  ChatMessage deviceExecutionMessage(AutomationResult result) => ChatMessage(
    id: DateTime.now().microsecondsSinceEpoch.toString(),
    sender: MessageSender.ai,
    // Terminar un intento no prueba éxito: los fallos no deben enseñar al LLM
    // que un código needsMoreEvidence fue una respuesta del asistente.
    text:
        '${result.isVerifiedSuccess ? 'Acción verificada' : 'Acción sin verificar'}:\n'
        '${automationUserFacingReason(result.reason)}',
    timestamp: DateTime.now(),
    source: MessageSource.device,
    status: result.isVerifiedSuccess ? MessageStatus.sent : MessageStatus.error,
  );
}
