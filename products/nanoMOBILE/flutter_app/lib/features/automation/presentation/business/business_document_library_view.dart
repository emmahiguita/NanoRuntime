import 'dart:ui';
import 'package:flutter/material.dart';
import '../../engine/business/business_document_library.dart';
import 'business_library_bottom_bar.dart';
import 'business_library_category_filters.dart';
import 'business_library_content.dart';
import 'business_library_header.dart';
import 'business_library_load_error.dart';
import 'business_library_search_bar.dart';

/// Composición única de la biblioteca: cada control aparece una sola vez.
final class BusinessDocumentLibraryView extends StatelessWidget {
  final String title, category, query, sortBy, fileType;
  final List<BusinessFolderInfo> folders;
  final List<BusinessDocument> documents;
  final int allDocumentsCount, totalSizeBytes;
  final Set<String> selectedPaths;
  final bool isSelectionMode, isGridView, isChatPicker, busy, canGenerate;
  final String? loadError;
  final ValueChanged<String> onCategory, onQuery, onSortChange;
  final ValueChanged<String> onFileTypeChange, onRenameFolder, onDeleteFolder;
  final ValueChanged<BusinessDocument> onSelectDocument, onOpen, onShare;
  final ValueChanged<BusinessDocument> onRenameDocument, onDeleteDocument;
  final VoidCallback onToggleSelectionMode, onToggleGridView, onSelectAll;
  final VoidCallback onSendSelected, onCreateFolder, onImport, onGenerate;
  final VoidCallback onClose, onRetry, onShowRecent, onShowAll;

  const BusinessDocumentLibraryView({
    super.key,
    required this.title,
    required this.category,
    required this.query,
    required this.sortBy,
    required this.fileType,
    required this.folders,
    required this.documents,
    required this.allDocumentsCount,
    required this.totalSizeBytes,
    required this.selectedPaths,
    required this.isSelectionMode,
    required this.isGridView,
    required this.isChatPicker,
    required this.busy,
    required this.canGenerate,
    required this.loadError,
    required this.onCategory,
    required this.onQuery,
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
    required this.onSelectAll,
    required this.onSendSelected,
    required this.onCreateFolder,
    required this.onImport,
    required this.onGenerate,
    required this.onClose,
    required this.onRetry,
    required this.onShowRecent,
    required this.onShowAll,
  });

  @override
  Widget build(BuildContext context) {
    const isDark = true;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xF20B1723), Color(0xF2142230)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF5D91B8).withValues(alpha: .45),
            ),
          ),
          child: Column(
            children: [
              BusinessLibraryHeader(
                isDark: isDark,
                isChatPicker: isChatPicker,
                onCreateFolder: onCreateFolder,
                onImport: onImport,
                onClose: onClose,
              ),
              BusinessLibrarySearchBar(
                query: query,
                isDark: isDark,
                onQuery: onQuery,
              ),
              BusinessLibraryCategoryFilters(
                folders: folders,
                selectedCategory: category,
                allDocumentsCount: allDocumentsCount,
                onCategory: onCategory,
                onShowFolders: onShowAll,
                onShowRecent: onShowRecent,
              ),
              if (busy)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: Color(0xFF087BFF),
                ),
              Expanded(
                child: loadError != null
                    ? BusinessLibraryLoadError(busy: busy, onRetry: onRetry)
                    : BusinessLibraryContent(
                        category: category,
                        query: query,
                        sortBy: sortBy,
                        fileType: fileType,
                        folders: folders,
                        documents: documents,
                        selectedPaths: selectedPaths,
                        isSelectionMode: isSelectionMode,
                        isGridView: isGridView,
                        isChatPicker: isChatPicker,
                        onCategory: onCategory,
                        onSortChange: onSortChange,
                        onFileTypeChange: onFileTypeChange,
                        onRenameFolder: onRenameFolder,
                        onDeleteFolder: onDeleteFolder,
                        onSelectDocument: onSelectDocument,
                        onOpen: onOpen,
                        onShare: onShare,
                        onRenameDocument: onRenameDocument,
                        onDeleteDocument: onDeleteDocument,
                        onToggleSelectionMode: onToggleSelectionMode,
                        onToggleGridView: onToggleGridView,
                        onShowAll: onShowAll,
                      ),
              ),
              BusinessLibraryBottomBar(
                totalCount: allDocumentsCount,
                totalSizeBytes: totalSizeBytes,
                selectedCount: selectedPaths.length,
                isSelectionMode: isSelectionMode,
                isChatPicker: isChatPicker,
                isDark: isDark,
                canGenerate: canGenerate,
                onSelectAll: onSelectAll,
                onSendSelected: onSendSelected,
                onGenerate: onGenerate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
