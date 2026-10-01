part of 'conversation_detail_sheet.dart';

/// [ConversationDetailAttachments] — Selección y envío de archivos adjuntos (< 200 líneas).
extension ConversationDetailAttachments on _ConversationDetailSheetState {
  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _attachmentOption(ctx, icon: Icons.image_rounded, color: const Color(0xFF00FF88), title: 'Enviar Imagen / Foto', subtitle: 'Galería o fotos del dispositivo', onTap: _attachImage),
              _attachmentOption(ctx, icon: Icons.videocam_rounded, color: const Color(0xFF60A5FA), title: 'Enviar Video', subtitle: 'Videos y clips multimedia', onTap: _attachVideo),
              _attachmentOption(ctx, icon: Icons.picture_as_pdf_rounded, color: const Color(0xFFEF4444), title: 'Enviar Documento PDF', subtitle: 'Archivos PDF del dispositivo', onTap: _attachPdf),
              _attachmentOption(ctx, icon: Icons.assignment_rounded, color: Colors.white24, title: 'Formulario Interactivo', subtitle: 'Plantilla de registro o encuesta rápida', onTap: _showFormPicker),
              _attachmentOption(ctx, icon: Icons.attach_file_rounded, color: Colors.white24, title: 'Cualquier archivo', subtitle: 'Archivos y documentos', onTap: _attachAndShareFile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentOption(BuildContext ctx, {required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white, size: 20)),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      onTap: () {
        Navigator.of(ctx).pop();
        onTap();
      },
    );
  }

  Future<void> _attachImage() => _pickAndShareMedia(type: FileType.image, label: 'imagen');
  Future<void> _attachVideo() => _pickAndShareMedia(type: FileType.video, label: 'video');
  Future<void> _attachPdf() => _pickAndShareMedia(type: FileType.custom, allowedExtensions: ['pdf'], label: 'PDF');
  Future<void> _attachAndShareFile() => _pickAndShareMedia(type: FileType.any, label: 'archivo');

  Future<void> _pickAndShareMedia({required FileType type, List<String>? allowedExtensions, required String label}) async {
    try {
      final picked = await FilePicker.pickFiles(type: type, allowedExtensions: allowedExtensions);
      final file = picked?.files.single;
      if (file == null || file.path == null) return;

      _safeSetState(() {
        _busy = true;
        _statusText = 'Preparando $label para compartir...';
      });

      const share = WhatsAppMediaShare();
      final stablePath = await share.copyToCatalog(file.path!) ?? file.path!;
      final caption = _inputController.text.trim();
      final contact = widget.item.conversationId.isNotEmpty ? widget.item.conversationId : widget.item.displayName;

      final ok = await share.shareFile(path: stablePath, contact: contact, caption: caption, packageName: widget.item.packageName);
      if (ok) _recordSharedMedia(stablePath, caption);

      _safeSetState(() {
        _statusText = ok ? 'Abriendo WhatsApp para enviar $label' : 'No se pudo abrir WhatsApp para compartir';
      });
    } catch (e) {
      _safeSetState(() => _statusText = 'Error al adjuntar $label: $e');
    } finally {
      _safeSetState(() => _busy = false);
    }
  }

  void _recordSharedMedia(String path, String caption) {
    try {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final memoryStore = ref.read(conversationMemoryStoreProvider);
      final textToSend = caption.isNotEmpty ? '$caption\n$path' : path;

      memoryStore.appendOutbound(canonicalConversationId(widget.item.conversationId), textToSend, kind: ConversationMemoryEntryKind.outboundDispatched, atMs: nowMs);
      ref.invalidate(conversationHubListProvider);
      ref.read(conversationHubVersionProvider.notifier).state++;
      _inputController.clear();
    } catch (_) {}
  }
}
