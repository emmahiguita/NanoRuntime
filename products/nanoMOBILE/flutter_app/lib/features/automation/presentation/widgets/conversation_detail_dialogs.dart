// conversation_detail_dialogs.dart
//
// QUÉ HACE:
// Despliega diálogos informativos y modales de confirmación en el detalle de conversación:
// alerta de accesibilidad no disponible y verificación de número de contacto no verificado.
//
// CÓMO FUNCIONA:
// - Usa NanoGlassDialog y NanoMetallicButton para una estética iOS Frosted Glass unificada.
// - Adapta la disposición a pantalla completa y rotación horizontal (landscape).
// - Provee retroalimentación háptica táctil y previene cierres inesperados.
//
// POR QUÉ:
// Asegura la consistencia visual del lenguaje iOS Liquid Glass con archivos bajo 200 líneas.

part of 'conversation_detail_sheet.dart';

extension ConversationDetailDialogs on _ConversationDetailSheetState {
  Future<String?> _showNoA11yOptionsModal(
    BuildContext context,
    WhatsAppMediaShare share,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<String>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF0F172A).withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.85),
              width: 1,
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                const Icon(Icons.bolt_rounded, color: Color(0xFF00FF88), size: 32),
                const SizedBox(height: 8),
                Text(
                  'Enviar sin salir de Nano',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Activa la accesibilidad de Nano para envío y retorno automático. O continúa preparando el borrador en WhatsApp.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 18),
                NanoMetallicButton(
                  label: 'Activar Retorno Automático',
                  icon: Icons.flash_on_rounded,
                  isExpanded: true,
                  style: NanoMetallicButtonStyle.primary,
                  onPressed: () async {
                    Navigator.of(ctx).pop('open_settings');
                    await share.openAccessibilitySettings();
                  },
                ),
                const SizedBox(height: 8),
                NanoMetallicButton(
                  label: 'Preparar mensaje en WhatsApp',
                  icon: Icons.send_rounded,
                  isExpanded: true,
                  style: NanoMetallicButtonStyle.subtle,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return NanoGlassDialog.show<void>(
      context: context,
      title: 'Destino no verificable',
      subtitle: 'Validación de seguridad para $contactName',
      icon: Icons.shield_outlined,
      iconColor: const Color(0xFFF59E0B),
      content: Text(
        'No hay una notificación activa en barra ni un número registrado para $contactName.\n\n'
        'Por seguridad, Nano no enviará a ciegas para evitar despachar a otro chat.',
        style: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF475569),
          fontSize: 13,
          height: 1.4,
        ),
      ),
      actions: [
        NanoMetallicButton(
          label: 'Entendido',
          icon: Icons.check_rounded,
          style: NanoMetallicButtonStyle.primary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
