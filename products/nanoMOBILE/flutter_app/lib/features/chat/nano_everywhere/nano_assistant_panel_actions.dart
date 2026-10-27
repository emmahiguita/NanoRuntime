part of 'nano_assistant_panel.dart';

/// Seleccionar cambia el contexto; solo Enviar despacha la acción real.
/// La lectura de pantalla es una herramienta local, no una respuesta inventada.
extension _NanoAssistantPanelActions on _NanoAssistantPanelState {
  /// Prepara una única petición explícita; conserva controles de confirmar y
  /// cancelar separados de adjuntos y del texto del mensaje.
  Future<void> _send() async {
    if (_busy) return;
    var text = widget.input.text.trim();
    if (NanoActionInput.isCancel(text)) {
      widget.controller.cancel();
      return;
    }
    if (_activeTool == 'Pantalla') text = '@leer_pantalla';
    if (text.isEmpty) return;
    try {
      if (_activeTool != 'Pantalla' && !NanoActionInput.isConfirm(text)) {
        text = _prepareAttachment(text);
      }
    } on FormatException catch (error) {
      widget.controller.reportStatus(error.message);
      return;
    }
    if (_activeTool == 'WhatsApp') {
      try {
        text = NanoActionInput.prepare(text, whatsApp: true);
      } on FormatException catch (error) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(SnackBar(content: Text(error.message)));
        return;
      }
    }
    if (AutomationAccessController.requiresAccessibility(text)) {
      _preparationCancelled = false;
      _setPreparing(true);
      final ready = await _access.refresh();
      if (!mounted) return;
      _setPreparing(false);
      if (!ready || _preparationCancelled) return;
    }
    final action = const ['Auto', 'WhatsApp', 'Pantalla'].contains(_activeTool);
    widget.controller.selectMode(
      action
          ? NanoMode.action
          : _activeTool == 'Media'
          ? NanoMode.media
          : NanoMode.quick,
    );
    final controller = widget.controller;
    // Leer pantalla no consume ni elimina el borrador de otro modo.

    if (action) {
      widget.onCollapse();
    } // Deja visible el control de la app objetivo.
    final receipt = await controller.submit(text);
    if (receipt.accepted && mounted && _activeTool != 'Pantalla') {
      // No borra un borrador nuevo ni pierde el texto si la petición fue rechazada.
      if (receipt.ok && widget.input.text.trim() == text) widget.input.clear();
    }
  }

  void _handleToolSelected(String tool) {
    _selectTool(tool);
    widget.controller.panelTool = tool;
    widget.controller.selectMode(
      const ['Auto', 'WhatsApp', 'Pantalla'].contains(tool)
          ? NanoMode.action
          : tool == 'Media'
          ? NanoMode.media
          : NanoMode.quick,
    );
  }

  String _getHint() => switch (_activeTool) {
    'Auto' => 'Indica qué acción realizar…',
    'WhatsApp' => 'Abre el chat de Emm…',
    'Pantalla' => 'Pulsa enviar para leer la pantalla…',
    'Media' => 'Pega un enlace multimedia…',
    _ => 'Pregunta a Búho…',
  };
}
