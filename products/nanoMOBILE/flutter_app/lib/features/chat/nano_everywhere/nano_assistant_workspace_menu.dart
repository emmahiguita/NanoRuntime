part of 'nano_assistant_panel.dart';

/// El icono de WhatsApp abre sus funciones existentes y las rutas locales
/// implementadas. Elegir una opción solo prepara el editor, nunca la ejecuta.
extension _NanoAssistantWorkspaceMenu on _NanoAssistantPanelState {
  Future<void> _openWorkspaceMenu(BuildContext anchor) =>
      showWhatsAppAutomationMenu(
        anchor,
        attachment: widget.controller.attachment == null ? null : AutomationInputAttachment(
          name: widget.controller.attachment!.name, path: widget.controller.attachment!.path),
        onActivate: () {
          if (mounted) _handleToolSelected('WhatsApp');
        },
        onDraft: (text) {
          if (mounted) widget.input.text = text;
        },
        extraActions: const {
          'Leer pantalla visible': 'Ver pantalla de WhatsApp',
          'Exportar chat desde WhatsApp':
              'Exporta esta conversación de WhatsApp',
          'Importar historial TXT o ZIP': 'Importa historial de WhatsApp',
          'Analizar historial importado': 'Analiza el historial importado',
          'Preparar QA de navegación': 'Prepara QA de WhatsApp',
          'Ejecutar QA preparado': 'Ejecuta QA de WhatsApp',
          'Historial de QA': 'Historial QA',
          'Compartir informe QA': 'Exporta informe QA',
        },
      );
}
