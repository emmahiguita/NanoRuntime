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
// Aplica SOLID coordinando subcomponentes especializados (< 160 líneas).

import 'dart:ui';
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
  final ValueChanged<BusinessDocument> onSelectDocument, onOpen, onShare, onRenameDocument, onDeleteDocument;
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
            border: Border.all(color: const Color(0x735D91B8)),
          ),
          child: Column(
            children: [
              BusinessLibraryHeader(
                isDark: true,
                isChatPicker: isChatPicker,
                isStore: !isDocs,
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
                BusinessLibrarySearchBar(query: query, isDark: true, onQuery: onQuery),
                BusinessLibraryCategoryFilters(folders: folders, selectedCategory: category, allDocumentsCount: allDocumentsCount, onCategory: onCategory, onShowFolders: onShowAll, onShowRecent: onShowRecent),
              ],
              if (busy) const LinearProgressIndicator(minHeight: 2, color: Color(0xFF087BFF)),
              Expanded(
                child: loadError != null
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
                  isDark: true,
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

  Widget _docsContent() => BusinessLibraryContent(
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
      );

  Widget _storeContent() => BusinessStoreContent(
        products: products,
        onAddProduct: onAddProduct,
        onEditProduct: onEditProduct,
        onShareProduct: onShareProduct,
      );
}
