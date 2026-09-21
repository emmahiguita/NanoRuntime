import 'package:flutter/foundation.dart';
import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/application/automation_feedback_presenter.dart';
import 'package:nanoai/features/automation/domain/automation_goal.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';

import '../../../core/models/chat_models.dart';
import '../../../core/services/chat_system_prompt.dart';
import '../../../core/services/device_info.dart';
import '../../../core/services/llm_engine_client.dart';
import '../../../core/services/runtime_engine.dart';
import '../domain/chat_context_builder.dart';
import '../domain/chat_suggestion_engine.dart';
import '../domain/stream_sanitizer.dart';
import 'chat_stream_session.dart';
import 'chat_tool_coordinator.dart';

/// Orquesta la generación recursiva del LLM, tool-calling multi-paso y control de fallos.
///
/// **QUÉ HACE:** Controla una ronda de inferencia generativa y recursión de herramientas.
/// **CÓMO FUNCIONA:** Ensambla contexto, consume stream SSE, ejecuta tools y detecta bucles.
/// **POR QUÉ:** Separa la complejidad del bucle del StateNotifier (SRP y Clean Architecture).
class ChatInferenceCoordinator {
  final ChatStreamSession streamSession;
  final ChatToolCoordinator toolCoordinator;
  final ChatContextBuilder contextBuilder;
  final AgentToolDispatcher tools;
  final AutomationCoordinator coordinator;
  final LLMEngineClient engine;

  const ChatInferenceCoordinator({
    required this.streamSession,
    required this.toolCoordinator,
    required this.contextBuilder,
    required this.tools,
    required this.coordinator,
    required this.engine,
  });

  Future<void> generateRound({
    required String text,
    required List<String> toolTrace,
    required List<ChatAttachment> attachments,
    required int generationId,
    required String activeModel,
    required String sessionId,
    required double temperature,
    required double topP,
    required int maxTokens,
    required EnginePhase Function() getEnginePhase,
    required bool Function() getEngineLive,
    required bool Function() isMounted,
    required List<ChatMessage> Function() getMessages,
    required void Function(ChatMessage message) onMessageAppended,
    required void Function(String text) onStreamingText,
    required void Function({required ChatMessage aiMessage, required double? liveTps, required TurnMetrics? turnMetrics}) onSuccess,
    required void Function({required String errorText, required bool degraded, required bool engineOnline}) onEngineError,
    required void Function(String errorText) onError,
  }) async {
    final messages = getMessages();
    final history = contextBuilder.historyBeforeCurrentUser(messages, text);
    final prompt = contextBuilder.buildPrompt(text: text, attachments: attachments, isFirstRound: toolTrace.isEmpty);

    try {
      if (!streamSession.isGenerationCurrent(generationId, isMounted())) return;
      final res = await streamSession.executeStream(
        engine: engine,
        prompt: prompt,
        temperature: temperature,
        topP: topP,
        maxTokens: maxTokens,
        sessionId: sessionId,
        systemPrompt: ChatSystemPrompt.build(
          registry: tools.registry,
          modelName: activeModel,
          now: DateTime.now(),
          device: DeviceInfo.read(),
        ),
        history: contextBuilder.buildHistory(history, toolTrace),
        generationId: generationId,
        isMounted: isMounted,
        onPhaseChange: (_) {},
        onTextUpdated: onStreamingText,
      );

      if (!streamSession.isGenerationCurrent(generationId, isMounted())) return;

      if (res.fullText.isEmpty) {
        onError('El motor terminó sin emitir texto. Esto suele indicar modelo no cargado o falta de memoria.');
        return;
      }

      final toolCalls = AgentToolProtocol.extractToolCalls(res.fullText);
      if (toolCalls.isNotEmpty && (toolTrace.length ~/ 2) < ChatToolCoordinator.maxToolRounds) {
        onMessageAppended(ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: res.fullText,
          timestamp: DateTime.now(),
          status: MessageStatus.sent,
        ));

        final worldBefore = await tools.worldFingerprint();
        final execRes = await coordinator.execute(AutomationGoal(text: text), plan: toolCalls);
        if (!streamSession.isGenerationCurrent(generationId, isMounted())) return;

        if (execRes.isPaused && execRes.confirmation != null) {
          toolCoordinator.pausePlan(
            plan: toolCalls,
            pauseIndex: execRes.pauseIndex,
            confirmation: execRes.confirmation,
            userText: text,
            trace: toolTrace,
            callText: res.fullText,
          );
          return;
        }

        final feedback = automationUserFacingReason(execRes.reason);
        final worldAfter = await tools.worldFingerprint();
        if (toolCoordinator.isStalledToolRound(calls: toolCalls, before: worldBefore, after: worldAfter, feedback: feedback)) {
          onError('[loopDetected] La misma herramienta devolvió el mismo resultado sin cambios.');
          return;
        }

        final lease = streamSession.activeStream;
        if (lease != null) streamSession.releaseStream(lease, 'entre rondas');
        await generateRound(
          text: text,
          toolTrace: [...toolTrace, res.fullText, feedback],
          attachments: const [],
          generationId: generationId,
          activeModel: activeModel,
          sessionId: sessionId,
          temperature: temperature,
          topP: topP,
          maxTokens: maxTokens,
          getEnginePhase: getEnginePhase,
          getEngineLive: getEngineLive,
          isMounted: isMounted,
          getMessages: getMessages,
          onMessageAppended: onMessageAppended,
          onStreamingText: onStreamingText,
          onSuccess: onSuccess,
          onEngineError: onEngineError,
          onError: onError,
        );
        return;
      }

      final cleanMsg = StreamSanitizer.sanitize(res.fullText);
      onSuccess(
        aiMessage: ChatMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          sender: MessageSender.ai,
          text: cleanMsg,
          timestamp: DateTime.now(),
          tps: res.tps,
          suggestions: ChatSuggestionEngine.derive(cleanMsg),
          status: MessageStatus.sent,
        ),
        liveTps: res.tps,
        turnMetrics: res.turnMetrics,
      );
    } on LLMEngineException catch (e) {
      if (!streamSession.isGenerationCurrent(generationId, isMounted())) return;
      final degraded = getEnginePhase() == EnginePhase.degraded;
      onEngineError(
        errorText: degraded
            ? 'El motor está vivo pero no hay modelo GGUF instalado. ($activeModel)'
            : 'El motor llama.cpp no respondió: ${e.message}. ($activeModel)',
        degraded: degraded,
        engineOnline: getEngineLive(),
      );
    } catch (e, st) {
      if (!streamSession.isGenerationCurrent(generationId, isMounted())) return;
      debugPrint('[ChatInferenceCoordinator] Error en generación: $e\n$st');
      onError('No se pudo iniciar o completar la generación: $e');
    } finally {
      final lease = streamSession.activeStream;
      if (lease != null && streamSession.activeGenerationId == generationId) {
        streamSession.releaseStream(lease, 'finally');
      }
    }
  }

  /// Re-exporta la derivación de sugerencias para retrocompatibilidad directa.
  static List<String> deriveSuggestions(String text) => ChatSuggestionEngine.derive(text);
}
