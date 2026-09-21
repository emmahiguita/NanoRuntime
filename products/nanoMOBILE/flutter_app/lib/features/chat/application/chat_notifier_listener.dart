import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/chat_models.dart';
import 'chat_action_listener.dart';
import 'chat_message_manager.dart';

/// Mixin que implementa el contrato `ChatActionListener` para actualizar el
/// `ChatState` en el `StateNotifier` ante eventos de inferencia y herramientas.
///
/// **QUÉ HACE:**
/// Recibe los callbacks desacoplados del runtime y actualiza reactivamente
/// el estado del chat en Riverpod (texto en streaming, errores, mensajes nuevos).
///
/// **CÓMO FUNCIONA:**
/// Implementa `ChatActionListener` modificando `state` e invocando `persistMessages`
/// asíncronamente en el gestor de mensajes (`ChatMessageManager`).
///
/// **POR QUÉ:**
/// Desacopla la lógica de suscripción y mutación de estado de la fachada principal,
/// manteniendo `ChatNotifier` limpio, cohesivo y estrictamente por debajo de 200 líneas.
mixin ChatNotifierListenerMixin on StateNotifier<ChatState>
    implements ChatActionListener {
  ChatMessageManager get msgManager;

  @override
  void onStreamingText(String text) =>
      state = state.copyWith(streamingText: text);

  @override
  void onMessageAppended(ChatMessage message) {
    state = state.copyWith(
      messages: [...state.messages, message],
      generating: false,
      streamingText: '',
    );
    unawaited(msgManager.persistMessages(state.messages));
  }

  @override
  void onToolTraceAppended(ChatMessage message) {
    state = state.copyWith(
      messages: [...state.messages, message],
      streamingText: '',
    );
    unawaited(msgManager.persistMessages(state.messages));
  }

  @override
  void onInferenceSuccess({
    required ChatMessage aiMessage,
    required double? liveTps,
    required TurnMetrics? turnMetrics,
  }) {
    state = state.copyWith(
      messages: [...state.messages, aiMessage],
      generating: false,
      streamingText: '',
      connection: ModelConnectionState.ready,
      engineOnline: true,
      liveTps: liveTps ?? state.liveTps,
      lastTurnMetrics: turnMetrics,
    );
    unawaited(msgManager.persistMessages(state.messages));
  }

  void emitError(
    String text, {
    bool degraded = false,
    bool? online,
    ModelConnectionState? conn,
  }) {
    final msg = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sender: MessageSender.ai,
      text: text,
      timestamp: DateTime.now(),
      status: MessageStatus.error,
    );
    state = state.copyWith(
      messages: [...state.messages, msg],
      generating: false,
      streamingText: '',
      connection:
          conn ??
          (degraded
              ? ModelConnectionState.noModel
              : ModelConnectionState.error),
      engineOnline: online ?? state.engineOnline,
    );
    unawaited(msgManager.persistMessages(state.messages));
  }

  @override
  void onEngineError({
    required String errorText,
    required bool degraded,
    required bool engineOnline,
  }) => emitError(errorText, degraded: degraded, online: engineOnline);

  @override
  void onTurnError(String text) =>
      emitError(text, conn: ModelConnectionState.error);

  @override
  void onEngineReady() => state = state.copyWith(
    connection: ModelConnectionState.ready,
    engineOnline: true,
  );

  @override
  void onToolPaused(String? tool, String? description) =>
      state = state.copyWith(
        generating: false,
        pendingTool: tool,
        pendingToolDescription: description,
      );
}
