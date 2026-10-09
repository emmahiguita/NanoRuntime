import 'package:flutter/foundation.dart';
import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/application/automation_feedback_presenter.dart';
import 'package:nanoai/features/automation/domain/automation_goal.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';

import '../../../core/models/chat_models.dart';
import '../../../core/services/personal_language_policy.dart';
import '../../automation/engine/language/runtime_personal_live_context.dart';
import '../../automation/personal_agent/domain/personal_live_context.dart';
import '../../../core/services/chat_system_prompt.dart';
import '../../../core/services/device_info.dart';
import '../../../core/services/llm_engine_client.dart';
import '../../../core/services/runtime_engine.dart';
import '../domain/chat_context_builder.dart';
import '../domain/chat_memory_index.dart';
import '../domain/chat_suggestion_engine.dart';
import '../domain/stream_sanitizer.dart';
import 'chat_stream_session.dart';
import 'chat_tool_coordinator.dart';

part 'chat_inference_context.part.dart';
part 'chat_inference_tools.part.dart';

/// QUÉ: orquesta inferencia y rondas de herramientas con confirmación.
/// CÓMO: delega contexto/ejecución, conserva cancelación y detecta bucles.
/// POR QUÉ: separa estas responsabilidades del estado visual del chat.
class ChatInferenceCoordinator {
  final ChatStreamSession streamSession;
  final ChatToolCoordinator toolCoordinator;
  final ChatContextBuilder contextBuilder;
  final AgentToolDispatcher tools;
  final AutomationCoordinator coordinator;
  final LLMEngineClient engine;
  final Future<String> Function(String query)? mcpContextFor;
  final Future<String> Function(String query)? skillContextFor;

  const ChatInferenceCoordinator({
    required this.streamSession,
    required this.toolCoordinator,
    required this.contextBuilder,
    required this.tools,
    required this.coordinator,
    required this.engine,
    this.mcpContextFor,
    this.skillContextFor,
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
    required void Function(ChatMessage message) onToolTraceAppended,
    required void Function(String? tool, String? description) onToolPaused,
    required void Function(String text) onStreamingText,
    required void Function({
      required ChatMessage aiMessage,
      required double? liveTps,
      required TurnMetrics? turnMetrics,
    })
    onSuccess,
    required void Function({
      required String errorText,
      required bool degraded,
      required bool engineOnline,
    })
    onEngineError,
    required void Function(String errorText) onError,
  }) async {
    final messages = getMessages();
    final history = contextBuilder.historyBeforeCurrentUser(messages, text);
    final prompt = contextBuilder.buildPrompt(
      text: text,
      attachments: attachments,
      isFirstRound: toolTrace.isEmpty,
    );
    final memoryContext = const ChatMemoryIndex().contextFor(history, text);
    // El envío validó evidencia textual. Los motores integrados en esta ruta
    // no reciben binarios: una foto aporta únicamente sus etiquetas de ML Kit.

    try {
      if (!streamSession.isGenerationCurrent(generationId, isMounted())) return;
      final system = await _buildTurnSystem(
        text: text,
        history: history,
        activeModel: activeModel,
        sessionId: sessionId,
        memoryContext: memoryContext,
      );
      if (!streamSession.isGenerationCurrent(generationId, isMounted())) return;
      final res = await streamSession.executeStream(
        engine: engine,
        prompt: prompt,
        temperature: temperature,
        topP: topP,
        maxTokens: maxTokens,
        sessionId: sessionId,
        systemPrompt: system,
        history: contextBuilder.buildHistory(history, toolTrace),
        generationId: generationId,
        isMounted: isMounted,
        onPhaseChange: (_) {},
        onTextUpdated: onStreamingText,
      );

      if (!streamSession.isGenerationCurrent(generationId, isMounted())) return;

      if (res.fullText.isEmpty) {
        onError(
          'El motor terminó sin emitir texto. Esto suele indicar modelo no cargado o falta de memoria.',
        );
        return;
      }

      final toolRound = await _handleToolReply(
        response: res.fullText,
        text: text,
        trace: toolTrace,
        generationId: generationId,
        isMounted: isMounted,
        onToolTraceAppended: onToolTraceAppended,
        onToolPaused: onToolPaused,
        onError: onError,
      );
      if (toolRound.handled) {
        if (toolRound.feedback == null) return;
        await generateRound(
          text: text,
          toolTrace: [...toolTrace, res.fullText, toolRound.feedback!],
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
          onToolTraceAppended: onToolTraceAppended,
          onToolPaused: onToolPaused,
          onStreamingText: onStreamingText,
          onSuccess: onSuccess,
          onEngineError: onEngineError,
          onError: onError,
        );
        return;
      }

      final message = _completedMessage(res.fullText, res.tps);
      if (message == null) {
        onError(
          'La salida del modelo no cumple el formato o el lenguaje neutral.',
        );
        return;
      }
      onSuccess(
        aiMessage: message,
        liveTps: res.tps,
        turnMetrics: res.turnMetrics,
      );
    } on LLMEngineException catch (e) {
      if (!streamSession.isGenerationCurrent(generationId, isMounted())) return;
      final degraded = getEnginePhase() == EnginePhase.degraded;
      onEngineError(
        errorText: degraded
            ? 'El motor local está vivo pero el paquete no está instalado. ($activeModel)'
            : 'El motor local no respondió: ${e.message}. ($activeModel)',
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
  static List<String> deriveSuggestions(String text) =>
      ChatSuggestionEngine.derive(text);
}
