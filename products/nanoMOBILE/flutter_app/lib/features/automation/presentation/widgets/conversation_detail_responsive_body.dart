part of 'conversation_detail_sheet.dart';

/// Distribuye el chat según el espacio real, no sólo según la orientación.
/// En horizontal usa un rail compacto y reserva el ancho principal al hilo.
extension ConversationDetailResponsiveBody on _ConversationDetailSheetState {
  Widget _buildResponsiveBody(
    AutomationVisualPalette visual,
    List<ConversationMemoryEntry> entries,
  ) {
    final webConversation = _hasWhatsAppWebConversation();
    return LayoutBuilder(
      builder: (context, constraints) {
        final landscape = constraints.maxWidth > constraints.maxHeight;
        final keyboardCompact =
            landscape && MediaQuery.viewInsetsOf(context).bottom > 0;

        // Con teclado horizontal sólo quedan el historial y el compositor.
        if (keyboardCompact) {
          return Column(
            children: [
              Expanded(child: _buildMessageList(visual, entries)),
              if (!webConversation) _buildBottomActionBar(visual),
            ],
          );
        }
        if (!landscape || constraints.maxWidth < 620) {
          return Column(
            children: [
              _buildHeader(visual),
              _buildControlBar(visual),
              _buildCapabilityBadge(visual),
              _buildStatus(visual),
              Expanded(child: _buildMessageList(visual, entries)),
              if (!webConversation) _buildBottomActionBar(visual),
            ],
          );
        }

        final railWidth = (constraints.maxWidth * 0.34).clamp(250.0, 310.0);
        return Row(
          children: [
            SizedBox(
              width: railWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(
                    alpha: visual.isDark ? 0.12 : 0.03,
                  ),
                  border: Border(
                    right: BorderSide(
                      color: visual.textMuted.withValues(alpha: 0.16),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    _buildHeader(visual),
                    _buildControlBar(visual),
                    _buildCapabilityBadge(visual),
                    _buildStatus(visual),
                    const Spacer(),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: _buildMessageList(visual, entries)),
                  if (!webConversation) _buildBottomActionBar(visual),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  bool _hasWhatsAppWebConversation() => {
    widget.item.conversationId,
    ...widget.item.conversationAliases,
  }.any((id) => id.startsWith('waweb:'));

  Widget _buildStatus(AutomationVisualPalette visual) {
    final status = _statusText;
    if (status == null || status.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Text(
        status,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: visual.accent, fontSize: 11),
      ),
    );
  }

  Widget _buildMessageList(
    AutomationVisualPalette visual,
    List<ConversationMemoryEntry> entries,
  ) {
    final aliases = {
      widget.item.conversationId,
      ...widget.item.conversationAliases,
    };
    final webAlias = aliases.where((id) => id.startsWith('waweb:')).firstOrNull;
    if (webAlias != null) {
      // Solo el hilo que el usuario abre en Nano; no abre la pantalla Web.
      return WhatsAppWebHistoryView(
        key: ValueKey(webAlias),
        title: widget.item.displayName,
        alias: webAlias,
        fallback: entries,
        bubble: (entry) => _buildChatBubble(
          entry.text,
          entry.kind == ConversationMemoryEntryKind.inbound,
          visual,
          sender: entry.sender,
          timestampMs: entry.atMs,
        ),
      );
    }
    final historyId = _historyIdForConversation();
    if (historyId != null) {
      // La página pertenece al hash guardado; no cambia cuentas ni abre WhatsApp.
      return NotificationHistoryView(
        key: ValueKey(historyId),
        historyId: historyId,
        fallback: entries,
        bubble: (entry) => _buildChatBubble(
          entry.text,
          entry.kind == ConversationMemoryEntryKind.inbound,
          visual,
          sender: entry.sender,
          timestampMs: entry.atMs,
        ),
      );
    }
    if (entries.isEmpty) return _buildFallbackLastMessage(visual);
    return ListView.builder(
      controller: _scrollController,
      // El origen queda en el final del hilo: al abrir el chat, la posición 0
      // corresponde al mensaje más reciente y no al inicio histórico.
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[entries.length - 1 - index];
        final isSelf =
            entry.kind == ConversationMemoryEntryKind.outboundVerified ||
            entry.kind == ConversationMemoryEntryKind.outboundDispatched ||
            entry.kind == ConversationMemoryEntryKind.outboundObservedManual ||
            entry.kind == ConversationMemoryEntryKind.effectUnknown;
        return _buildChatBubble(
          entry.text,
          !isSelf,
          visual,
          sender: entry.sender,
          timestampMs: entry.atMs,
        );
      },
    );
  }
}
