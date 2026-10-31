part of 'conversation_detail_sheet.dart';

/// [ConversationDetailAttachmentsShare]
/// QUÉ HACE: Despacha y persiste archivos adjuntos (fotos, videos, PDFs y notas de voz) en WhatsApp.
/// CÓMO FUNCIONA: Usa FilePicker, normaliza catálogo persistente y registra la salida en ConversationMemoryStore.
/// POR QUÉ: Asegura que el usuario vea reflejado en el chat lo que envía (< 110 líneas).
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
      final caption = _inputController.text.trim();
      final ok = await share.shareFile(
        path: stablePath,
        contact: recipient.contact,
        caption: caption,
        packageName: widget.item.packageName,
        autoSend: true,
        recipientName: recipient.name,
        recipientKind: recipient.kind,
        recipientVerified: recipient.verified,
      );
      if (ok) {
        _recordSharedMedia(stablePath, caption);
      }
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

  /// Registra el archivo enviado en el historial observable del chat.
  void _recordSharedMedia(String path, String caption) {
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final memoryStore = ref.read(conversationMemoryStoreProvider);
      final textToSend = caption.isNotEmpty ? '$caption\n$path' : path;

      memoryStore.appendOutbound(
        canonicalConversationId(widget.item.conversationId),
        textToSend,
        kind: ConversationMemoryEntryKind.outboundDispatched,
        atMs: nowMs,
      );

      ref.read(conversationHubVersionProvider.notifier).state++;
      _inputController.clear();
    } catch (_) {}
  }

  /// Selecciona y comparte una nota de voz de audio (.opus, .m4a, .mp3, etc.).
  Future<void> _attachVoiceNote() => _pickAndShareMedia(
    type: FileType.custom,
    allowedExtensions: const ['opus', 'm4a', 'mp3', 'ogg', 'wav', 'aac'],
    label: 'nota de voz',
  );
}
