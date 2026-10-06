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
    if (!mounted) return;

    // Una conversación archivada puede no tener notificación activa; por eso
    // el historial persistente se carga aunque Android no exponga ninguna.
    final replyable =
        matches.where((n) => n.canReply).firstOrNull ?? matches.firstOrNull;
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
        if (seen.add('${atMs}_${isSelf ? 'out' : 'in'}_$text')) {
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
      // No repetir como entrante el evento que ya llegó clasificado en messages.
      final hasRawCopy = matched.rawMessages.any((message) {
        final rawText = (message['messageText'] ?? message['text'] ?? '')
            .toString()
            .trim();
        return rawText.isNotEmpty &&
            rawText.toLowerCase() == mainText.toLowerCase();
      });
      if (mainText.isNotEmpty &&
          !hasRawCopy &&
          seen.add('${atMs}_in_$mainText')) {
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

    // Los alias estables enlazan el resumen del centro con mensajes guardados
    // por Android, incluso después de descartar la notificación original.
    final historyId = _historyIdForConversation();
    if (historyId != null) {
      final storedRows = await ref
          .read(notificationHistoryClientProvider)
          .messages(historyId);
      for (final row in storedRows) {
        final text = '${row['body'] ?? ''}'.trim();
        if (text.isEmpty) continue;
        final isSelf = row['isSelf'] == true;
        final atMs = (row['atMs'] as num?)?.toInt() ?? 0;
        if (!seen.add('${atMs}_${isSelf ? 'out' : 'in'}_$text')) continue;
        entries.add(
          ConversationMemoryEntry(
            kind: isSelf
                ? ConversationMemoryEntryKind.outboundObservedManual
                : ConversationMemoryEntryKind.inbound,
            text: text,
            sender: '${row['sender'] ?? ''}'.trim().isNotEmpty
                ? '${row['sender']}'.trim()
                : (isSelf ? 'Tú' : widget.item.displayName),
            atMs: atMs,
            eventId: '${row['eventId'] ?? ''}',
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
          // El emisor del resumen evita pintar como ajeno un mensaje de "Tú".
          kind: widget.item.lastSender?.trim().toLowerCase() == 'tú'
              ? ConversationMemoryEntryKind.outboundObservedManual
              : ConversationMemoryEntryKind.inbound,
          text: itemLastMsg,
          sender: widget.item.lastSender?.trim().isNotEmpty == true
              ? widget.item.lastSender!.trim()
              : widget.item.displayName,
          atMs: widget.item.lastAtMs,
        ),
      );
    }
    entries.sort((a, b) => a.atMs.compareTo(b.atMs));
    if (!mounted) return;
    setState(() {
      _activeNotification = replyable;
      _liveEntries = entries;
    });
  }

  // Acepta ambas formas porque el deduplicador puede conservar cualquiera.
  String? _historyIdForConversation() {
    final identities = {
      widget.item.conversationId,
      ...widget.item.conversationAliases,
    };
    for (final identity in identities) {
      for (final prefix in const ['notification-history:', 'history:']) {
        if (identity.startsWith(prefix)) {
          final id = identity.substring(prefix.length);
          if (RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) return id;
        }
      }
    }
    return null;
  }
}
