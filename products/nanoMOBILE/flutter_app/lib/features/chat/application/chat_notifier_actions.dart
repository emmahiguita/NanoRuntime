part of '../../../core/providers/chat_provider.dart';

// The extension is a part of ChatNotifier's library, split only to keep the
// facade below the 300-line boundary. It intentionally updates StateNotifier
// state through the owning notifier.
// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member

extension ChatNotifierActions on ChatNotifier {
  void addAttachment(ChatAttachment attachment) => state = state.copyWith(
    attachments: _msgManager.addAttachment(
      currentAttachments: state.attachments,
      attachment: attachment,
    ),
  );

  /// Analiza una foto real antes de adjuntarla. `false` significa que la
  /// captura existe, pero el clasificador no produjo evidencia utilizable.
  Future<bool> addPhotoAttachment({
    required String name,
    required String path,
    required int sizeBytes,
  }) async {
    final observation = await _visionAdapter.describe(path);
    addAttachment(
      ChatAttachment(
        name: name,
        content:
            observation ??
            '[Imagen capturada: $name]\n'
                'El clasificador visual local no devolvió observaciones; '
                'no se inventó una descripción.',
        kind: ChatAttachmentKind.photo,
        sizeBytes: sizeBytes,
      ),
    );
    return observation != null;
  }

  void removeAttachment(String name) => state = state.copyWith(
    attachments: _msgManager.removeAttachment(
      currentAttachments: state.attachments,
      name: name,
    ),
  );

  Future<void> refreshEngine() => _modelService.refreshEngine(
    activeModelPath: state.activeModelPath,
    isMounted: () => mounted,
    onEngineUpdated: ({required online, conn}) => state = state.copyWith(
      engineOnline: online,
      connection: conn ?? state.connection,
    ),
  );

  Future<void> approvePendingTool() => _sendUseCase.approvePending(
    activeModel: state.activeModel,
    sessionId: _modelService.sessionId,
    isMounted: () => mounted,
    getMessages: () => state.messages,
    listener: this,
    onSetGenerating: () => state = state.copyWith(
      generating: true,
      pendingTool: null,
      pendingToolDescription: null,
    ),
  );

  Future<void> rejectPendingTool() => _sendUseCase.rejectPending(
    pendingTool: state.pendingTool,
    activeModel: state.activeModel,
    sessionId: _modelService.sessionId,
    isMounted: () => mounted,
    getMessages: () => state.messages,
    listener: this,
    onSetGenerating: () => state = state.copyWith(
      generating: true,
      pendingTool: null,
      pendingToolDescription: null,
    ),
  );

  Future<void> speakLastResponse() async {
    if (_lastAiMessage()?.text case final text? when text.isNotEmpty) {
      await _voiceCoordinator.speakText(text);
    }
  }

  ChatMessage? _lastAiMessage() {
    for (final message in state.messages.reversed) {
      if (message.sender == MessageSender.ai) return message;
    }
    return null;
  }

  Future<bool> startVoiceConversation() =>
      _voiceCoordinator.startVoiceConversation(
        onTranscriptReady: send,
        getLastAiText: () => _lastAiMessage()?.text,
        isMounted: () => mounted,
      );

  void stopVoiceConversation() => _voiceCoordinator.stopVoiceConversation();

  void stop() {
    _sendUseCase.streamSession.stop(engine: _engine);
    state = state.copyWith(generating: false, streamingText: '');
    unawaited(_msgManager.persistMessages(state.messages));
  }

  Future<void> clear() async {
    if (state.generating) stop();
    _sendUseCase.coordinator.reset();
    _toolCoordinator.reset();
    _modelService.rotateSession();
    state = state.copyWith(
      messages: const [],
      input: '',
      streamingText: '',
      attachments: const [],
      pendingTool: null,
      pendingToolDescription: null,
    );
    await _msgManager.clearAll();
  }

  void delete(String id) => state = state.copyWith(
    messages: _msgManager.deleteMessage(
      currentMessages: state.messages,
      id: id,
    ),
  );

  void retry(String errorMessageId) {
    if (state.generating) return;
    final result = _msgManager.retryMessage(
      currentMessages: state.messages,
      errorMessageId: errorMessageId,
    );
    if (result.userTextToRetry == null) return;
    state = state.copyWith(messages: result.messages);
    unawaited(
      send(
        result.userTextToRetry!,
      ).catchError((error) => debugPrint('[ChatNotifier] retry error: $error')),
    );
  }

  void selectModel(
    String name, {
    String? path,
    bool confirmedExtreme = false,
  }) => _modelService.selectModel(
    name: name,
    path: path,
    confirmedExtreme: confirmedExtreme,
    currentModel: state.activeModel,
    currentModelPath: state.activeModelPath,
    onSelectionStarted: ({required selectedModel, required selectedPath}) =>
        state = state.copyWith(
          activeModel: selectedModel,
          activeModelPath: selectedPath,
          connection: ModelConnectionState.loadingModel,
          showModelSelector: false,
        ),
    onCheckEngine: (model, revision) =>
        _checkEngine(model: model, expectedRevision: revision),
  );
}
