import 'dart:io';
import 'package:flutter/cupertino.dart';
import '../../engine/business/business_document_library.dart';
import 'business_3d_file_preview.dart';
import 'business_library_grid_actions.dart';
import 'pdf_document_thumbnail.dart';

/// Tarjeta iOS de archivo: previsualización, jerarquía textual y acciones.
class BusinessLibraryGridCard extends StatelessWidget {
  final BusinessDocument document;
  final bool selected, isSelectionMode, isDark;
  final ValueChanged<BusinessDocument> onSelect, onOpen, onShare;
  final ValueChanged<BusinessDocument> onRename, onDelete;

  const BusinessLibraryGridCard({
    super.key,
    required this.document,
    required this.selected,
    required this.isSelectionMode,
    required this.isDark,
    required this.onSelect,
    required this.onOpen,
    required this.onShare,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: selected ? const Color(0x45317EDC) : const Color(0xA0162535),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: selected ? const Color(0xFF438FEF) : const Color(0x1AFFFFFF),
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: CupertinoButton(
      onPressed: () => isSelectionMode ? onSelect(document) : onOpen(document),
      minimumSize: Size.zero,
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (isSelectionMode)
                CupertinoButton(
                  onPressed: () => onSelect(document),
                  minimumSize: const Size.square(32),
                  padding: EdgeInsets.zero,
                  child: Icon(
                    selected
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.circle,
                    size: 20,
                    color: selected
                        ? const Color(0xFF0A84FF)
                        : const Color(0xFF8CA0B4),
                  ),
                )
              else
                _sizeBadge(),
              const Spacer(),
              BusinessLibraryGridActions(
                document: document,
                onOpen: onOpen,
                onShare: onShare,
                onRename: onRename,
                onDelete: onDelete,
              ),
            ],
          ),
          Expanded(child: _thumbnail()),
          const SizedBox(height: 4),
          Text(
            document.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFE5EDF6),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _title(document.category),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF4DAEFF),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );

  /// La etiqueta mantiene el tamaño fuera del bloque de nombre y categoría.
  Widget _sizeBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0x16FFFFFF),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(
      _formatSize(document.sizeBytes),
      style: const TextStyle(
        color: Color(0xFFA6B6C6),
        fontSize: 9,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  /// Usa miniatura real cuando existe; conserva fallback para otros formatos.
  Widget _thumbnail() {
    if (document.isPdf) {
      return Center(
        child: PdfDocumentThumbnail(document: document, width: 72, height: 96),
      );
    }
    if (document.isImage && File(document.file.path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          document.file,
          width: double.infinity,
          height: 94,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() =>
      Business3dFilePreview(document: document, isDark: isDark);

  String _title(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
  String _formatSize(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1048576
      ? '${(bytes / 1024).toStringAsFixed(0)} KB'
      : '${(bytes / 1048576).toStringAsFixed(1)} MB';
}
