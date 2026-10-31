// conversation_detail_dialogs.dart
//
// QUÉ HACE:
// Despliega diálogos informativos y modales de confirmación en el detalle de conversación:
// alerta de accesibilidad no disponible y verificación de número de contacto no verificado.
//
// CÓMO FUNCIONA:
// - Usa showNanoGlassWindow, NanoGlassDialog y NanoMetallicButton para una estética iOS Frosted Glass unificada.
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

    return showNanoGlassWindow<String>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
    );
  }
}
