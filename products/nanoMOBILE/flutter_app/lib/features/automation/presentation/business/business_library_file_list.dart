import 'package:flutter/material.dart';
import '../../engine/business/business_document_library.dart';
import 'business_library_file_actions.dart';
import 'business_library_file_thumbnail.dart';

/// Lista compacta iOS: datos a la izquierda y acciones reales sin submenús duplicados.
class BusinessLibraryFileList extends StatelessWidget {
  final List<BusinessDocument> documents;
  final Set<String> selectedPaths;
  final bool isSelectionMode, isChatPicker, isDark;
  final ValueChanged<BusinessDocument> onSelectDocument, onOpen, onShare;
  final ValueChanged<BusinessDocument> onRenameDocument, onDeleteDocument;

  const BusinessLibraryFileList({
    super.key,
    required this.documents,
    required this.selectedPaths,
    required this.isSelectionMode,
    required this.isChatPicker,
    required this.isDark,
    required this.onSelectDocument,
    required this.onOpen,
    required this.onShare,
    required this.onRenameDocument,
    required this.onDeleteDocument,
  });

  @override
  Widget build(BuildContext context) => SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    sliver: SliverList.builder(
      itemCount: documents.length,
      itemBuilder: (_, index) {
        final doc = documents[index];
        final selected = selectedPaths.contains(doc.file.path);
        return Container(
          constraints: const BoxConstraints(minHeight: 76),
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0x45317EDC) : const Color(0xA0162535),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? const Color(0xFF438FEF)
                  : Colors.white.withValues(alpha: .08),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isSelectionMode
                  ? () => onSelectDocument(doc)
                  : () => onOpen(doc),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                child: Row(
                  children: [
                    if (isSelectionMode) ...[
                      SizedBox(
                        width: 24,
                        child: Checkbox(
                          value: selected,
                          onChanged: (_) => onSelectDocument(doc),
                          activeColor: const Color(0xFF087BFF),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    BusinessLibraryFileThumbnail(document: doc),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFE5EDF6),
                              fontSize: 12.5,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_title(doc.category)}  •  ${_formatSize(doc.sizeBytes)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF8BA0B5),
                              fontSize: 10,
                              height: 1.15,
                            ),
                          ),
                          Text(
                            _formatDate(doc.modifiedAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF748A9F),
                              fontSize: 9,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isSelectionMode)
                      BusinessLibraryFileActions(
                        document: doc,
                        onOpen: onOpen,
                        onShare: onShare,
                        onRename: onRenameDocument,
                        onDelete: onDeleteDocument,
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

  String _title(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
  String _formatSize(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1048576
      ? '${(bytes / 1024).toStringAsFixed(0)} KB'
      : '${(bytes / 1048576).toStringAsFixed(1)} MB';
  String _formatDate(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year}, $hour:$minute ${date.hour < 12 ? 'a. m.' : 'p. m.'}';
  }
}
