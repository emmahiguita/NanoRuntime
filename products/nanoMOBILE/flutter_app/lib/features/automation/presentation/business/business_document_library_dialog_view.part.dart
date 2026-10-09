// business_document_library_dialog_view.part.dart
//
// QUÉ HACE:
// Conexión visual del diálogo de biblioteca: enlaza el estado con `BusinessDocumentLibraryView`.
//
// CÓMO FUNCIONA:
// - Pasa propiedades reactivas de archivos, carpetas, filtros y catálogo de productos a la vista.
// - Conecta los callbacks de navegación, selección, tienda y acciones de documento.
//
// POR QUÉ:
// Mantiene dividida la implementación del widget dialog en archivos menores a 140 líneas.

part of 'business_document_library_dialog.dart';

extension _BusinessDocumentLibraryDialogView
    on _BusinessDocumentLibraryDialogState {
  Widget _buildLibrary(BuildContext context) => BusinessDocumentLibraryView(
    title: _business,
    category: _category,
    folders: _folders,
    query: _query,
    documents: _visibleDocuments,
    products: _facts.products,
    section: _section,
    allDocumentsCount: _allDocuments.length,
    totalSizeBytes: _totalSize,
    selectedPaths: _selectedPaths,
    isSelectionMode: _isSelectionMode,
    isGridView: _isGridView,
    isChatPicker: widget.onSendToChat != null,
    sortBy: _sortBy,
    fileType: _fileType,
    loadError: _loadError,
    busy: _busy,
    canGenerate: _facts.products.isNotEmpty,
    onSectionChanged: (sec) => setState(() => _section = sec),
    onCategory: (value) async {
      setState(() => _category = value);
      await _refresh();
    },
    onQuery: (value) => setState(() => _query = value),
    onToggleSelectionMode: () => setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedPaths.clear();
    }),
    onToggleGridView: () => setState(() => _isGridView = !_isGridView),
    onSortChange: (value) => setState(() => _sortBy = value),
    onFileTypeChange: (value) => setState(() => _fileType = value),
    onShowRecent: () => _resetScope(recent: true),
    onShowAll: _resetScope,
    onSelectDocument: _toggleSelection,
    onSelectAll: () => setState(() {
      _selectedPaths.length == _visibleDocuments.length
          ? _selectedPaths.clear()
          : _selectedPaths.addAll(
              _visibleDocuments.map((doc) => doc.file.path),
            );
    }),
    onSendSelected: _sendSelected,
    onCreateFolder: () => BusinessFolderActions.createFolder(
      context: context,
      library: _library,
      business: _business,
      onCreated: _refresh,
    ),
    onRenameFolder: (name) => BusinessFolderActions.renameFolder(
      context: context,
      library: _library,
      business: _business,
      oldName: name,
      onRenamed: () => _folderChanged(name),
    ),
    onDeleteFolder: (name) => BusinessFolderActions.deleteFolder(
      context: context,
      library: _library,
      business: _business,
      folderName: name,
      onDeleted: () => _folderChanged(name),
    ),
    onImport: _importFile,
    onGenerate: _saveCatalog,
    onOpen: _open,
    onShare: _share,
    onRenameDocument: (doc) => BusinessDocumentActions.rename(
      context: context,
      library: _library,
      document: doc,
      onRenamed: _refresh,
    ),
    onDeleteDocument: (doc) => BusinessDocumentActions.delete(
      context: context,
      library: _library,
      document: doc,
      onDeleted: _refresh,
    ),
    onAddProduct: _addProduct,
    onEditProduct: _editProduct,
    onShareProduct: _shareProduct,
    onClose: () => Navigator.pop(context),
    onRetry: _refresh,
  );

  Future<void> _resetScope({bool recent = false}) async {
    setState(() {
      _category = BusinessDocumentLibrary.allCategory;
      _query = '';
      _fileType = 'all';
      if (recent) _sortBy = 'date';
    });
    await _refresh();
  }

  Future<void> _folderChanged(String name) async {
    if (_category == name) _category = BusinessDocumentLibrary.allCategory;
    await _refresh();
  }

  void _share(BusinessDocument doc) {
    if (widget.onSendToChat != null) {
      widget.onSendToChat!([doc]);
      Navigator.pop(context);
    } else {
      BusinessDocumentActions.share(context: context, documents: [doc]);
    }
  }
}
