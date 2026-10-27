// conversation_doc_card.dart
//
// QUÉ HACE:
// Tarjetas interactivas para documentos PDF y archivos adjuntos en el chat.
//
// CÓMO FUNCIONA:
// - Abre documentos PDF en el visor nativo/impresor de páginas vía Printing.layoutPdf.
// - Abre otros tipos de archivos adjuntos mediante enlaces y aplicaciones del sistema.
//
// POR QUÉ:
// Mantiene la arquitectura limpia (SRP) y archivos estrictamente bajo 200 líneas.

library;

import 'package:flutter/material.dart';
import 'conversation_media_viewer.dart';
import 'conversation_media_source.dart';

/// Tarjeta para documentos PDF con acción táctil de visualización.
class ConversationPdfCard extends StatelessWidget {
  final String pathOrUrl;
  const ConversationPdfCard({super.key, required this.pathOrUrl});

  @override
  Widget build(BuildContext context) {
    final fileName = ConversationMediaSource(pathOrUrl).displayName;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => ConversationMediaViewer.openPdfDocument(
        context,
        pathOrUrl: pathOrUrl,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.redAccent.withValues(alpha: 0.16)
              : Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.redAccent.withValues(alpha: 0.38)
                : Colors.red.withValues(alpha: 0.25),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName.isNotEmpty ? fileName : 'Documento.pdf',
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Visualizar PDF · Toca para abrir',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.visibility_rounded,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta para archivos genéricos adjuntos.
class ConversationFileCard extends StatelessWidget {
  final String pathOrUrl;
  const ConversationFileCard({super.key, required this.pathOrUrl});

  @override
  Widget build(BuildContext context) {
    final name = ConversationMediaSource(pathOrUrl).displayName;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => ConversationMediaViewer.openExternalLink(context, pathOrUrl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.20)
                : const Color(0x33CBD5E1),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.attach_file_rounded,
              color: isDark ? Colors.white70 : const Color(0xFF64748B),
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
