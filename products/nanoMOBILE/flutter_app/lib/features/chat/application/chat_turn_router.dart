/// QUÉ HACE:
/// Enruta deterministamente turnos de usuario evaluando herramientas locales,
/// comandos Linux, flujos cacheados y el Cerebro Universal de instrucciones compuestas.
///
/// CÓMO FUNCIONA:
/// Prioriza cancelaciones, llamadas `@`, comandos Linux, descomposición semántica universal
/// (Data Studio, Catálogo, Alertas) y flujos nativos antes de invocar la inferencia generativa.
///
/// POR QUÉ:
/// Reserva las respuestas generativas al modelo seleccionado y conserva las
/// operaciones locales verificables sin atribuirlas al motor de inferencia.
library;

import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/application/automation_feedback_presenter.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/engine/planning/linux_voice_command_parser.dart';
import 'package:nanoai/features/automation/engine/universal/universal_instruction_contract.dart';
import 'package:nanoai/features/automation/engine/universal/universal_instruction_parser.dart';

import '../../browser_ai/application/browser_ai_gateway.dart';
import 'chat_control_intent.dart';
import 'chat_messaging_turn_router.dart';
import 'chat_turn_pipeline_executor.dart';
import 'web_ai_turn_router.dart';
import '../domain/chat_context_builder.dart';
import '../domain/chat_memory_tools.dart';

import '../../../core/models/chat_models.dart';
import '../../database/application/data_chat_command_router.dart';
import '../domain/chat_turn_route_result.dart';

class ChatTurnRouter {
  final ChatTurnPipelineExecutor _pipeline = const ChatTurnPipelineExecutor();

  const ChatTurnRouter();

  Future<ChatTurnRouteResult> tryRoute({
    required String text,
    required AutomationCoordinator coordinator,
    required bool engineOnline,
    required String? activeModelPath,
    required String? lastLinuxFilePath,
    bool preferConfiguredApi = false,
    bool hasAttachments = false,
    List<ChatMessage> chatHistory = const [],
    BrowserAiGateway? browserAiGateway,
  }) async {
    // 0. Consultas directas a Web AI (ChatGPT, DeepSeek, etc.)
    if (browserAiGateway != null) {
      final webAiRes = await const WebAiTurnRouter().tryRoute(text: text, gateway: browserAiGateway);
      if (webAiRes != null) return webAiRes;
    }

    // 1. Cancelación determinista inmediata
    if (ChatControlIntent.isCancellation(text)) {
      coordinator.cancelCurrent();
      return ChatTurnRouteResult.completed(
        ChatMessage(id: DateTime.now().microsecondsSinceEpoch.toString(), sender: MessageSender.ai, text: ChatControlIntent.cancellationReply(text), timestamp: DateTime.now()),
      );
    }

    // 1.1 Datos locales: solo responde cuando una operación SQLite real coincide.
    final dataCommand = await const DataChatCommandRouter().tryRoute(text);
    if (dataCommand != null) return dataCommand;

    const chatMemory = ChatMemoryTools();
    if (chatMemory.isMemoryCommand(text)) {
      final previousTurns = const ChatContextBuilder().historyBeforeCurrentUser(chatHistory, text);
      final memoryReply = chatMemory.resolveCommand(input: text, history: previousTurns);
      if (memoryReply != null) {
        return ChatTurnRouteResult.completed(memoryReply);
      }
    }

    // 2. Comandos `@` directos
    if (AgentToolDispatcher.isToolCommand(text)) {
      final result = await coordinator.runCommand(text);
      return ChatTurnRouteResult.completed(
        ChatMessage(id: DateTime.now().microsecondsSinceEpoch.toString(), sender: MessageSender.ai, text: automationUserFacingReason(result), timestamp: DateTime.now(), status: MessageStatus.sent),
      );
    }

    // 3. Comandos Linux deterministas
    final linuxCmd = const LinuxVoiceCommandParser().parse(text, lastFilePath: lastLinuxFilePath);
    if (linuxCmd != null) {
      return _pipeline.executeLinux(text: text, linuxCmd: linuxCmd, coordinator: coordinator, lastLinuxFilePath: lastLinuxFilePath);
    }

    // 3.1 Mensajería determinista real (WhatsApp, Telegram, Messenger)
    final messagingRes = await const ChatMessagingTurnRouter().tryRoute(
      text: text,
      coordinator: coordinator,
    );
    if (messagingRes != null) return messagingRes;

    // 4. Cerebro Universal: Instrucciones compuestas multidominio
    final contract = const UniversalInstructionParser().parse(text: text, lastLinuxFilePath: lastLinuxFilePath);
    if (contract.executionMode != InstructionExecutionMode.conversationalOnly && contract.obligations.length >= 2) {
      return _pipeline.executeUniversal(contract: contract);
    }

    // 5. Flujos verificados en caché y catálogo cross-app
    final cached = await _pipeline.tryCachedFlows(text: text, coordinator: coordinator);
    if (cached != null) return cached;

    // Un turno conversacional no se contesta con plantillas: sigue hacia el motor real.
    // ensureReady carga el modelo elegido aunque aún esté dormido.
    if (preferConfiguredApi || activeModelPath?.trim().isNotEmpty == true) {
      return const ChatTurnRouteResult.notHandled();
    }
    // Sin modelo local/API, ChatSendUseCase intenta Browser AI y muestra su error real.
    return const ChatTurnRouteResult.notHandled();
  }
}
