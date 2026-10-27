// conversation_pdf_viewer.dart
//
// QUÉ HACE:
// Visor interactivo de documentos PDF 100% estilo iOS sobre GlassSurface con zoom libre y fluido (hasta 8x),
// soporte de doble toque, impresión nativa, compartir y renombrado directo.
//
// CÓMO FUNCIONA:
// - Integra InteractiveViewer sobre PdfPreview permitiendo ampliar y desplazarse libremente.
// - Soporta doble toque para alternar entre escala normal (1.0x) y zoom detallado (2.5x).
// - Provee barra superior iOS Frosted Glass con acciones de imprimir, compartir y renombrar.
//
// POR QUÉ:
// Elimina las restricciones de escala fijas ofreciendo una experiencia QuickLook nativa de Apple (< 200 líneas).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:nanoai/core/widgets/nano_glass_window.dart';
import 'package:printing/printing.dart';
import 'conversation_media_source.dart';
import 'nano_glass_dialog.dart';
import 'nano_metallic_button.dart';

part 'conversation_pdf_viewer_actions.part.dart';

abstract final class ConversationPdfViewer {
  static Future<void> show(
    BuildContext context, {
    required String pathOrUrl,
    String? title,
  }) {
    return showNanoGlassWindow<void>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _ConversationPdfPreview(
        source: ConversationMediaSource(pathOrUrl),
        title: title,
      ),
    );
  }
}

class _ConversationPdfPreview extends StatefulWidget {
  final ConversationMediaSource source;
  final String? title;
  const _ConversationPdfPreview({required this.source, this.title});

  @override
  State<_ConversationPdfPreview> createState() =>
      _ConversationPdfPreviewState();
}

class _ConversationPdfPreviewState extends State<_ConversationPdfPreview> {
  late Future<Uint8List> _document;
  final TransformationController _transformController =
      TransformationController();
  late String _currentName;

  @override
  void initState() {
    super.initState();
    _currentName = widget.title?.trim().isNotEmpty == true
        ? widget.title!.trim()
        : widget.source.displayName;
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
      if (file == null || !await file.exists()) {
        throw StateError('El archivo ya no está disponible');
      }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw StateError('El PDF está vacío');
      return bytes;
    }
    final uri = source.launchUri;
    if (uri == null) throw const FormatException('URL de PDF inválida');
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('El servidor respondió ${response.statusCode}');
    }
    if (response.bodyBytes.isEmpty) throw StateError('El PDF está vacío');
    return response.bodyBytes;
  }

  void _handleDoubleTap() {
    HapticFeedback.selectionClick();
    _transformController.value =
        _transformController.value != Matrix4.identity()
        ? Matrix4.identity()
        : Matrix4.diagonal3Values(2.5, 2.5, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * (isLandscape ? 0.90 : 0.84),
      child: FutureBuilder<Uint8List>(
        future: _document,
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          return Column(
            children: [
              _buildHeader(bytes),
              Expanded(
                child: snapshot.hasError
                    ? _buildError(snapshot.error)
                    : (bytes == null
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF38BDF8),
                              ),
                            )
                          : GestureDetector(
                              onDoubleTap: _handleDoubleTap,
                              child: InteractiveViewer(
                                transformationController: _transformController,
                                minScale: 0.5,
                                maxScale: 8.0,
                                boundaryMargin: const EdgeInsets.all(250),
                                child: PdfPreview(
                                  build: (_) async => bytes,
                                  pdfFileName:
                                      _currentName.toLowerCase().endsWith(
                                        '.pdf',
                                      )
                                      ? _currentName
                                      : '$_currentName.pdf',
                                  canChangeOrientation: false,
                                  canChangePageFormat: false,
                                  canDebug: false,
                                  allowPrinting: false,
                                  allowSharing: false,
                                  actions: const [],
                                  scrollViewDecoration: const BoxDecoration(
                                    color: Colors.transparent,
                                  ),
                                ),
                              ),
                            )),
              ),
            ],
          );
        },
      ),
    );
  }
}
