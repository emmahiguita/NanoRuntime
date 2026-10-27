// conversation_detail_attachments.dart
//
// QUÉ HACE:
// Menú miniatura de adjuntos con diseño iOS Context Menu: compacto, profesional,
// sin colores estridentes y con opciones completas y legibles en una sola tarjeta glass.
//
// CÓMO FUNCIONA:
// - Despliega un menú popover con BackdropFilter (28px de desenfoque), borde metálico ultrafino y divisores iOS.
// - Cada opción es una fila compacta de 42px con tipografía nítida y respuesta táctil inmediata.
// - Conecta con FilePicker y WhatsAppMediaShare para despachar fotos, videos, PDFs y catálogos.
//
// POR QUÉ:
// Optimiza el espacio visual eliminando tarjetas redundantes y logrando la estética minimalista de iOS (< 200 líneas).

part of 'conversation_detail_sheet.dart';

extension ConversationDetailAttachments on _ConversationDetailSheetState {
  void _showAttachmentMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                width: 270,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A).withValues(alpha: 0.84)
                      : Colors.white.withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.90),
                    width: 0.9,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _menuRow(ctx, isDark, Icons.photo_library_outlined, 'Fotos e imágenes', _attachImage),
                    _separator(isDark),
                    _menuRow(ctx, isDark, Icons.videocam_outlined, 'Videos', _attachVideo),
                    _separator(isDark),
                    _menuRow(ctx, isDark, Icons.picture_as_pdf_outlined, 'Documentos PDF', _attachPdf),
                    _separator(isDark),
                    _menuRow(ctx, isDark, Icons.folder_open_rounded, 'Biblioteca de Nano', _showNanoLibrary),
                    _separator(isDark),
                    _menuRow(ctx, isDark, Icons.description_outlined, 'Plantillas de texto', _showFormPicker),
                    _separator(isDark),
                    _menuRow(ctx, isDark, Icons.attach_file_rounded, 'Otros archivos', _attachAndShareFile),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuRow(
    BuildContext ctx,
    bool isDark,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final iconColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(ctx).pop();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(icon, size: 19, color: iconColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _separator(bool isDark) => Divider(
    height: 1,
    thickness: 0.6,
    indent: 44,
    endIndent: 0,
    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
  );

  Future<void> _attachImage() => _pickAndShareMedia(type: FileType.image, label: 'imagen');
  Future<void> _attachVideo() => _pickAndShareMedia(type: FileType.video, label: 'video');
  Future<void> _attachPdf() => _pickAndShareMedia(type: FileType.custom, allowedExtensions: ['pdf'], label: 'PDF');
  Future<void> _attachAndShareFile() => _pickAndShareMedia(type: FileType.any, label: 'archivo');

  Future<void> _pickAndShareMedia({
    required FileType type,
    List<String>? allowedExtensions,
    required String label,
  }) async {
    try {
      const share = WhatsAppMediaShare();
      final picked = await FilePicker.pickFiles(type: type, allowedExtensions: allowedExtensions);
      final file = picked?.files.single;
      if (file == null || file.path == null) return;

      _safeSetState(() {
        _busy = true;
        _statusText = 'Preparando $label para compartir...';
      });

      final stablePath = await share.copyToCatalog(file.path!, category: NanoMediaCategory.forFileName(file.name));
      if (stablePath == null) {
        _safeSetState(() => _statusText = 'No se pudo preparar el archivo para WhatsApp.');
        return;
      }
      final recipient = _verifiedAttachmentRecipient();
      if (recipient == null) {
        _safeSetState(() => _statusText = 'No hay una identidad verificable para ${widget.item.displayName}.');
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
