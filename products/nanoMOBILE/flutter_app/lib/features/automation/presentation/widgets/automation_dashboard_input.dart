part of 'automation_dashboard.dart';

/// Separa el + general del componente activo. El mismo propietario coordina
/// menús, selectores y borradores para evitar ventanas o operaciones duplicadas.
extension _AutomationDashboardInput on _AutomationDashboardState {
  /// Fallback para invocaciones sin un botón medible; no abre funciones WhatsApp.
  void _showInputOptions() => _openInputMenu(context);

  /// Serializa ambos menús y la captura nativa; libera el bloqueo incluso al fallar.
  Future<void> _withInputMenu(Future<void> Function() open) async {
    if (_running || _inputMenu != null) return;
    final pending = open();
    _inputMenu = pending;
    try {
      await pending;
    } finally {
      _inputMenu = null;
    }
  }

  /// El + contiene adjuntos y el catálogo de complementos, nunca sus comandos.
  Future<void> _openInputMenu(BuildContext anchor) =>
      _withInputMenu(() => _chooseInput(anchor));

  /// La selección de WhatsApp solo activa su contexto en el editor. Cámara,
  /// Fotos y Archivos usan proveedores reales y conservan el adjunto sin enviarlo.
  Future<void> _chooseInput(BuildContext anchor) async {
    final choice = await showAutomationInputMenu(
      anchor,
      whatsAppSelected: _inputContext.selected,
    );
    if (!mounted || choice == null) return;
    if (choice == AutomationInputChoice.whatsapp) {
      _inputContext.toggleWhatsApp();
      _updateInputDraft(_commandController.text);
      _focusEditor();
      return;
    }
    try {
      final file = await AutomationAttachmentPicker.pick(choice);
      if (!mounted || file == null) return;
      final replacesDraft =
          _attachment?.ownsDraft(_commandController.text) ?? false;
      setState(() => _attachment = file);
      if (_commandController.text.trim().isEmpty || replacesDraft) {
        _writeDraft('Envía el adjunto a ');
      } else {
        _focusEditor();
      }
    } on Object catch (error) {
      if (!mounted) return;
      final message = error is FormatException
          ? error.message
          : 'No se pudo preparar el adjunto.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  /// El logo abre las funciones del componente; adjuntar sigue perteneciendo al +.
  Future<void> _openWhatsAppMenu(BuildContext anchor) => _withInputMenu(
    () => showWhatsAppAutomationMenu(
      anchor,
      attachment: _attachment,
      onActivate: () {
        if (mounted && !_inputContext.selected) _inputContext.toggleWhatsApp();
      },
      onDraft: _writeDraft,
    ),
  );

  /// Reutiliza el controlador del editor, sin montar una segunda barra de escritura.
  void _writeDraft(String draft) {
    if (!mounted) return;
    _commandController.text = draft;
    _commandController.selection = TextSelection.collapsed(
      offset: draft.length,
    );
    _updateInputDraft(draft);
    _focusEditor();
  }

  /// Abre el editor del shell antes de solicitar foco al campo existente.
  void _focusEditor() {
    NanoFloatingNavigationFrame.openInput(context);
    _commandFocus.requestFocus();
  }

  /// Revoca también el borrador generado que contiene su ruta; conserva textos
  /// independientes y el componente seleccionado, evitando un envío residual.
  void _removeAttachment() {
    if (_running) return;
    final revoke = _attachment?.ownsDraft(_commandController.text) ?? false;
    setState(() => _attachment = null);
    if (revoke) _commandController.clear();
    _updateInputDraft(_commandController.text);
  }

  /// La vista previa usa el mismo adjunto y destinatario que el despacho real.
  /// Una orden incompleta no muestra identidades deducidas de palabras sueltas.
  void _updateInputDraft(String text) {
    try {
      _inputContext.updateDraft(prepareAutomationDraft(text, _attachment).goal);
    } on FormatException {
      _inputContext.updateDraft('');
    }
  }

  /// La ayuda describe el contexto vigente sin imponer un destinatario de ejemplo.
  String get _inputHint => _attachment != null
      ? 'Envía el adjunto a (contacto)…'
      : _inputContext.selected
      ? 'Escribe una acción de WhatsApp…'
      : 'Describe qué quieres automatizar…';
}
