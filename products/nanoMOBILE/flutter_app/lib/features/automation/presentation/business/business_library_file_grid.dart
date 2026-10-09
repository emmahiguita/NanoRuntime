// business_library_file_grid.dart
//
// QUÉ HACE:
// Renderiza la cuadrícula de archivos comerciales con previsualización miniatura 3D realista
// para PDFs, hojas de cálculo, videos y fotos, junto con metadatos y opciones rápidas.
//
// CÓMO FUNCIONA:
// - Construye tarjetas adaptables con bordes translúcidos y sombreados iOS Liquid Glass.
// - Ofrece selección táctil individual y menú emergente para renombrar, compartir o eliminar.
//
// POR QUÉ:
// Soluciona la apariencia plana vacía, dotando a la app de estética iOS Files premium (< 150 líneas).

import 'dart:io';
import 'package:flutter/material.dart';
import '../../engine/business/business_document_library.dart';
import 'business_3d_file_preview.dart';
import 'pdf_document_thumbnail.dart';

class BusinessLibraryFileGrid extends StatelessWidget {
  final List<BusinessDocument> documents;
  final Set<String> selectedPaths;
  final bool isSelectionMode, isDark;
  final ValueChanged<BusinessDocument> onSelectDocument,
      onOpen,
      onShare,
      onRenameDocument,
      onDeleteDocument;

  const BusinessLibraryFileGrid({
    super.key,
    required this.documents,
    required this.selectedPaths,
    required this.isSelectionMode,
    required this.isDark,
    required this.onSelectDocument,
    required this.onOpen,
    required this.onShare,
    required this.onRenameDocument,
    required this.onDeleteDocument,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 182,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: documents.length,
        itemBuilder: (context, index) {
          final doc = documents[index];
          final isSelected = selectedPaths.contains(doc.file.path);

          return Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark
                        ? const Color(0xFF0284C7).withValues(alpha: 0.20)
                        : const Color(0xFFE0F2FE))
                  : (isDark
                        ? const Color(0xFF1E293B).withValues(alpha: 0.50)
                        : Colors.white.withValues(alpha: 0.85)),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF38BDF8)
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : const Color(0xFFE2E8F0)),
                width: isSelected ? 1.2 : 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: isSelectionMode
                    ? () => onSelectDocument(doc)
                    : () => onOpen(doc),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (isSelectionMode)
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (_) => onSelectDocument(doc),
                                activeColor: const Color(0xFF0284C7),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white10
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _formatSize(doc.sizeBytes),
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white60
                                      : const Color(0xFF64748B),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              Icons.more_horiz_rounded,
                              size: 16,
                              color: isDark
                                  ? Colors.white54
                                  : const Color(0xFF94A3B8),
                            ),
                            onSelected: (val) {
                              if (val == 'open') onOpen(doc);
                              if (val == 'share') onShare(doc);
                              if (val == 'rename') onRenameDocument(doc);
                              if (val == 'delete') onDeleteDocument(doc);
                            },
                            itemBuilder: (ctx) => const [
                              PopupMenuItem(
                                value: 'open',
                                child: Text('Abrir'),
                              ),
                              PopupMenuItem(
                                value: 'share',
                                child: Text('Compartir'),
                              ),
                              PopupMenuItem(
                                value: 'rename',
                                child: Text('Renombrar'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Eliminar',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Expanded(child: _buildThumbnail(doc)),
                      const SizedBox(height: 4),
                      Text(
                        doc.name,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _capitalize(doc.category),
                        style: TextStyle(
                          color: isDark
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF0284C7),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildThumbnail(BusinessDocument doc) {
    if (doc.isPdf) {
      return Center(
        child: PdfDocumentThumbnail(document: doc, width: 72, height: 96),
      );
    }
    if (doc.isImage && File(doc.file.path).existsSync()) {
      return Container(
        height: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            doc.file,
            width: double.infinity,
            height: 90,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Business3dFilePreview(document: doc, isDark: isDark),
          ),
        ),
      );
    }
    return Business3dFilePreview(document: doc, isDark: isDark);
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
  String _formatSize(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(0)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
