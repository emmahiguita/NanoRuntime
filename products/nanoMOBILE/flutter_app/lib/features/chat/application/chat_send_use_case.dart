// chat_send_use_case.dart — Caso de uso principal de envío y enrutamiento del chat.
// QUÉ HACE: Orquesta turnos de usuario evaluando herramientas locales, comandos o inferencia LLM.
// CÓMO FUNCIONA: Enruta turnos deterministas; si no hay modelo delega a ChatWebAiFallback; si hay modelo invoca al motor.
// POR QUÉ: Aplica Clean Architecture (SRP) desacoplando la inferencia de la UI (< 200 líneas).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/application/automation_coordinator_provider.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/browser_ai/application/browser_ai_gateway.dart';

import '../../../core/models/chat_models.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/runtime_engine.dart';
import '../domain/chat_context_builder.dart';
import 'chat_action_listener.dart';
import 'chat_inference_coordinator.dart';
import 'chat_stream_session.dart';
import 'chat_tool_approval_use_case.dart';
import 'chat_tool_coordinator.dart';
import 'chat_turn_router.dart';
import 'chat_web_ai_fallback.dart';

class ChatSendUseCase {
  final ChatTurnRouter turnRouter;
  final ChatInferenceCoordinator inferenceCoordinator;
  final ChatToolCoordinator toolCoordinator;
  final ChatStreamSession streamSession;
  final Ref ref;
  final AutomationCoordinator coordinator;
  final ChatWebAiFallback _webAiFallback = const ChatWebAiFallback();
  late final ChatToolApprovalUseCase _approvalUseCase;

  ChatSendUseCase({
    required this.turnRouter,
    required this.inferenceCoordinator,
    required this.toolCoordinator,
    required this.streamSession,
    required this.ref,
    required this.coordinator,
  }) {
    _approvalUseCase = ChatToolApprovalUseCase(
      coordinator: coordinator,
      toolCoordinator: toolCoordinator,
      streamSession: streamSession,
      sendUseCase: this,
    );
  }

  factory ChatSendUseCase.create({
    required Ref ref,
    required AgentToolDispatcher tools,
    required AutomationCoordinator? coordinator,
  }) {
    final stream = ChatStreamSession();
    final toolCoord = ChatToolCoordinator();
    final AutomationCoordinator resolved = (coordinator ?? ref.read(automationCoordinatorProvider))!;
    return ChatSendUseCase(
      turnRouter: const ChatTurnRouter(),
      inferenceCoordinator: ChatInferenceCoordinator(
        streamSession: stream, toolCoordinator: toolCoord,
        contextBuilder: const ChatContextBuilder(), tools: tools,
        coordinator: resolved, engine: ref.read(runtimeEngineProvider.notifier).client,
      ),
      toolCoordinator: toolCoord, streamSession: stream,
      ref: ref, coordinator: resolved,
    );
  }

  // QUÉ HACE: Ejecuta un turno completo de usuario analizando rutas deterministas y motor de inferencia.
  Future<void> execute({
    required String text, required List<ChatAttachment> attachments,
    required int generationId, required String? activeModelPath,
    required String activeModel, required String sessionId,
    required bool engineOnline, required String? lastLinuxFilePath,
    required bool Function() isMounted, required List<ChatMessage> Function() getMessages,
    required void Function(String? newPath) onUpdateLastLinuxFilePath,
    required ChatActionListener listener,
  }) async {
    try {
      final routeRes = await turnRouter.tryRoute(
        text: text, coordinator: coordinator,
        engineOnline: engineOnline, activeModelPath: activeModelPath,
        lastLinuxFilePath: lastLinuxFilePath,
        browserAiGateway: ref.read(browserAiGatewayProvider),
      );
      if (!streamSession.isGenerationCurrent(generationId, isMounted())) return;

      if (routeRes.isHandled) {
        if (routeRes.updatedLastLinuxFilePath != null) onUpdateLastLinuxFilePath(routeRes.updatedLastLinuxFilePath);
        if (routeRes.isPaused) {
          toolCoordinator.pauseFromRoute(routeRes, text);
          listener.onToolPaused(routeRes.pauseTool, routeRes.pauseDescription);
          return;
        }
        if (routeRes.message != null) {
          listener.onMessageAppended(routeRes.message!);
          return;
        }
      }

      if (activeModelPath?.trim().isNotEmpty != true) {
        await _webAiFallback.handleFallback(
          gateway: ref.read(browserAiGatewayProvider),
          text: text,
          listener: listener,
        );
        return;
      }

      final engine = ref.read(runtimeEngineProvider.notifier);
      final ready = await engine.ensureReady(modelPath: activeModelPath);
      if (!streamSession.isGenerationCurrent(generationId, isMounted())) return;
      if (!ready) {
        final degraded = engine.phase == EnginePhase.degraded;
        listener.onEngineError(
          errorText: degraded
              ? 'El motor está vivo pero no hay modelo GGUF instalado. Descárgalo desde el catálogo.'
              : 'El motor no pudo arrancar: ${engine.reason ?? "fallo desconocido"}.',
          degraded: degraded, engineOnline: engine.isLive,
        );
        return;
      }

      listener.onEngineReady();
      await resumeInference(
        text: text, trace: const [], attachments: attachments,
        generationId: generationId, activeModel: activeModel, sessionId: sessionId,
        isMounted: isMounted, getMessages: getMessages, listener: listener,
      );
    } catch (e, st) {
      if (!streamSession.isGenerationCurrent(generationId, isMounted())) return;
      debugPrint('[ChatSendUseCase] Error preparando turno: $e\n$st');
      listener.onTurnError('No se pudo completar la operación solicitada: $e');
    }
  }

  // QUÉ HACE: Continúa el proceso de generación recurrente hacia el motor local.
  Future<void> resumeInference({
    required String text, required List<String> trace,
    required List<ChatAttachment> attachments, required int generationId,
    required String activeModel, required String sessionId,
    required bool Function() isMounted, required List<ChatMessage> Function() getMessages,
    required ChatActionListener listener,
  }) async {
    final settings = ref.read(settingsProvider);
    final engine = ref.read(runtimeEngineProvider.notifier);
    await inferenceCoordinator.generateRound(
      text: text, toolTrace: trace, attachments: attachments,
      generationId: generationId, activeModel: activeModel, sessionId: sessionId,
      temperature: settings.temperature, topP: settings.topP,
      maxTokens: settings.maxTokens.clamp(32, 4096),
      getEnginePhase: () => engine.phase, getEngineLive: () => engine.isLive,
      isMounted: isMounted, getMessages: getMessages,
      onMessageAppended: listener.onMessageAppended,
      onStreamingText: listener.onStreamingText,
      onSuccess: listener.onInferenceSuccess,
      onEngineError: ({required errorText, required degraded, required engineOnline}) =>
          listener.onEngineError(errorText: errorText, degraded: degraded, engineOnline: engineOnline),
      onError: listener.onTurnError,
    );
  }

  Future<void> approvePending({
    required String activeModel, required String sessionId,
    required bool Function() isMounted, required List<ChatMessage> Function() getMessages,
    required ChatActionListener listener, required void Function() onSetGenerating,
  }) => _approvalUseCase.approve(
    activeModel: activeModel, sessionId: sessionId,
    isMounted: isMounted, getMessages: getMessages,
    listener: listener, onSetGenerating: onSetGenerating,
  );

  Future<void> rejectPending({
    required String? pendingTool, required String activeModel,
    required String sessionId, required bool Function() isMounted,
    required List<ChatMessage> Function() getMessages,
    required ChatActionListener listener, required void Function() onSetGenerating,
  }) => _approvalUseCase.reject(
    pendingTool: pendingTool, activeModel: activeModel,
    sessionId: sessionId, isMounted: isMounted,
    getMessages: getMessages, listener: listener,
    onSetGenerating: onSetGenerating,
  );
}
