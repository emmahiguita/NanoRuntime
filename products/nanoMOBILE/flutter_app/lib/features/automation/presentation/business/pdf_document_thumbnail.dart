// Renderiza la primera página real del PDF usando el plugin Printing ya instalado.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../engine/business/business_document_library.dart';

/// Mantiene una caché LRU pequeña para no rasterizar cada fila al hacer scroll.
abstract final class PdfDocumentThumbnailCache {
  static final _images = <String, Uint8List>{};
  static final _pending = <String, Future<Uint8List?>>{};

  // La versión del archivo invalida la miniatura cuando se reemplaza el PDF.
  static String _key(BusinessDocument doc) =>
      '${doc.file.path}:${doc.sizeBytes}:${doc.modifiedAt.microsecondsSinceEpoch}';

  /// Convierte solo la portada a baja resolución y reutiliza resultados recientes.
  static Future<Uint8List?> load(BusinessDocument document) {
    final key = _key(document);
    final cached = _images.remove(key);
    if (cached != null) {
      _images[key] = cached;
      return Future.value(cached);
    }
    return _pending.putIfAbsent(key, () => _render(key, document));
  }

  // Fallar al crear una miniatura no impide abrir el documento en el lector.
  static Future<Uint8List?> _render(
    String key,
    BusinessDocument document,
  ) async {
    try {
      final bytes = await document.file.readAsBytes();
      final page = await Printing.raster(
        bytes,
        pages: const [0],
        dpi: 48,
      ).first;
      final png = await page.toPng();
      _images[key] = png;
      if (_images.length > 8) _images.remove(_images.keys.first);
      return png;
    } on Object {
      return null;
    } finally {
      _pending.remove(key);
    }
  }
}

/// Estado de carga independiente por fila; el tap de la fila sigue abriendo el PDF.
final class PdfDocumentThumbnail extends StatefulWidget {
  const PdfDocumentThumbnail({super.key, required this.document});
  final BusinessDocument document;

  @override
  State<PdfDocumentThumbnail> createState() => _PdfDocumentThumbnailState();
}

final class _PdfDocumentThumbnailState extends State<PdfDocumentThumbnail> {
  late Future<Uint8List?> _image;

  @override
  void initState() {
    super.initState();
    _image = PdfDocumentThumbnailCache.load(widget.document);
  }

  // Cambia la imagen al cambiar de documento, sin conservar bytes de otro archivo.
  @override
  void didUpdateWidget(covariant PdfDocumentThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.file.path != widget.document.file.path ||
        oldWidget.document.modifiedAt != widget.document.modifiedAt) {
      _image = PdfDocumentThumbnailCache.load(widget.document);
    }
  }

  // Muestra el PDF real; deja un icono neutro si la primera página está dañada.
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 46,
    height: 62,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: FutureBuilder<Uint8List?>(
        future: _image,
        builder: (context, snapshot) => snapshot.data == null
            ? Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
              )
            : Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                cacheWidth: 138,
              ),
      ),
    ),
  );
}
