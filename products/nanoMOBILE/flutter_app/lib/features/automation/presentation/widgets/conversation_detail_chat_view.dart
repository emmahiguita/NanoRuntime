part of 'conversation_detail_sheet.dart';

/// [ConversationDetailChatView] — Renderiza las burbujas de mensaje, capacidades y remitente (< 200 líneas).
extension ConversationDetailChatView on _ConversationDetailSheetState {
  Widget _buildAndroidCapabilityBadge(AutomationVisualPalette visual) {
    final cap = WhatsAppCapabilityResolver.resolve(_activeNotification);
    final isBg = cap.text == WhatsAppSendCapability.backgroundSupported;
    final color = isBg
        ? (visual.isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
        : const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
      decoration: BoxDecoration(
        color: visual.isDark
            ? const Color(0xFF1E293B).withValues(alpha: 0.45)
            : Colors.white.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: visual.isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.85),
          width: 0.9,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isBg ? Icons.bolt_rounded : Icons.info_outline_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isBg
                  ? 'En segundo plano · Nano permanece en pantalla'
                  : 'Sin notificación activa · Requiere interacción',
              style: TextStyle(
                color: color,
                fontFamily: 'Inter',
                fontFamilyFallback: ConversationDetailSheet._sfFallback,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Una preview no demuestra dirección/fecha y un borrador no está enviado.
  /// Se informa como texto neutral, nunca como burbujas de historial confirmado.
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
              'Historial aún no recuperado',
              style: TextStyle(color: visual.textMuted),
            ),
            const SizedBox(height: 12),
            Text('Última vista previa: $preview', textAlign: TextAlign.center),
            if (widget.item.hasPendingReply)
              const Text('Hay un borrador pendiente de envío.'),
          ],
        ),
      ),
    );
  }
}
