part of 'business_document_library_view.dart';

/// Ensambla vistas existentes sin duplicar filtros, catálogo ni almacenamiento.
/// La vista contenedora solo decide qué sección muestra y su estado de error.
extension _LibraryContents on BusinessDocumentLibraryView {
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
    onAnalyzeDocument: onAnalyzeDocument,
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
