part of 'conversation_detail_sheet.dart';

/// [ConversationDetailAttachments] — Selección y envío de archivos adjuntos (< 200 líneas).
extension ConversationDetailAttachments on _ConversationDetailSheetState {
  void _showAttachmentMenu() {
    final visual = AutomationVisual.of(context);
    final accentGreen = visual.isDark
        ? const Color(0xFF00FF88)
        : const Color(0xFF059669);

    showModalBottomSheet(
      context: context,
      backgroundColor: visual.isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _attachmentOption(
                  ctx,
                  visual: visual,
                  icon: Icons.image_rounded,
                  color: accentGreen,
                  title: 'Enviar Imagen / Foto',
                  subtitle: 'Galería o fotos del dispositivo',
                  onTap: _attachImage,
                ),
                _attachmentOption(
                  ctx,
                  visual: visual,
                  icon: Icons.videocam_rounded,
                  color: const Color(0xFF60A5FA),
                  title: 'Enviar Video',
                  subtitle: 'Videos y clips multimedia',
                  onTap: _attachVideo,
                ),
                _attachmentOption(
                  ctx,
                  visual: visual,
                  icon: Icons.picture_as_pdf_rounded,
                  color: const Color(0xFFEF4444),
                  title: 'Enviar Documento PDF',
                  subtitle: 'Archivos PDF del dispositivo',
                  onTap: _attachPdf,
                ),
                _attachmentOption(
                  ctx,
                  visual: visual,
                  icon: Icons.assignment_rounded,
                  color: visual.isDark
                      ? Colors.white24
                      : const Color(0xFF94A3B8),
                  title: 'Plantillas de formulario',
                  subtitle: 'Texto editable antes de abrir WhatsApp',
                  onTap: _showFormPicker,
                ),
                _attachmentOption(
                  ctx,
                  visual: visual,
                  icon: Icons.attach_file_rounded,
                  color: visual.isDark
                      ? Colors.white24
                      : const Color(0xFF94A3B8),
                  title: 'Cualquier archivo',
                  subtitle: 'Archivos y documentos',
                  onTap: _attachAndShareFile,
                ),
                _attachmentOption(
                  ctx,
                  visual: visual,
                  icon: Icons.folder_copy_rounded,
                  color: visual.isDark
                      ? const Color(0xFF60A5FA)
                      : const Color(0xFF2563EB),
                  title: 'Biblioteca de Nano',
                  subtitle: 'Busca archivos guardados por carpetas',
                  onTap: _showNanoLibrary,
                ),
                _attachmentOption(
                  ctx,
                  visual: visual,
                  icon: Icons.create_new_folder_rounded,
                  color: visual.isDark
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFFD97706),
                  title: 'Organizar archivo en Nano',
                  subtitle: 'Importa y elige su carpeta',
                  onTap: _organizeFileInNano,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _attachmentOption(
    BuildContext ctx, {
    required AutomationVisualPalette visual,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(color: visual.text, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: visual.textMuted, fontSize: 12),
      ),
      onTap: () {
        Navigator.of(ctx).pop();
        onTap();
      },
    );
  }

  Future<void> _attachImage() =>
      _pickAndShareMedia(type: FileType.image, label: 'imagen');
  Future<void> _attachVideo() =>
      _pickAndShareMedia(type: FileType.video, label: 'video');
  Future<void> _attachPdf() => _pickAndShareMedia(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    label: 'PDF',
  );
  Future<void> _attachAndShareFile() =>
      _pickAndShareMedia(type: FileType.any, label: 'archivo');

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
      final caption = _inputController.text.trim();
      final contact = _verifiedAttachmentContact();
      if (contact == null || contact.length < 7) {
        _safeSetState(
          () => _statusText =
              'No hay un número verificable para ${widget.item.displayName}.',
        );
        return;
      }

      final returnsToNano = await share.isAccessibilityEnabled();
      final ok = await share.shareFile(
        path: stablePath,
        contact: contact,
        caption: caption,
        packageName: widget.item.packageName,
        autoSend: true,
      );
      _safeSetState(() {
        _statusText = ok
            ? returnsToNano
                  ? 'Archivo preparado en WhatsApp. Nano regresará al finalizar; verifica el envío.'
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
