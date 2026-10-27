part of 'conversation_detail_sheet.dart';

/// Distribución responsiva del panel de conversación para vertical y horizontal.
///
/// - **QUÉ HACE:** Organiza cabecera, controles, historial de mensajes y barra
///   de composición adaptándose al ancho/alto real y al teclado en pantalla.
/// - **CÓMO FUNCIONA:** En modo horizontal usa un panel lateral desplazable
///   (`SingleChildScrollView`) de ancho acotado y cede el área principal al chat.
/// - **POR QUÉ:** Evita desbordamientos verticales (`RenderFlex overflow`) en
///   pantallas apaisadas y mantiene todos los controles accesibles y usables.
extension ConversationDetailResponsiveBody on _ConversationDetailSheetState {
  /// Construye el cuerpo adaptable según orientación y espacio disponible.
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

        final railWidth = (constraints.maxWidth * 0.34).clamp(240.0, 300.0);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(visual),
                      _buildControlBar(visual),
                      _buildCapabilityBadge(visual),
                      _buildStatus(visual),
                    ],
                  ),
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

  bool _hasWhatsAppWebConversation() => _preferWebHistory && _hasWebSource;

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

  /// Renderiza la lista de mensajes desde la fuente activa (Web, SQLite o memoria).
  Widget _buildMessageList(
    AutomationVisualPalette visual,
    List<ConversationMemoryEntry> entries,
  ) {
    final aliases = {
      widget.item.conversationId,
      ...widget.item.conversationAliases,
    };
    final webAlias = aliases.where((id) => id.startsWith('waweb:')).firstOrNull;
    if (webAlias != null && _preferWebHistory) {
      return WhatsAppWebHistoryView(
        key: ValueKey(webAlias),
        title: widget.item.displayName,
        alias: webAlias,
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
