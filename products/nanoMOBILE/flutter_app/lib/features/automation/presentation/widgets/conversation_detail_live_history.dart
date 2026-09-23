part of 'conversation_detail_sheet.dart';

/// Carga el historial observable de la notificación activa sin duplicar mensajes.
extension ConversationDetailLiveHistory on _ConversationDetailSheetState {
  Future<void> _loadLiveHistoryAndCapabilities() async {
    // Dos streams pueden invalidar a la vez. Se serializa la lectura y se
    // conserva una sola recarga pendiente para no crear futuros huérfanos.
    if (_historyLoadInProgress) {
      _historyReloadRequested = true;
      return;
    }
    _historyLoadInProgress = true;
    try {
      do {
        _historyReloadRequested = false;
        await _refreshLiveHistory();
      } while (_historyReloadRequested && mounted);
    } catch (error) {
      debugPrint('[conversation-detail] historial no disponible: $error');
    } finally {
      _historyLoadInProgress = false;
    }
  }

  Future<void> _refreshLiveHistory() async {
    final executor = ref.read(notificationExecutorProvider);
    final matches = _findAllMatchingNotifications(
      await executor.list(limit: 50),
    );
    if (matches.isEmpty || !mounted) return;

    final replyable =
        matches.where((n) => n.canReply).firstOrNull ?? matches.first;
    final entries = <ConversationMemoryEntry>[];
    final seen = <String>{};
    for (final matched in matches) {
      for (final message in matched.rawMessages) {
        final text = (message['messageText'] ?? message['text'] ?? '')
            .toString()
            .trim();
        if (text.isEmpty) continue;
        final isSelf = message['isSelf'] == true;
        final sender =
            (message['sender'] ?? (isSelf ? 'Tú' : widget.item.displayName))
                .toString();
        final atMs = message['messageTimestamp'] is num
            ? (message['messageTimestamp'] as num).toInt()
            : matched.postedAt.millisecondsSinceEpoch;
        if (seen.add('${atMs}_$text')) {
          entries.add(
            ConversationMemoryEntry(
              kind: isSelf
                  ? ConversationMemoryEntryKind.outboundObservedManual
                  : ConversationMemoryEntryKind.inbound,
              text: text,
              sender: sender,
              atMs: atMs,
            ),
          );
        }
      }

      final mainText =
          (matched.messageText.isNotEmpty ? matched.messageText : matched.text)
              .trim();
      final atMs = matched.messageTimestamp > 0
          ? matched.messageTimestamp
          : matched.postedAt.millisecondsSinceEpoch;
      if (mainText.isNotEmpty && seen.add('${atMs}_$mainText')) {
        entries.add(
          ConversationMemoryEntry(
            kind: ConversationMemoryEntryKind.inbound,
            text: mainText,
            sender: matched.sender.isNotEmpty
                ? matched.sender
                : widget.item.displayName,
            atMs: atMs,
          ),
        );
      }
    }

    final itemLastMsg = widget.item.lastMessage.trim();
    final isPhone = RegExp(r'^\+?[0-9\s\-]+$').hasMatch(itemLastMsg);
    final itemKey = '${widget.item.lastAtMs}_$itemLastMsg';
    if (itemLastMsg.isNotEmpty && !isPhone && seen.add(itemKey)) {
      entries.add(
        ConversationMemoryEntry(
          kind: ConversationMemoryEntryKind.inbound,
          text: itemLastMsg,
          sender: widget.item.displayName,
          atMs: widget.item.lastAtMs,
        ),
      );
    }
    entries.sort((a, b) => a.atMs.compareTo(b.atMs));
    if (!mounted) return;
    setState(() {
      _activeNotification = replyable;
      if (entries.isNotEmpty) _liveEntries = entries;
    });
  }
}
