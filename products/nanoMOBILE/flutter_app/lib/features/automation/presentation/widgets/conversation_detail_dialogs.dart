part of 'conversation_detail_sheet.dart';

/// [ConversationDetailDialogs] — Diálogos de soporte y formularios (< 200 líneas).
extension ConversationDetailDialogs on _ConversationDetailSheetState {
  Future<String?> _showNoA11yOptionsModal(
    BuildContext context,
    WhatsAppMediaShare share,
  ) async {
    final visual = AutomationVisual.of(context);
    final accentGreen = visual.isDark
        ? const Color(0xFF00FF88)
        : const Color(0xFF059669);

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            decoration: BoxDecoration(
              color: visual.isDark
                  ? const Color(0xEB0F172A)
                  : Colors.white.withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              border: Border.all(
                color: visual.isDark
                    ? Colors.white.withValues(alpha: 0.18)
                    : const Color(0x33CBD5E1),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: visual.isDark ? Colors.white38 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Icon(Icons.bolt_rounded, color: accentGreen, size: 36),
                const SizedBox(height: 10),
                Text(
                  'Enviar sin salir de Nano',
                  style: TextStyle(
                    color: visual.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Activa el servicio de Accesibilidad de Nano para intentar el envío automático. Si continúas manualmente, Nano abrirá WhatsApp con el borrador y tendrás que revisar el contacto y pulsar Enviar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: visual.textMuted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  icon: const Icon(Icons.flash_on_rounded, size: 18),
                  label: const Text('Activar Retorno Automático'),
                  style: FilledButton.styleFrom(
                    backgroundColor: accentGreen,
                    foregroundColor: visual.isDark
                        ? Colors.black
                        : Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(ctx).pop('open_settings');
                    await share.openAccessibilitySettings();
                  },
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Preparar mensaje en WhatsApp'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: visual.text,
                    side: BorderSide(
                      color: visual.isDark
                          ? Colors.white.withValues(alpha: 0.25)
                          : const Color(0x33CBD5E1),
                    ),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  // Devuelve el control al emisor; este abre WhatsApp y conserva el borrador.
                  onPressed: () => Navigator.of(ctx).pop('open_whatsapp'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMissingPhoneDialog(
    BuildContext context,
    String contactName,
  ) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFFFF9500), size: 24),
            SizedBox(width: 8),
            Text(
              'Destino no verificable',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'No hay una notificación activa en barra ni un número registrado para $contactName.\n\n'
          'Por seguridad, Nano no enviará a ciegas para evitar enviar a otro chat.',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              'Entendido',
              style: TextStyle(color: Color(0xFF007AFF)),
            ),
          ),
        ],
      ),
    );
  }
}
