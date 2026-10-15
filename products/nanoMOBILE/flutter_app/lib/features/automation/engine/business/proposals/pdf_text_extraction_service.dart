import 'package:flutter/services.dart';

final class ExtractedPdfPage {
  const ExtractedPdfPage({required this.page, required this.text});

  final int page;
  final String text;
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
}
