part of 'conversation_detail_sheet.dart';

/// [ConversationDetailAttachments]
///
/// QUÉ HACE:
/// Administra la selección y envío de archivos adjuntos (imágenes, videos, documentos PDF
/// y archivos arbitrarios) hacia WhatsApp para el contacto activo.
///
/// CÓMO FUNCIONA:
/// 1. Abre el selector nativo del sistema (`FilePicker`).
/// 2. Copia el archivo al catálogo local persistente de la aplicación.
/// 3. Comparte el archivo mediante `WhatsAppMediaShare.shareFile`.
/// 4. Registra la entrada en `ConversationMemoryStore` para visualización inmediata en el chat.
///
/// POR QUÉ:
/// Desacopla el manejo de archivos pesados y galerías multimedia del árbol principal de la vista,
/// manteniendo la separación de responsabilidades y modularidad (< 200 líneas).
extension ConversationDetailAttachments on _ConversationDetailSheetState {
  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF00FF88),
                  child: Icon(Icons.image_rounded, color: Colors.black),
                ),
                title: const Text('Enviar Imagen / Foto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Galería o fotos del dispositivo', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _attachImage();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF60A5FA),
                  child: Icon(Icons.videocam_rounded, color: Colors.white),
                ),
                title: const Text('Enviar Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Videos y clips multimedia', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _attachVideo();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEF4444),
                  child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                ),
                title: const Text('Enviar Documento PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Archivos PDF del dispositivo', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _attachPdf();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  child: const Icon(Icons.assignment_rounded, color: Colors.white),
                ),
                title: const Text('Formulario Interactivo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Plantilla de registro o encuesta rápida', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showFormPicker();
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  child: const Icon(Icons.attach_file_rounded, color: Colors.white),
                ),
                title: const Text('Cualquier archivo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Archivos y documentos', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _attachAndShareFile();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _attachImage() => _pickAndShareMedia(type: FileType.image, label: 'imagen');

  Future<void> _attachVideo() => _pickAndShareMedia(type: FileType.video, label: 'video');

  Future<void> _attachPdf() => _pickAndShareMedia(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        label: 'PDF',
      );

  Future<void> _attachAndShareFile() => _pickAndShareMedia(type: FileType.any, label: 'archivo');

  Future<void> _pickAndShareMedia({
    required FileType type,
    List<String>? allowedExtensions,
    required String label,
  }) async {
    try {
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

      const share = WhatsAppMediaShare();
      final stablePath = await share.copyToCatalog(file.path!) ?? file.path!;
      final caption = _inputController.text.trim();
      final contact = widget.item.conversationId.isNotEmpty
          ? widget.item.conversationId
          : widget.item.displayName;

      final ok = await share.shareFile(
        path: stablePath,
        contact: contact,
        caption: caption,
        packageName: widget.item.packageName,
      );

      if (ok) {
        _recordSharedMedia(stablePath, caption);
      }

      _safeSetState(() {
        _statusText = ok
            ? 'Abriendo WhatsApp para enviar $label'
            : 'No se pudo abrir WhatsApp para compartir';
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

      memoryStore.appendOutbound(
        canonicalConversationId(widget.item.conversationId),
        textToSend,
        kind: ConversationMemoryEntryKind.outboundDispatched,
        atMs: nowMs,
      );

      ref.invalidate(conversationHubListProvider);
      ref.read(conversationHubVersionProvider.notifier).state++;
      _inputController.clear();
    } catch (_) {}
  }
}
