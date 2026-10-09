import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../engine/business/business_document_library.dart';
import 'business_library_file_grid.dart';
import 'business_library_file_list.dart';
import 'business_library_folders_carousel.dart';
import 'business_library_toolbar.dart';

/// Contenido desplazable de la biblioteca, separado del marco modal.
class BusinessLibraryContent extends StatelessWidget {
  final String category, query, sortBy, fileType;
  final List<BusinessFolderInfo> folders;
  final List<BusinessDocument> documents;
  final Set<String> selectedPaths;
  final bool isSelectionMode, isGridView, isChatPicker;
  final ValueChanged<String> onCategory, onSortChange, onFileTypeChange;
  final ValueChanged<String> onRenameFolder, onDeleteFolder;
  final ValueChanged<BusinessDocument> onSelectDocument, onOpen, onShare;
  final ValueChanged<BusinessDocument> onRenameDocument, onDeleteDocument;
  final VoidCallback onToggleSelectionMode, onToggleGridView, onShowAll;

  const BusinessLibraryContent({
    super.key,
    required this.category,
    required this.query,
    required this.sortBy,
    required this.fileType,
    required this.folders,
    required this.documents,
    required this.selectedPaths,
    required this.isSelectionMode,
    required this.isGridView,
    required this.isChatPicker,
    required this.onCategory,
    required this.onSortChange,
    required this.onFileTypeChange,
    required this.onRenameFolder,
    required this.onDeleteFolder,
    required this.onSelectDocument,
    required this.onOpen,
    required this.onShare,
    required this.onRenameDocument,
    required this.onDeleteDocument,
    required this.onToggleSelectionMode,
    required this.onToggleGridView,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverToBoxAdapter(
        child: BusinessLibraryToolbar(
          isDark: true,
          isGridView: isGridView,
          isSelectionMode: isSelectionMode,
          sortBy: sortBy,
          fileType: fileType,
          onToggleGridView: onToggleGridView,
          onToggleSelectionMode: onToggleSelectionMode,
          onSortChange: onSortChange,
          onFileTypeChange: onFileTypeChange,
        ),
      ),
      if (query.isEmpty) ...[
        _section('Carpetas', onShowAll),
        SliverToBoxAdapter(
          child: BusinessLibraryFoldersCarousel(
            folders: folders,
            isDark: true,
            onCategory: onCategory,
            onRenameFolder: onRenameFolder,
            onDeleteFolder: onDeleteFolder,
          ),
        ),
      ],
      _section(
        category == BusinessDocumentLibrary.allCategory
            ? 'Archivos recientes'
            : category,
        onShowAll,
      ),
      if (documents.isEmpty)
        _empty()
      else if (isGridView)
        BusinessLibraryFileGrid(
          documents: documents,
          selectedPaths: selectedPaths,
          isSelectionMode: isSelectionMode,
          isDark: true,
          onSelectDocument: onSelectDocument,
          onOpen: onOpen,
          onShare: onShare,
          onRenameDocument: onRenameDocument,
          onDeleteDocument: onDeleteDocument,
        )
      else
        BusinessLibraryFileList(
          documents: documents,
          selectedPaths: selectedPaths,
          isSelectionMode: isSelectionMode,
          isChatPicker: isChatPicker,
          isDark: true,
          onSelectDocument: onSelectDocument,
          onOpen: onOpen,
          onShare: onShare,
          onRenameDocument: onRenameDocument,
          onDeleteDocument: onDeleteDocument,
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
    ],
  );

  Widget _section(String text, VoidCallback action) => SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 7, 12, 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFFDCE7F4),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          CupertinoButton(
            onPressed: action,
            minimumSize: const Size.square(30),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: const Text(
              'Ver todos',
              style: TextStyle(
                color: Color(0xFF4DAEFF),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _empty() => const SliverToBoxAdapter(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Column(
        children: [
          Icon(Icons.folder_open_rounded, size: 36, color: Color(0xFF6E8197)),
          SizedBox(height: 8),
          Text(
            'No se encontraron archivos',
            style: TextStyle(color: Color(0xFF91A4B9), fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
