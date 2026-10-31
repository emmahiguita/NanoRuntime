part of 'nano_assistant_panel.dart';

/// Seleccionar cambia el contexto; solo Enviar despacha la acción real.
/// La lectura de pantalla es una herramienta local, no una respuesta inventada.
extension _NanoAssistantPanelActions on _NanoAssistantPanelState {
  /// Prepara una única petición explícita; conserva controles de confirmar y
  /// cancelar separados de adjuntos y del texto del mensaje.
  Future<void> _send() async {
    if (_busy) {
      debugPrint('[owl-action] rejected: busy');
      return;
    }
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
        debugPrint('[owl-action] rejected: invalid WhatsApp command');
        // El panel externo no tiene Scaffold propio: publica el motivo en
        // su estado compartido y conserva la orden para que pueda completarse.
        widget.controller.reportStatus(error.message);
        return;
      }
    }
    if (AutomationAccessController.requiresAccessibility(text)) {
      _preparationCancelled = false;
      _setPreparing(true);
      final ready = await _access.refresh();
      if (!mounted) return;
      _setPreparing(false);
      if (_preparationCancelled) return;
      if (!ready) {
        debugPrint('[owl-action] rejected: accessibility unavailable');
        final owner = widget.controller;
        try {
          if (await NanoInputFallback.copyCurrentChatDraft(text)) {
            Map<Object?, Object?> state = const {};
            try {
              state = await NanoInputFallback.status();
            } on Object {
              // Sin diagnóstico nativo no se inventa el estado del teclado.
            }
            final keyboard = state['imeSelected'] == true
                ? 'Nano Input está seleccionado.'
                : state['imeEnabled'] == true
                ? 'Selecciona Nano Input desde el selector de teclados.'
                : 'Puedes habilitar Nano Input en ajustes de teclado.';
            final accessibility = state['accessibilityEnabled'] == true &&
                    state['accessibilityConnected'] == false
                ? 'Accesibilidad habilitada pero sin conexión.'
                : state['accessibilityEnabled'] == false
                ? 'Accesibilidad de Nano desactivada.'
                : 'Accesibilidad no disponible.';
            owner.reportStatus(
              '$accessibility Texto copiado al portapapeles del sistema. '
              'En WhatsApp pégalo en el chat correcto y pulsa Enviar; '
              '$keyboard Nano Input ofrece «Pegar borrador».',
            );
            return;
          }
        } on Object {
          owner.reportStatus('No se pudo copiar el borrador.');
          return;
        }
        widget.controller.reportStatus(
          'La accesibilidad de Nano no está conectada; no se inició la acción.',
        );
        return;
      }
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
      debugPrint('[owl-action] collapsing panel before dispatch');
      // La ventana externa debe retirarse antes de observar el chat objetivo.
      final collapse = widget.onCollapseForAction;
      if (collapse != null) {
        await collapse();
      } else {
        widget.onCollapse();
      }
    }
    debugPrint('[owl-action] dispatching ${action ? 'action' : 'query'}');
    final receipt = await controller.submit(text);
    debugPrint('[owl-action] finished: ${receipt.outcome.name}');
    if (receipt.accepted && mounted && _activeTool != 'Pantalla') {
      // No borra un borrador nuevo ni pierde el texto si la petición fue rechazada.
      if (receipt.ok && widget.input.text.trim() == text) widget.input.clear();
    }
  }

  /// Lleva a los ajustes públicos sin activar ni sustituir el teclado actual.
  Future<void> _openNanoKeyboardSettings() async {
    final owner = widget.controller;
    try {
      await NanoInputFallback.openKeyboardSettings();
    } on Object {
      owner.reportStatus('No se pudieron abrir los ajustes de teclado.');
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
