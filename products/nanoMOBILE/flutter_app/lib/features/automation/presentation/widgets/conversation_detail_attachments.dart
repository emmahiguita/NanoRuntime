// conversation_detail_attachments.dart
//
// QUÉ HACE:
// Menú flotante de adjuntos con diseño iOS Context Menu sobre GlassSurface: compacto,
// profesional y con opciones completas y legibles.
//
// CÓMO FUNCIONA:
// - Despliega showNanoGlassWindow con ancho compacto (310px) y divisores iOS.
// - Cada opción es una fila compacta de 42px con tipografía nítida y respuesta táctil inmediata.
// - Conecta con FilePicker y WhatsAppMediaShare para despachar fotos, videos, PDFs, notas de voz y catálogos.
//
// POR QUÉ:
// Optimiza el espacio visual eliminando tarjetas opacas redundantes (< 200 líneas).

part of 'conversation_detail_sheet.dart';

extension ConversationDetailAttachments on _ConversationDetailSheetState {
  void _showAttachmentMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showNanoGlassWindow(
      context: context,
      useRootNavigator: true,
      constraints: const BoxConstraints(maxWidth: 310),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _menuRow(
              ctx,
              isDark,
              Icons.photo_library_outlined,
              'Fotos e imágenes',
              _attachImage,
            ),
            _separator(isDark),
            _menuRow(
              ctx,
              isDark,
              Icons.videocam_outlined,
              'Videos',
              _attachVideo,
            ),
            _separator(isDark),
            _menuRow(
              ctx,
              isDark,
              Icons.picture_as_pdf_outlined,
              'Documentos PDF',
              _attachPdf,
            ),
            _separator(isDark),
            _menuRow(
              ctx,
              isDark,
              Icons.mic_none_rounded,
              'Notas de voz y audio',
              _attachVoiceNote,
            ),
            _separator(isDark),
            _menuRow(
              ctx,
              isDark,
              Icons.folder_open_rounded,
              'Biblioteca de Nano',
              _showNanoLibrary,
            ),
            _separator(isDark),
            _menuRow(
              ctx,
              isDark,
              Icons.description_outlined,
              'Plantillas de texto',
              _showFormPicker,
            ),
            _separator(isDark),
            _menuRow(
              ctx,
              isDark,
              Icons.attach_file_rounded,
              'Otros archivos',
              _attachAndShareFile,
            ),
          ],
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
    final iconColor = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF475569);

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
    color: isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06),
  );

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
}
