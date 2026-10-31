// business_document_library_view.dart
//
// QUÉ HACE:
// Vista contenedora principal de la Biblioteca Comercial de Nano.
// Alterna entre explorador de Archivos/PDFs y el Catálogo/Tienda de productos.
//
// CÓMO FUNCIONA:
// - Despliega un fondo esmerilado translúcido estilo iOS Liquid Glass.
// - Integra `BusinessLibrarySectionTabs` para cambiar entre Documentos y Tienda.
//
// POR QUÉ:
// Aplica SOLID coordinando subcomponentes especializados (< 165 líneas).

import 'package:nanoai/core/widgets/glass_surface.dart';
import 'package:flutter/material.dart';
import '../../engine/business/business_document_library.dart';
import '../../engine/business/business_product.dart';
import 'business_library_bottom_bar.dart';
import 'business_library_category_filters.dart';
import 'business_library_content.dart';
import 'business_library_header.dart';
import 'business_library_load_error.dart';
import 'business_library_search_bar.dart';
import 'business_library_section_tabs.dart';
import 'store/business_store_content.dart';

part 'business_library_contents.part.dart';

final class BusinessDocumentLibraryView extends StatelessWidget {
  final String title, category, query, sortBy, fileType;
  final List<BusinessFolderInfo> folders;
  final List<BusinessDocument> documents;
  final List<BusinessProduct> products;
  final BusinessLibrarySection section;
  final int allDocumentsCount, totalSizeBytes;
  final Set<String> selectedPaths;
  final bool isSelectionMode, isGridView, isChatPicker, busy, canGenerate;
  final String? loadError;
  final ValueChanged<BusinessLibrarySection> onSectionChanged;
  final ValueChanged<String> onCategory, onQuery, onSortChange, onFileTypeChange, onRenameFolder, onDeleteFolder;
  final ValueChanged<BusinessDocument> onSelectDocument,
      onOpen,
      onShare,
      onAnalyzeDocument,
      onRenameDocument,
      onDeleteDocument;
  final ValueChanged<BusinessProduct> onEditProduct, onShareProduct;
  final VoidCallback onAddProduct, onToggleSelectionMode, onToggleGridView, onSelectAll, onSendSelected;
  final VoidCallback onCreateFolder, onImport, onGenerate, onClose, onRetry, onShowRecent, onShowAll;

  const BusinessDocumentLibraryView({
    super.key,
    required this.title,
    required this.category,
    required this.query,
    required this.sortBy,
    required this.fileType,
    required this.folders,
    required this.documents,
    required this.products,
    required this.section,
    required this.allDocumentsCount,
    required this.totalSizeBytes,
    required this.selectedPaths,
    required this.isSelectionMode,
    required this.isGridView,
    required this.isChatPicker,
    required this.busy,
    required this.canGenerate,
    required this.loadError,
    required this.onSectionChanged,
    required this.onCategory,
    required this.onQuery,
    required this.onSortChange,
    required this.onFileTypeChange,
    required this.onRenameFolder,
    required this.onDeleteFolder,
    required this.onSelectDocument,
    required this.onOpen,
    required this.onShare,
    required this.onAnalyzeDocument,
    required this.onRenameDocument,
    required this.onDeleteDocument,
    required this.onEditProduct,
    required this.onShareProduct,
    required this.onAddProduct,
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
    final isDocs = section == BusinessLibrarySection.documents;
    return GlassSurface(
      interactive: false,
      padding: EdgeInsets.zero,
      radius: 24,
      child: Column(
        children: [
          BusinessLibraryHeader(
            isDark: Theme.of(context).brightness == Brightness.dark,
            isChatPicker: isChatPicker,
            isStore: !isDocs,
            productsCount: products.length,
            onCreateFolder: onCreateFolder,
            onImport: onImport,
            onAddProduct: onAddProduct,
            onClose: onClose,
          ),
          BusinessLibrarySectionTabs(
            currentSection: section,
            documentsCount: allDocumentsCount,
            productsCount: products.length,
            onSectionChanged: onSectionChanged,
          ),
          if (isDocs) ...[
            BusinessLibrarySearchBar(
              query: query,
              isDark: Theme.of(context).brightness == Brightness.dark,
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
          ],
          if (busy) LinearProgressIndicator(minHeight: 2, color: Theme.of(context).colorScheme.primary),
          Expanded(
            child: isDocs && loadError != null
                ? BusinessLibraryLoadError(busy: busy, onRetry: onRetry)
                : (isDocs ? _docsContent() : _storeContent()),
          ),
          if (isDocs)
            BusinessLibraryBottomBar(
              totalCount: allDocumentsCount,
              totalSizeBytes: totalSizeBytes,
              selectedCount: selectedPaths.length,
              isSelectionMode: isSelectionMode,
              isChatPicker: isChatPicker,
              isDark: Theme.of(context).brightness == Brightness.dark,
              canGenerate: canGenerate,
              onSelectAll: onSelectAll,
              onSendSelected: onSendSelected,
              onGenerate: onGenerate,
            ),
        ],
      ),
    );
  }
}
