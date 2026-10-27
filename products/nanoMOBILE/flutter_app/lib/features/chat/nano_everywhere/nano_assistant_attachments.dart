part of 'nano_assistant_panel.dart';

/// Adaptador de presentación al selector y gramática de adjuntos existentes.
/// No duplica cámara, almacenamiento ni motor de envío.
extension _NanoAssistantAttachments on _NanoAssistantPanelState {
  /// Una selección preparada sobrevive al contraer el panel en su controlador.
  Future<void> _pickAttachment(BuildContext anchor) async {
    if (_busy) return;
    setState(() => _pickingAttachment = true);
    var ownsPreparation = false;
    try {
      final choice = await showAutomationInputMenu(
        anchor,
        whatsAppSelected: _activeTool == 'WhatsApp',
      );
      if (!mounted || choice == null) return;
      if (choice == AutomationInputChoice.whatsapp) {
        _handleToolSelected(_activeTool == 'WhatsApp' ? 'Chat' : 'WhatsApp');
        return;
      }
      ownsPreparation = widget.controller.beginFilePreparation();
      if (!ownsPreparation) return;
      final file = await AutomationAttachmentPicker.pick(choice);
      if (!mounted || file == null) return;
      _removeAttachment(clearPrompt: false);
      widget.controller.setAttachment(
        NanoPreparedAttachment(name: file.name, path: file.path),
      );
      widget.controller.reportStatus(
        'Adjunto preparado. Selecciona WhatsApp y escribe el destinatario.',
      );
    } on Object catch (error) {
      if (mounted) {
        widget.controller.reportStatus(
          error is FormatException
              ? error.message
              : 'No se pudo preparar el archivo.',
        );
      }
    } finally {
      if (ownsPreparation) widget.controller.endFilePreparation();
      if (mounted) setState(() => _pickingAttachment = false);
    }
  }

  /// Revoca únicamente el borrador que contenía la ruta retirada. Eliminar la
  /// selección no borra el archivo real de la biblioteca ni otro texto escrito.
  void _removeAttachment({bool clearPrompt = true}) {
    final file = widget.controller.attachment;
    if (file != null) {
      final draft = AutomationInputAttachment(name: file.name, path: file.path);
      if (draft.ownsDraft(widget.input.text)) widget.input.clear();
    }
    widget.controller.setAttachment(null);
    if (clearPrompt) {
      widget.controller.reportStatus('Adjunto retirado del borrador.');
    }
  }

  /// El archivo se asocia solo a una orden explícita de compartir con identidad.
  /// Nunca ignora un adjunto para enviar únicamente el texto por accidente.
  String _prepareAttachment(String input) {
    if (widget.controller.attachment != null &&
        _activeTool != 'WhatsApp' &&
        _activeTool != 'Auto') {
      throw const FormatException(
        'Selecciona WhatsApp para compartir el adjunto.',
      );
    }
    return prepareNanoAttachment(input, widget.controller.attachment);
  }

  /// Muestra nombre y retirada; la ruta privada no forma parte del texto visual.
  Widget _attachmentView() {
    final file = widget.controller.attachment;
    if (file == null) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(Icons.attach_file_rounded, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(file.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
        IconButton(
          tooltip: 'Quitar adjunto',
          onPressed: _busy ? null : _removeAttachment,
          icon: const Icon(Icons.close_rounded, size: 18),
        ),
      ],
    );
  }
}
