import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';

import 'conversation_media_source.dart';

/// Visor PDF integrado con carga local/remota, zoom, impresión y compartir.
abstract final class ConversationPdfViewer {
  static Future<void> show(BuildContext context, {required String pathOrUrl, String? title}) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
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

  @override
  void initState() {
    super.initState();
    _document = _loadDocument();
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

  void _retry() => setState(() => _document = _loadDocument());

  @override
  Widget build(BuildContext context) {
    final fileName = widget.title?.trim().isNotEmpty == true ? widget.title!.trim() : widget.source.displayName;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.94,
        child: Material(
          color: const Color(0xFF0F172A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _PdfViewerHeader(title: fileName),
              Expanded(
                child: FutureBuilder<Uint8List>(
                  future: _document,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _PdfLoadError(message: '${snapshot.error}', onRetry: _retry);
                    }
                    final bytes = snapshot.data;
                    if (bytes == null) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF60A5FA)));
                    }
                    return PdfPreview(
                      build: (_) async => bytes,
                      pdfFileName: fileName.toLowerCase().endsWith('.pdf') ? fileName : '$fileName.pdf',
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      canDebug: false,
                      allowPrinting: true,
                      allowSharing: true,
                      maxPageWidth: 720,
                      scrollViewDecoration: const BoxDecoration(color: Color(0xFF111827)),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfViewerHeader extends StatelessWidget {
  final String title;

  const _PdfViewerHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
      child: Row(
        children: [
          const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFF87171)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
          Semantics(
            label: 'Cerrar',
            button: true,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}

class _PdfLoadError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _PdfLoadError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.amber, size: 42),
            const SizedBox(height: 12),
            const Text(
              'No se pudo visualizar el PDF',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
