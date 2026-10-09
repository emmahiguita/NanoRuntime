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
    if (widget.facts.products.isEmpty) return;
    setState(() => _busy = true);
    try {
      final bytes = await CatalogPdfGenerator.generatePdfBytes(
        facts: widget.facts,
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

  void _msg(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );
}
