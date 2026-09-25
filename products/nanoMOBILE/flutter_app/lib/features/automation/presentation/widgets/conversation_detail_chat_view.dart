part of 'conversation_detail_sheet.dart';

/// [ConversationDetailChatView] — Renderiza las burbujas de mensaje, capacidades y remitente (< 200 líneas).
extension ConversationDetailChatView on _ConversationDetailSheetState {
  Widget _buildCapabilityBadge(AutomationVisualPalette visual) {
    final cap = WhatsAppCapabilityResolver.resolve(_activeNotification);
    final isBg = cap.text == WhatsAppSendCapability.backgroundSupported;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isBg ? const Color(0xFF25D366).withValues(alpha: 0.10) : Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isBg ? const Color(0xFF25D366).withValues(alpha: 0.30) : Colors.amber.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isBg ? Icons.bolt_rounded : Icons.info_outline_rounded, size: 13, color: isBg ? const Color(0xFF25D366) : Colors.amber),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              isBg
                  ? 'Texto / Link ✓ En segundo plano · Nano permanece en pantalla'
                  : 'Sin notificación activa · El envío requiere interacción',
              style: TextStyle(
                color: isBg ? const Color(0xFF25D366) : Colors.amber,
                fontFamily: 'Inter',
                fontFamilyFallback: ConversationDetailSheet._sfFallback,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackLastMessage(AutomationVisualPalette visual) {
    final lastMsg = widget.item.lastMessage.trim();
    final isPhoneNumber = RegExp(r'^\+?[0-9\s\-]+$').hasMatch(lastMsg);
    if (lastMsg.isEmpty || isPhoneNumber) {
      return _buildNewChatEmptyState(visual);
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: visual.isDark ? 0.08 : 0.45),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: visual.isDark ? 0.15 : 0.60), width: 0.8),
            ),
            child: Text(
              'Historial reciente de mensajes',
              style: TextStyle(
                color: visual.textMuted,
                fontFamily: 'Inter',
                fontFamilyFallback: ConversationDetailSheet._sfFallback,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildChatBubble(widget.item.lastMessage, true, visual, sender: widget.item.lastSender, timestampMs: widget.item.lastAtMs),
        if (widget.item.hasPendingReply && widget.item.pendingReplyText != null)
          _buildChatBubble(widget.item.pendingReplyText!, false, visual, timestampMs: widget.item.lastAtMs),
      ],
    );
  }

  Color _getSenderColor(String sender) {
    const colors = [
      Color(0xFF38BDF8),
      Color(0xFF34D399),
      Color(0xFFA78BFA),
      Color(0xFFFBBF24),
      Color(0xFFF472B6),
      Color(0xFF2DD4BF),
    ];
    return colors[sender.hashCode.abs() % colors.length];
  }

  Widget _buildChatBubble(String text, bool isInbound, AutomationVisualPalette visual, {String? sender, int? timestampMs}) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final semantic = ConversationSemanticClassifier.classify(text);
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(15),
      topRight: const Radius.circular(15),
      bottomLeft: Radius.circular(isInbound ? 4 : 15),
      bottomRight: Radius.circular(isInbound ? 15 : 4),
    );

    return Align(
      alignment: isInbound ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * (isLandscape ? 0.58 : 0.78),
        ),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: isInbound
                  ? Colors.black.withValues(alpha: visual.isDark ? 0.25 : 0.06)
                  : const Color(0xFF007AFF).withValues(alpha: 0.35),
              blurRadius: 7,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                gradient: isInbound
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: visual.isDark
                            ? [Colors.white.withValues(alpha: 0.12), Colors.white.withValues(alpha: 0.05)]
                            : [Colors.white.withValues(alpha: 0.85), Colors.white.withValues(alpha: 0.65)],
                      )
                    : const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xDD007AFF), Color(0xB30056C6)],
                      ),
                border: Border.all(
                  color: isInbound
                      ? (visual.isDark ? Colors.white.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.70))
                      : Colors.white.withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: isInbound ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.item.isGroup && isInbound && sender != null && sender.isNotEmpty && sender != widget.item.displayName) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_rounded, size: 12, color: _getSenderColor(sender)),
                        const SizedBox(width: 4),
                        Text(
                          sender,
                          style: TextStyle(
                            color: _getSenderColor(sender),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (semantic != ConversationSemanticTag.conversation) ...[
                    ConversationSemanticBadge(tag: semantic, compact: true),
                    const SizedBox(height: 5),
                  ],
                  ConversationMediaBubble(
                    text: text,
                    isInbound: isInbound,
                    visual: visual,
                    timestampMs: timestampMs,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
