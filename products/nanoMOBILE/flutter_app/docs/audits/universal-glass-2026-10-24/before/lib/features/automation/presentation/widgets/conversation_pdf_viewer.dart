// conversation_pdf_viewer.dart
//
// QUÉ HACE:
// Visor interactivo de documentos PDF 100% estilo iOS con zoom libre y fluido (hasta 8x),
// soporte de doble toque, impresión nativa, compartir, renombrado directo y drag handle iOS.
//
// CÓMO FUNCIONA:
// - Integra InteractiveViewer sobre PdfPreview permitiendo ampliar y desplazarse libremente.
// - Soporta doble toque para alternar entre escala normal (1.0x) y zoom detallado (2.5x).
// - Provee barra superior iOS Frosted Glass con acciones de imprimir, compartir, renombrar y cerrar.
//
// POR QUÉ:
// Elimina las restricciones de escala fijas ofreciendo una experiencia QuickLook nativa de Apple (< 190 líneas).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'conversation_media_source.dart';
import 'nano_glass_dialog.dart';
import 'nano_metallic_button.dart';

abstract final class ConversationPdfViewer {
  static Future<void> show(BuildContext context, {required String pathOrUrl, String? title}) {
    return showModalBottomSheet<void>(
      context: context, useRootNavigator: true, isScrollControlled: true, useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConversationPdfPreview(source: ConversationMediaSource(pathOrUrl), title: title),
    );
  }
}

class _ConversationPdfPreview extends StatefulWidget {
  final ConversationMediaSource source;
  final String? title;
  const _ConversationPdfPreview({required this.source, this.title});

  @override
  State<_ConversationPdfPreview> createState() => _ConversationPdfPreviewState();
}

class _ConversationPdfPreviewState extends State<_ConversationPdfPreview> {
  late Future<Uint8List> _document;
  final TransformationController _transformController = TransformationController();
  late String _currentName;

  @override
  void initState() {
    super.initState();
    _currentName = widget.title?.trim().isNotEmpty == true ? widget.title!.trim() : widget.source.displayName;
    _document = _loadDocument();
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<Uint8List> _loadDocument() async {
    final source = widget.source;
    if (source.isLocal) {
      final file = source.localFile;
      if (file == null || !await file.exists()) throw StateError('El archivo ya no está disponible');
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw StateError('El PDF está vacío');
      return bytes;
    }
    final uri = source.launchUri;
    if (uri == null) throw const FormatException('URL de PDF inválida');
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) throw StateError('El servidor respondió ${response.statusCode}');
    if (response.bodyBytes.isEmpty) throw StateError('El PDF está vacío');
    return response.bodyBytes;
  }

  void _handleDoubleTap() {
    HapticFeedback.selectionClick();
    _transformController.value = _transformController.value != Matrix4.identity() ? Matrix4.identity() : Matrix4.diagonal3Values(2.5, 2.5, 1.0);
  }

  Future<void> _renameFile() async {
    final controller = TextEditingController(text: _currentName);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final newName = await NanoGlassDialog.show<String>(
      context: context, title: 'Renombrar documento', subtitle: 'Modifica el nombre visible de este PDF',
      icon: Icons.edit_note_rounded, iconColor: const Color(0xFF38BDF8),
      content: TextField(
        controller: controller, autofocus: true,
        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5),
        decoration: InputDecoration(
          hintText: 'Nombre del archivo', filled: true,
          fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        ),
      ),
      actions: [
        NanoMetallicButton(label: 'Cancelar', style: NanoMetallicButtonStyle.subtle, onPressed: () => Navigator.pop(context)),
        NanoMetallicButton(label: 'Guardar', icon: Icons.check_rounded, style: NanoMetallicButtonStyle.primary, onPressed: () => Navigator.pop(context, controller.text.trim())),
      ],
    );

    if (newName != null && newName.isNotEmpty && newName != _currentName) {
      if (widget.source.isLocal && widget.source.localFile != null) {
        final f = widget.source.localFile!;
        final targetExt = newName.toLowerCase().endsWith('.pdf') ? newName : '$newName.pdf';
        try { await f.rename('${f.parent.path}/$targetExt'); } catch (_) {}
      }
      setState(() => _currentName = newName);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: isLandscape ? 0.98 : 0.95,
        child: Material(
          color: const Color(0xFF0B1120),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: FutureBuilder<Uint8List>(
            future: _document,
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              return Column(
                children: [
                  const SizedBox(height: 6),
                  Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 4),
                  _buildHeader(bytes),
                  Expanded(
                    child: snapshot.hasError
                        ? _buildError(snapshot.error)
                        : (bytes == null
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFF38BDF8)))
                            : GestureDetector(
                                onDoubleTap: _handleDoubleTap,
                                child: InteractiveViewer(
                                  transformationController: _transformController,
                                  minScale: 0.5,
                                  maxScale: 8.0,
                                  boundaryMargin: const EdgeInsets.all(250),
                                  child: PdfPreview(
                                    build: (_) async => bytes,
                                    pdfFileName: _currentName.toLowerCase().endsWith('.pdf') ? _currentName : '$_currentName.pdf',
                                    canChangeOrientation: false, canChangePageFormat: false, canDebug: false,
                                    allowPrinting: false, allowSharing: false, actions: const [],
                                    scrollViewDecoration: const BoxDecoration(color: Color(0xFF0B1120)),
                                  ),
                                ),
                              )),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Uint8List? bytes) => Container(
    padding: const EdgeInsets.fromLTRB(14, 6, 8, 8),
    decoration: BoxDecoration(
      color: const Color(0xFF0F172A).withValues(alpha: 0.92),
      border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.10), width: 0.8)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.20), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFF87171), size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(_currentName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        IconButton(icon: const Icon(Icons.drive_file_rename_outline_rounded, color: Colors.white70, size: 18), tooltip: 'Renombrar', onPressed: _renameFile),
        if (bytes != null) ...[
          IconButton(icon: const Icon(Icons.print_rounded, color: Colors.white70, size: 18), tooltip: 'Imprimir', onPressed: () => Printing.layoutPdf(name: _currentName, onLayout: (_) async => bytes)),
          IconButton(icon: const Icon(Icons.share_rounded, color: Colors.white70, size: 18), tooltip: 'Compartir', onPressed: () => Printing.sharePdf(bytes: bytes, filename: _currentName.toLowerCase().endsWith('.pdf') ? _currentName : '$_currentName.pdf')),
        ],
        IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20), onPressed: () => Navigator.of(context).pop()),
      ],
    ),
  );

  Widget _buildError(Object? error) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.amber, size: 36),
          const SizedBox(height: 8),
          const Text('No se pudo visualizar el PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('$error', textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          const SizedBox(height: 12),
          NanoMetallicButton(label: 'Reintentar', icon: Icons.refresh_rounded, onPressed: () => setState(() => _document = _loadDocument())),
        ],
      ),
    ),
  );
}
