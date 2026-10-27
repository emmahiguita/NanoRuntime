import 'package:flutter/services.dart';

final class ExtractedPdfPage {
  const ExtractedPdfPage({
    required this.page,
    required this.text,
    this.ocr = false,
  });

  final int page;
  final String text;
  final bool ocr;
}

final class ExtractedPdfDocument {
  const ExtractedPdfDocument({
    required this.pages,
    required this.totalPages,
    required this.partial,
  });

  final List<ExtractedPdfPage> pages;
  final int totalPages;
  final bool partial;
}

/// Puente local de lectura. No persiste texto ni autoriza productos por sí solo.
final class PdfTextExtractionService {
  const PdfTextExtractionService();

  static const _channel = MethodChannel('dev.nanoai/pdf_text');

  Future<List<ExtractedPdfPage>> extractPages(String path) async {
    final rows = await _channel.invokeListMethod<dynamic>('extractPages', {
      'path': path,
    });
    if (rows == null) return const [];
    return [
      for (final row in rows)
        if (row is Map)
          ExtractedPdfPage(
            page: (row['page'] as num?)?.toInt() ?? 0,
            text: row['text']?.toString() ?? '',
          ),
    ];
  }

  /// Lee texto real y hace OCR solo en páginas PDF sin capa de texto.
  /// El lector Android limita el trabajo a 8 páginas, 100k caracteres y 15 s.
  Future<ExtractedPdfDocument> readMessagePdf(String path) async {
    final result = await _channel.invokeMapMethod<dynamic, dynamic>(
      'readMessagePdf',
      {'path': path},
    );
    final rawPages = result?['pages'];
    final pages = <ExtractedPdfPage>[];
    if (rawPages is List) {
      for (final row in rawPages) {
        if (row is! Map) continue;
        pages.add(
          ExtractedPdfPage(
            page: (row['page'] as num?)?.toInt() ?? 0,
            text: row['text']?.toString() ?? '',
            ocr: row['ocr'] == true,
          ),
        );
      }
    }
    return ExtractedPdfDocument(
      pages: pages,
      totalPages: (result?['totalPages'] as num?)?.toInt() ?? pages.length,
      partial: result?['partial'] == true,
    );
  }
}
