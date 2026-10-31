part of 'conversation_detail_sheet.dart';

/// [ConversationDetailChatView] — Renderiza las capacidades y remitente sin banner tosco (< 150 líneas).
extension ConversationDetailChatView on _ConversationDetailSheetState {
  Widget _buildAndroidCapabilityBadge(AutomationVisualPalette visual) {
    final cap = WhatsAppCapabilityResolver.resolve(_activeNotification);
    final isBg = cap.text == WhatsAppSendCapability.backgroundSupported;
    final color = isBg
        ? (visual.isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
        : (visual.isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: visual.isDark ? 0.08 : 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: visual.isDark ? 0.22 : 0.26),
              width: 0.6,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                isBg
                    ? 'Segundo plano activo · Nano responde sin salir'
                    : 'Sin notificación activa · Interacción local requerida',
                style: TextStyle(
                  color: color,
                  fontFamily: 'Inter',
                  fontFamilyFallback: ConversationDetailSheet._sfFallback,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Una preview no demuestra dirección/fecha y un borrador no está enviado.
  Widget _buildFallbackLastMessage(AutomationVisualPalette visual) {
    final preview = widget.item.lastMessage.trim();
    if (preview.isEmpty) return _buildNewChatEmptyState(visual);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Historial pendiente de sincronización',
              style: TextStyle(
                color: visual.textMuted,
                fontFamily: 'Inter',
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              preview,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: visual.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (widget.item.hasPendingReply) ...[
              const SizedBox(height: 6),
              const Text(
                'Hay un borrador pendiente de envío',
                style: TextStyle(
                  color: Color(0xFF0EA5E9),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
