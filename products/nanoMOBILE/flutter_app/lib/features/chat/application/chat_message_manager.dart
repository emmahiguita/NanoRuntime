import 'dart:async';

import '../../../core/models/chat_models.dart';
import '../../../core/services/chat_history_store.dart';

/// Gestor de operaciones sobre la lista de mensajes y adjuntos en memoria y disco.
class ChatMessageManager {
  static const int maxAttachments = 3;
  static const int maxAttachmentSizeBytes = 500000;

  final ChatHistoryStore historyStore;
  bool historyTouched = false;

  ChatMessageManager([ChatHistoryStore? store])
      : historyStore = store ?? ChatHistoryStore();

  Future<void> persistMessages(List<ChatMessage> messages) =>
      historyStore.save(messages);

  Future<List<ChatMessage>?> restoreMessages({
    required bool Function() isMounted,
  }) async {
    try {
      final messages = await historyStore.restore();
      if (!isMounted() || historyTouched) return null;
      return messages;
    } catch (_) {
      return null;
    }
  }

  List<ChatAttachment> addAttachment({
    required List<ChatAttachment> currentAttachments,
    required ChatAttachment attachment,
  }) {
    if ((attachment.content.length * 2) > maxAttachmentSizeBytes) {
      return currentAttachments;
    }
    final updated = [...currentAttachments]
      ..removeWhere((a) => a.name == attachment.name);
    if (updated.length >= maxAttachments) {
      updated.removeAt(0);
    }
    updated.add(attachment);
    return updated;
  }

  List<ChatAttachment> removeAttachment({
    required List<ChatAttachment> currentAttachments,
    required String name,
  }) {
    return currentAttachments.where((a) => a.name != name).toList();
  }

  List<ChatMessage> deleteMessage({
    required List<ChatMessage> currentMessages,
    required String id,
  }) {
    historyTouched = true;
    final updated = currentMessages.where((m) => m.id != id).toList();
    unawaited(persistMessages(updated));
    return updated;
  }

  ({List<ChatMessage> messages, String? userTextToRetry}) retryMessage({
    required List<ChatMessage> currentMessages,
    required String errorMessageId,
  }) {
    final errIdx = currentMessages.indexWhere((m) => m.id == errorMessageId);
    if (errIdx < 1) {
      return (messages: currentMessages, userTextToRetry: null);
    }

    ChatMessage? userMsg;
    for (var i = errIdx - 1; i >= 0; i--) {
      if (currentMessages[i].sender == MessageSender.user) {
        userMsg = currentMessages[i];
        break;
      }
    }
    if (userMsg == null) {
      return (messages: currentMessages, userTextToRetry: null);
    }

    historyTouched = true;
    final newMsgs = currentMessages
        .where((m) => m.id != errorMessageId && m.id != userMsg!.id)
        .toList();
    unawaited(persistMessages(newMsgs));
    return (messages: newMsgs, userTextToRetry: userMsg.text);
  }

  Future<void> clearAll() async {
    historyTouched = true;
    await historyStore.clear();
  }
}
