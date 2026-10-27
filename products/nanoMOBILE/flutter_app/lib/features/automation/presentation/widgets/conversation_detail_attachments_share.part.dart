part of 'conversation_detail_sheet.dart';

extension ConversationDetailAttachmentsShare on _ConversationDetailSheetState {
  Future<void> _pickAndShareMedia({
    required FileType type,
    List<String>? allowedExtensions,
    required String label,
  }) async {
    try {
      const share = WhatsAppMediaShare();
      final picked = await FilePicker.pickFiles(
        type: type,
        allowedExtensions: allowedExtensions,
      );
      final file = picked?.files.single;
      if (file == null || file.path == null) return;

      _safeSetState(() {
        _busy = true;
        _statusText = 'Preparando $label para compartir...';
      });

      final stablePath = await share.copyToCatalog(
        file.path!,
        category: NanoMediaCategory.forFileName(file.name),
      );
      if (stablePath == null) {
        _safeSetState(
          () => _statusText = 'No se pudo preparar el archivo para WhatsApp.',
        );
        return;
      }
      final recipient = _verifiedAttachmentRecipient();
      if (recipient == null) {
        _safeSetState(
          () => _statusText =
              'No hay una identidad verificable para ${widget.item.displayName}.',
        );
        return;
      }

      final returnsToNano = await share.isAccessibilityEnabled();
      final ok = await share.shareFile(
        path: stablePath,
        contact: recipient.contact,
        caption: _inputController.text.trim(),
        packageName: widget.item.packageName,
        autoSend: true,
        recipientName: recipient.name,
        recipientKind: recipient.kind,
        recipientVerified: recipient.verified,
      );
      _safeSetState(() {
        _statusText = ok
            ? returnsToNano
                  ? 'Automatización iniciada. Nano regresará tras pulsar Enviar.'
                  : 'Archivo abierto en WhatsApp. Confirma Enviar allí para completar.'
            : 'No se pudo iniciar el envío de $label';
      });
    } catch (e) {
      _safeSetState(() => _statusText = 'Error al adjuntar $label: $e');
    } finally {
      _safeSetState(() => _busy = false);
    }
  }
}
