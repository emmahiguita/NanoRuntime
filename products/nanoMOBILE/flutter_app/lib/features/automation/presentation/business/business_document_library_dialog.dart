// QUÉ HACE: permite guardar, importar, organizar y compartir PDFs desde Nano.
// CÓMO: usa el almacenamiento persistente de la app y el selector oficial de Android.
// POR QUÉ: WhatsApp debe recibir el archivo real y dejar que el usuario elija contacto.
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../engine/business/business_document_library.dart';
import '../../engine/business/business_facts.dart';
import '../../engine/business/catalog_pdf_generator.dart';
import 'business_document_actions.dart';
import '../widgets/conversation_pdf_viewer.dart';
import 'business_document_library_view.dart';

/// Diálogo de biblioteca comercial que conserva los datos del negocio existentes.
final class BusinessDocumentLibraryDialog extends StatefulWidget {
  const BusinessDocumentLibraryDialog({super.key, required this.facts});
  final BusinessFacts facts;

  /// Abre la biblioteca desde el catálogo de automatización.
  static Future<void> show(BuildContext context, BusinessFacts facts) =>
      showModalBottomSheet(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FractionallySizedBox(
          heightFactor: .96,
          child: BusinessDocumentLibraryDialog(facts: facts),
        ),
      );

  @override
  State<BusinessDocumentLibraryDialog> createState() =>
      _BusinessDocumentLibraryDialogState();
}

/// Mantiene selección de categoría y refresca la lista tras cada operación.
final class _BusinessDocumentLibraryDialogState
    extends State<BusinessDocumentLibraryDialog> {
  final _library = const BusinessDocumentLibrary();
  String _category = BusinessDocumentLibrary.allCategory;
  List<BusinessDocument> _documents = const [];
  bool _busy = false;
  String _query = '';
  String? _loadError;
  int _loadRevision = 0;

  String get _business => widget.facts.businessName.trim().isEmpty
      ? 'Servicios Tecnológicos de DevEmmai'
      : widget.facts.businessName.trim();

  // Filtra en memoria; escribir en el buscador no vuelve a consultar el disco.
  List<BusinessDocument> get _visibleDocuments => _documents
      .where(
        (document) =>
            document.name.toLowerCase().contains(_query.toLowerCase().trim()),
      )
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// Recarga solo la categoría visible para evitar trabajo de disco innecesario.
  Future<void> _refresh() async {
    final revision = ++_loadRevision;
    try {
      final files = await _library.list(_business, _category);
      if (mounted && revision == _loadRevision) {
        setState(() {
          _documents = files;
          _loadError = null;
        });
      }
    } on Object catch (error) {
      if (mounted && revision == _loadRevision) {
        setState(() => _loadError = error.toString());
      }
    }
  }

  // Abre el visor PDF integrado de Nano con el archivo persistente seleccionado.
  Future<void> _open(BusinessDocument d) => ConversationPdfViewer.show(
    context,
    pathOrUrl: d.file.path,
    title: d.name,
  );

  /// Guarda el PDF con productos/precios reales que ya están en el catálogo.
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
    } on Object catch (error) {
      if (mounted) _showError('No se pudo guardar el catálogo: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Copia un PDF elegido del teléfono para que Nano lo mantenga disponible.
  Future<void> _importPdf() async {
    setState(() => _busy = true);
    try {
      // El selector puede cancelarse; aun así el bloque finally libera el estado.
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      final path = picked?.files.single.path;
      if (path == null) return;
      await _library.importPdf(
        path,
        _business,
        _library.destinationCategory(_category),
      );
      await _refresh();
    } on Object catch (error) {
      if (mounted) _showError('No se pudo importar el PDF: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Expone fallos reales del sistema para que el usuario pueda decidir qué hacer.
  void _showError(String message) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );

  /// Entrega el estado y las acciones a una vista de biblioteca separada.
  @override
  Widget build(BuildContext context) => BusinessDocumentLibraryView(
    title: _business,
    category: _category,
    query: _query,
    documents: _visibleDocuments,
    loadError: _loadError,
    busy: _busy,
    canGenerate: widget.facts.products.isNotEmpty,
    onCategory: (value) async {
      setState(() => _category = value);
      await _refresh();
    },
    onQuery: (value) => setState(() => _query = value),
    onImport: _importPdf,
    onGenerate: _saveCatalog,
    onOpen: _open,
    onShare: (document) =>
        BusinessDocumentActions.share(context: context, document: document),
    onDelete: (document) => BusinessDocumentActions.delete(
      context: context,
      library: _library,
      document: document,
      onDeleted: _refresh,
    ),
    onClose: () => Navigator.pop(context),
    onRetry: _refresh,
  );
}
