// business_document_library_dialog.dart
//
// QUÉ HACE:
// Controlador modal principal de la biblioteca comercial de Nano:
// gestiona estados reactivos de carga, búsqueda, carpetas, ordenamiento, importación y tienda multimedia.
//
// CÓMO FUNCIONA:
// - Abre una ventana flotante con una única superficie GlassSurface.
// - Conecta BusinessDocumentLibrary con las acciones de archivos, carpetas y catálogo de tienda.
// - Mantiene sincronizados los productos reales con el contexto del agente.
//
// POR QUÉ:
// Aplica Clean Architecture separando el control de flujo de la vista de renderizado (< 180 líneas).

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../engine/business/business_document_library.dart';
import '../../engine/business/business_facts.dart';
import '../../engine/business/business_facts_providers.dart';
import '../../engine/business/catalog_pdf_generator.dart';
import '../../engine/business/proposals/pdf_product_extractor.dart';
import '../../engine/business/proposals/pdf_text_extraction_service.dart';
import '../widgets/dialogs/product_dialog.dart';
import 'business_document_actions.dart';
import 'business_folder_actions.dart';
import 'business_library_section_tabs.dart';
import 'store/business_store_product_actions.dart';
import '../widgets/conversation_pdf_viewer.dart';
import 'business_document_library_view.dart';
import 'proposals/pdf_product_review_dialog.dart';
import 'package:nanoai/core/widgets/nano_glass_window.dart';

part 'business_document_library_dialog_view.part.dart';
part 'business_document_library_dialog_actions.part.dart';

final class BusinessDocumentLibraryDialog extends ConsumerStatefulWidget {
  final BusinessFacts facts;
  final BusinessLibrarySection initialSection;
  final ValueChanged<List<BusinessDocument>>? onSendToChat;

  const BusinessDocumentLibraryDialog({
    super.key,
    required this.facts,
    this.initialSection = BusinessLibrarySection.documents,
    this.onSendToChat,
  });

  static Future<void> show(
    BuildContext context,
    BusinessFacts facts, {
    BusinessLibrarySection initialSection = BusinessLibrarySection.documents,
    ValueChanged<List<BusinessDocument>>? onSendToChat,
  }) => showNanoGlassWindow(
    context: context,
    useRootNavigator: true,
    chrome: NanoWindowChrome.contentOwned,

    builder: (context) => SizedBox(
      height: MediaQuery.sizeOf(context).height * .96,
      child: BusinessDocumentLibraryDialog(facts: facts, initialSection: initialSection, onSendToChat: onSendToChat),
    ),
  );

  @override
  ConsumerState<BusinessDocumentLibraryDialog> createState() => _BusinessDocumentLibraryDialogState();
}

final class _BusinessDocumentLibraryDialogState extends ConsumerState<BusinessDocumentLibraryDialog> {
  final _library = const BusinessDocumentLibrary();
  static const _pdfText = PdfTextExtractionService();
  static const _pdfProducts = PdfProductExtractor();
  late BusinessFacts _facts;
  late String _storageBusiness;
  BusinessLibrarySection _section = BusinessLibrarySection.documents;
  String _category = BusinessDocumentLibrary.allCategory, _sortBy = 'date', _query = '';
  String _fileType = 'all';
  List<BusinessFolderInfo> _folders = const [];
  List<BusinessDocument> _documents = const [];
  List<BusinessDocument> _allDocuments = const [];
  final Set<String> _selectedPaths = {};
  bool _isSelectionMode = false, _isGridView = false, _busy = false;
  String? _loadError;
  int _loadRevision = 0;

  String get _business =>
      _facts.businessName.trim().isEmpty ? 'Servicios Tecnológicos de DevEmmai' : _facts.businessName.trim();
  int get _totalSize => _allDocuments.fold<int>(0, (sum, d) => sum + d.sizeBytes);

  List<BusinessDocument> get _visibleDocuments {
    var list = _documents.where((d) {
      final q = _query.toLowerCase().trim();
      final mQ = q.isEmpty || d.name.toLowerCase().contains(q) || d.category.toLowerCase().contains(q);
      final mT = switch (_fileType) {
        'pdf' => d.isPdf,
        'sheet' => d.isSheet,
        'image' => d.isImage,
        'video' => d.isVideo,
        _ => true,
      };
      return mQ && mT;
    }).toList();
    switch (_sortBy) {
      case 'name':
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      case 'size':
        list.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
        break;
      case 'date':
      default:
        list.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
        break;
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    _facts = widget.facts;
    _section = widget.initialSection;
    _storageBusiness = _business;
    _refresh();
  }

  Future<void> _refresh() async {
    final rev = ++_loadRevision;
    try {
      final storageBusiness = await _library.resolveStorageBusiness(_business);
      final f = await _library.listFolders(storageBusiness);
      final d = await _library.list(storageBusiness, _category);
      final all = _category == BusinessDocumentLibrary.allCategory
          ? d
          : await _library.list(storageBusiness, BusinessDocumentLibrary.allCategory);
      if (mounted && rev == _loadRevision) {
        setState(() {
          _storageBusiness = storageBusiness;
          _folders = f;
          _documents = d;
          _allDocuments = all;
          _loadError = null;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('BusinessDocumentLibrary: no se pudo cargar: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted && rev == _loadRevision) {
        setState(() => _loadError = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<BusinessFacts>(businessFactsNotifierProvider, (previous, next) {
      final businessChanged = previous?.businessName != next.businessName;
      if (!mounted) return;
      setState(() => _facts = next);
      if (businessChanged) _refresh();
    });
    return _buildLibrary(context);
  }
}
