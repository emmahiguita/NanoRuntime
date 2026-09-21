part of 'conversation_detail_sheet.dart';

/// [ConversationDetailChatView]
///
/// QUÉ HACE:
/// Renderiza las burbujas de mensaje (inbound/outbound), el badge de capacidades
/// de envío en segundo plano y el fallback de último mensaje en caso necesario.
///
/// CÓMO FUNCIONA:
/// 1. `_buildChatBubble`: Burbuja con efecto de cristal (glassmorphism) translúcido,
///    desenfoque óptico y bordes adaptados. En horizontal (landscape) restringe el ancho
///    al 60% de la pantalla para evitar estiramientos antiestéticos.
/// 2. `_buildCapabilityBadge`: Informa si la respuesta se puede entregar en 2do plano sin salir
///    de Nano (RemoteInput) o si requiere interacción.
/// 3. `_buildFallbackLastMessage`: Si la lista no cargó de SQLite pero hay un mensaje previo.
///
/// POR QUÉ:
/// Ofrece un diseño pulido, legible y profesional manteniendo los archivos estrictamente
/// por debajo de 200 líneas.
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
        _buildChatBubble(widget.item.lastMessage, true, visual),
        if (widget.item.hasPendingReply && widget.item.pendingReplyText != null)
          _buildChatBubble(widget.item.pendingReplyText!, false, visual),
      ],
    );
  }

  Widget _buildChatBubble(String text, bool isInbound, AutomationVisualPalette visual) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(isInbound ? 4 : 20),
      bottomRight: Radius.circular(isInbound ? 20 : 4),
    );

    return Align(
      alignment: isInbound ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * (isLandscape ? 0.60 : 0.80),
        ),
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: isInbound
                  ? Colors.black.withValues(alpha: visual.isDark ? 0.25 : 0.06)
                  : const Color(0xFF007AFF).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              child: Text(
                text,
                style: TextStyle(
                  color: isInbound ? visual.text : Colors.white,
                  fontFamily: 'Inter',
                  fontFamilyFallback: ConversationDetailSheet._sfFallback,
                  fontSize: 14,
                  height: 1.35,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
