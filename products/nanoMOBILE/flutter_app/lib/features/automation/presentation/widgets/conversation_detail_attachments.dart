part of 'conversation_detail_sheet.dart';

/// [ConversationDetailAttachments]
///
/// QUÉ HACE:
/// Administra la selección y envío de archivos adjuntos (imágenes, documentos PDF
/// y archivos arbitrarios) hacia WhatsApp para el contacto activo.
///
/// CÓMO FUNCIONA:
/// 1. Abre el selector nativo del sistema (`FilePicker`).
/// 2. Copia el archivo de forma segura al catálogo local persistente de la aplicación.
/// 3. Comparte el archivo hacia WhatsApp mediante `WhatsAppMediaShare.shareFile`
///    incluyendo el pie de foto o comentario redactado por el usuario.
///
/// POR QUÉ:
/// Desacopla el manejo de archivos pesados y galerías multimedia del árbol principal de la vista,
/// manteniendo la separación de responsabilidades y la modularidad del código.
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
                title: const Text('Enviar Imagen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Galería o fotos guardadas', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _attachImage();
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF007AFF),
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
                subtitle: const Text('Archivos del dispositivo', style: TextStyle(color: Colors.white54, fontSize: 12)),
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

  Future<void> _attachImage() async {
    try {
      final picked = await FilePicker.pickFiles(type: FileType.image);
      final file = picked?.files.single;
      if (file == null || file.path == null) return;

      _safeSetState(() {
        _busy = true;
        _statusText = 'Preparando imagen para compartir...';
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

      _safeSetState(() {
        _statusText = ok
            ? 'Abriendo WhatsApp para enviar imagen'
            : 'No se pudo abrir WhatsApp para compartir';
      });
    } catch (e) {
      _safeSetState(() => _statusText = 'Error al adjuntar imagen: $e');
    } finally {
      _safeSetState(() => _busy = false);
    }
  }

  Future<void> _attachPdf() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      final file = picked?.files.single;
      if (file == null || file.path == null) return;

      _safeSetState(() {
        _busy = true;
        _statusText = 'Preparando PDF para compartir...';
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

      _safeSetState(() {
        _statusText = ok
            ? 'Abriendo WhatsApp para enviar PDF'
            : 'No se pudo abrir WhatsApp para compartir';
      });
    } catch (e) {
      _safeSetState(() => _statusText = 'Error al adjuntar PDF: $e');
    } finally {
      _safeSetState(() => _busy = false);
    }
  }

  Future<void> _attachAndShareFile() async {
    try {
      final picked = await FilePicker.pickFiles(type: FileType.any);
      final file = picked?.files.single;
      if (file == null || file.path == null) return;

      _safeSetState(() {
        _busy = true;
        _statusText = 'Preparando archivo para compartir...';
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

      _safeSetState(() {
        _statusText = ok
            ? 'Abriendo WhatsApp para adjuntar archivo'
            : 'No se pudo abrir WhatsApp para compartir';
      });
    } catch (e) {
      _safeSetState(() => _statusText = 'Error al adjuntar: $e');
    } finally {
      _safeSetState(() => _busy = false);
    }
  }
}
