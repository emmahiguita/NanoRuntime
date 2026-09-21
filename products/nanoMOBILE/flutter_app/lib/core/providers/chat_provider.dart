import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/features/automation/application/automation_coordinator.dart';
import 'package:nanoai/features/automation/engine/agent_dependencies.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/engine/voice/voice_runtime.dart';

import '../../features/chat/application/chat_action_listener.dart';
import '../../features/chat/application/chat_message_manager.dart';
import '../../features/chat/application/chat_model_service.dart';
import '../../features/chat/application/chat_notifier_listener.dart';
import '../../features/chat/application/chat_send_use_case.dart';
import '../../features/chat/application/chat_tool_coordinator.dart';
import '../../features/chat/application/chat_voice_coordinator.dart';
import '../../features/chat/domain/chat_vision_adapter.dart';
import '../models/catalog_models.dart';
import '../models/chat_models.dart';
import '../services/chat_history_store.dart';
import '../services/llm_engine_client.dart';
import '../services/runtime_engine.dart';

part '../../features/chat/application/chat_notifier_actions.dart';

/// Fachada del chat: expone estado y compone casos de uso separados.
///
/// La lógica secundaria vive en servicios y extensiones para mantener SRP/DIP;
/// aquí solo se conectan mensajes, modelo, herramientas, visión y voz.
class ChatNotifier extends StateNotifier<ChatState>
    with ChatNotifierListenerMixin
    implements ChatActionListener {
  final ChatMessageManager _msgManager;
  final ChatModelService _modelService;
  final ChatToolCoordinator _toolCoordinator;
  final ChatVoiceCoordinator _voiceCoordinator;
  final ChatVisionAdapter _visionAdapter;
  final ChatSendUseCase _sendUseCase;
  final LLMEngineClient Function() _getEngine;
  String? _lastLinuxFilePath;

  LLMEngineClient get _engine => _getEngine();

  @override
  ChatMessageManager get msgManager => _msgManager;

  @visibleForTesting
  String get sessionId => _modelService.sessionId;
  VoiceSessionManager get voiceSession => _voiceCoordinator.voiceSession;
  bool get isVoiceConversationActive =>
      _voiceCoordinator.isVoiceConversationActive;

  ChatNotifier._(
    Ref ref, {
    AgentToolDispatcher? toolDispatcher,
    AutomationCoordinator? coordinator,
    ChatHistoryStore? historyStore,
    ChatVisionAdapter? visionAdapter,
    ChatState? initialState,
    bool autoInit = true,
  }) : _msgManager = ChatMessageManager(historyStore),
       _modelService = ChatModelService(ref),
       _toolCoordinator = ChatToolCoordinator(),
       _voiceCoordinator = ChatVoiceCoordinator(ref),
       _visionAdapter = visionAdapter ?? MlKitChatVisionAdapter(),
       _getEngine = (() => ref.read(runtimeEngineProvider.notifier).client),
       _sendUseCase = ChatSendUseCase.create(
         ref: ref,
         tools: toolDispatcher ?? AgentToolDispatcher(),
         coordinator: coordinator,
       ),
       super(
         initialState ??
             ChatState(
               availableModels: [for (final m in NeuralCatalog.models) m.name],
             ),
       ) {
    if (autoInit) _initAsync();
  }

  ChatNotifier(
    Ref ref, {
    AgentToolDispatcher? toolDispatcher,
    AutomationCoordinator? coordinator,
    ChatHistoryStore? historyStore,
  }) : this._(
         ref,
         toolDispatcher: toolDispatcher,
         coordinator: coordinator,
         historyStore: historyStore,
       );

  @visibleForTesting
  ChatNotifier.fixed(
    Ref ref,
    ChatState initial, {
    AgentToolDispatcher? toolDispatcher,
    AutomationCoordinator? coordinator,
    ChatHistoryStore? historyStore,
    ChatVisionAdapter? visionAdapter,
  }) : this._(
         ref,
         toolDispatcher: toolDispatcher,
         coordinator: coordinator,
         historyStore: historyStore,
         visionAdapter: visionAdapter,
         initialState: initial,
         autoInit: false,
       );

  Future<void> _initAsync() async {
    await _modelService.restoreModel(
      isMounted: () => mounted,
      onModelRestored: ({required model, required path, required connection}) =>
          state = state.copyWith(
            activeModel: model,
            activeModelPath: path,
            connection: connection,
          ),
      onCheckEngine: (m, r) => _checkEngine(model: m, expectedRevision: r),
    );
    final restored = await _msgManager.restoreMessages(
      isMounted: () => mounted,
    );
    if (restored != null && mounted) state = state.copyWith(messages: restored);
  }

  Future<void> _checkEngine({String? model, int? expectedRevision}) async {
    await _modelService.checkEngine(
      activeModel: model ?? state.activeModel,
      expectedRevision: expectedRevision,
      isMounted: () => mounted,
      onStateUpdated:
          ({required model, required connection, required online}) =>
              state = state.copyWith(
                activeModel: model,
                connection: connection,
                engineOnline: online,
              ),
    );
  }

  Future<void> send(String text) async {
    final t = text.trim();
    if (t.isEmpty || state.generating) return;
    _msgManager.historyTouched = true;
    _sendUseCase.coordinator.reset();
    _toolCoordinator.reset();
    if (state.pendingTool != null) {
      state = state.copyWith(pendingTool: null, pendingToolDescription: null);
    }

    final userMsg = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sender: MessageSender.user,
      text: t,
      timestamp: DateTime.now(),
      attachmentNames: [for (final a in state.attachments) a.name],
    );
    final attachments = state.attachments;
    state = state.copyWith(
      messages: [...state.messages, userMsg],
      input: '',
      generating: true,
      streamingText: '',
      attachments: const [],
    );
    unawaited(_msgManager.persistMessages(state.messages));

    await _sendUseCase.execute(
      text: t,
      attachments: attachments,
      generationId: _sendUseCase.streamSession.beginGeneration(),
      activeModelPath: state.activeModelPath,
      activeModel: state.activeModel,
      sessionId: _modelService.sessionId,
      engineOnline: state.engineOnline,
      lastLinuxFilePath: _lastLinuxFilePath,
      isMounted: () => mounted,
      getMessages: () => state.messages,
      onUpdateLastLinuxFilePath: (path) => _lastLinuxFilePath = path,
      listener: this,
    );
  }

  @override
  void dispose() {
    _sendUseCase.streamSession.dispose();
    _modelService.dispose();
    unawaited(_voiceCoordinator.dispose());
    super.dispose();
  }
}

final StateNotifierProvider<ChatNotifier, ChatState> chatProvider =
    StateNotifierProvider<ChatNotifier, ChatState>(
      (ref) =>
          ChatNotifier(ref, toolDispatcher: ref.watch(agentDispatcherProvider)),
    );
