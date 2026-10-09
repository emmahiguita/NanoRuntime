// business_document_library_dialog_actions.part.dart
//
// QUÉ HACE:
// Acciones operativas del diálogo de biblioteca: abrir, importar, compartir, generar PDF
// y gestionar productos de la tienda integrada (crear, editar, compartir foto y ficha).
//
// CÓMO FUNCIONA:
// - Persiste transaccionalmente las modificaciones de productos en SQLite vía `BusinessFactsStore`.
// - Despacha la foto real y la ficha enriquecida hacia WhatsApp, Telegram o el chat de Nano.
//
// POR QUÉ:
// Aplica el principio de responsabilidad única dividiendo la lógica de acciones en < 160 líneas.

part of 'business_document_library_dialog.dart';

extension _BusinessDocumentLibraryDialogActions
    on _BusinessDocumentLibraryDialogState {
  Future<void> _open(BusinessDocument document) async {
    if (widget.onSendToChat != null && _isSelectionMode) {
      _toggleSelection(document);
      return;
    }
    if (document.isPdf) {
      await ConversationPdfViewer.show(
        context,
        pathOrUrl: document.file.path,
        title: document.name,
      );
      return;
    }
    await BusinessDocumentActions.share(
      context: context,
      documents: [document],
    );
  }

  Future<void> _saveCatalog() async {
    if (_facts.products.isEmpty) return;
    setState(() => _busy = true);
    try {
      final bytes = await CatalogPdfGenerator.generatePdfBytes(
        facts: _facts,
        businessName: _business,
      );
      await _library.saveBytes(
        bytes,
        _business,
        _library.destinationCategory(_category),
        'catalogo_comercial',
      );
      await _refresh();
    } on Object {
      if (mounted) _msg('No se pudo guardar el catálogo');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFile() async {
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      for (final file in picked.files) {
        if (file.path != null) {
          await _library.importFile(
            file.path!,
            _business,
            _library.destinationCategory(_category),
          );
        }
      }
      await _refresh();
    } on Object {
      if (mounted) _msg('No se pudo importar el archivo');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleSelection(BusinessDocument document) => setState(() {
    if (!_selectedPaths.add(document.file.path)) {
      _selectedPaths.remove(document.file.path);
    }
  });

  Future<void> _sendSelected() async {
    final targets = _documents
        .where((doc) => _selectedPaths.contains(doc.file.path))
        .toList();
    if (targets.isEmpty) {
      _msg('Selecciona al menos un archivo para enviar');
      return;
    }
    if (widget.onSendToChat != null) {
      widget.onSendToChat!(targets);
      Navigator.pop(context);
      return;
    }
    await BusinessDocumentActions.share(context: context, documents: targets);
  }

  Future<void> _addProduct() async {
    final newProduct = await showDialog<BusinessProduct>(
      context: context,
      useRootNavigator: true,
      builder: (_) => const ProductDialog(),
    );
    if (newProduct == null || !mounted) return;
    final updatedList = [..._facts.products, newProduct];
    final updatedFacts = _facts.copyWith(products: updatedList);
    await _factsStore.save(updatedFacts);
    setState(() => _facts = updatedFacts);
    _msg('Producto agregado al catálogo');
  }

  Future<void> _editProduct(BusinessProduct product) async {
    final updated = await showDialog<BusinessProduct>(
      context: context,
      useRootNavigator: true,
      builder: (_) => ProductDialog(initial: product),
    );
    if (updated == null || !mounted) return;
    final updatedList = [
      for (final p in _facts.products)
        if (p.id == updated.id) updated else p,
    ];
    final updatedFacts = _facts.copyWith(products: updatedList);
    await _factsStore.save(updatedFacts);
    setState(() => _facts = updatedFacts);
    _msg('Producto actualizado');
  }

  Future<void> _shareProduct(BusinessProduct product) async {
    await BusinessStoreProductActions.shareProduct(
      context: context,
      product: product,
    );
  }

  void _msg(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );
}
