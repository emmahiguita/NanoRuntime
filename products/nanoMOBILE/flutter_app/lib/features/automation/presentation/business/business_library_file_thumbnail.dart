import 'dart:io';
import 'package:flutter/material.dart';
import '../../engine/business/business_document_library.dart';
import 'pdf_document_thumbnail.dart';

/// Miniatura real para PDF/imagen y fallback legible para otros formatos.
class BusinessLibraryFileThumbnail extends StatelessWidget {
  final BusinessDocument document;

  const BusinessLibraryFileThumbnail({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    if (document.isPdf) {
      return PdfDocumentThumbnail(document: document, width: 42, height: 50);
    }
    if (document.isImage && File(document.file.path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.file(
          document.file,
          width: 42,
          height: 50,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    final (accent, label) = switch (true) {
      _ when document.isSheet => (const Color(0xFF2ACB88), 'XLSX'),
      _ when document.isVideo => (const Color(0xFF9B70F5), 'VIDEO'),
      _ => (const Color(0xFF3998F4), 'DOC'),
    };
    return Container(
      width: 42,
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EEF4),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              document.isVideo
                  ? Icons.play_circle_fill_rounded
                  : Icons.description_outlined,
              color: accent,
              size: 23,
            ),
          ),
          Positioned(
            left: 3,
            bottom: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xD90D1722),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 6.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
