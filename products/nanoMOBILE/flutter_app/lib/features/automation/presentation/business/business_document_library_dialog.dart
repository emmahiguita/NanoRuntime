// business_document_library_dialog.dart
//
// QUÉ HACE:
// Controlador modal principal de la biblioteca comercial de Nano:
// gestiona estados reactivos de carga, búsqueda, carpetas, ordenamiento e importación.
//
// CÓMO FUNCIONA:
// - Despliega un modal bottom sheet con BackdropFilter blur al estilo iOS Liquid Glass.
// - Conecta BusinessDocumentLibrary con las acciones de archivos y carpetas.
// - Notifica al chat cuando se utiliza en modo selector de adjuntos comerciales.
//
// POR QUÉ:
// Aplica Clean Architecture separando el control de flujo de la vista de renderizado (< 180 líneas).

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../engine/business/business_document_library.dart';
import '../../engine/business/business_facts.dart';
import '../../engine/business/catalog_pdf_generator.dart';
import 'business_document_actions.dart';
import 'business_folder_actions.dart';
import '../widgets/conversation_pdf_viewer.dart';
import 'business_document_library_view.dart';

part 'business_document_library_dialog_view.part.dart';
part 'business_document_library_dialog_actions.part.dart';

final class BusinessDocumentLibraryDialog extends StatefulWidget {
  final BusinessFacts facts;
  final ValueChanged<List<BusinessDocument>>? onSendToChat;

  const BusinessDocumentLibraryDialog({
    super.key,
    required this.facts,
    this.onSendToChat,
  });

  static Future<void> show(
    BuildContext context,
    BusinessFacts facts, {
    ValueChanged<List<BusinessDocument>>? onSendToChat,
  }) => showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(8),
      child: FractionallySizedBox(
        heightFactor: .96,
        child: BusinessDocumentLibraryDialog(
          facts: facts,
          onSendToChat: onSendToChat,
        ),
      ),
    ),
  );

  @override
  State<BusinessDocumentLibraryDialog> createState() =>
      _BusinessDocumentLibraryDialogState();
}

final class _BusinessDocumentLibraryDialogState
    extends State<BusinessDocumentLibraryDialog> {
  final _library = const BusinessDocumentLibrary();
  String _category = BusinessDocumentLibrary.allCategory,
      _sortBy = 'date',
      _query = '';
  String _fileType = 'all';
  List<BusinessFolderInfo> _folders = const [];
  List<BusinessDocument> _documents = const [];
  List<BusinessDocument> _allDocuments = const [];
  final Set<String> _selectedPaths = {};
  bool _isSelectionMode = false, _isGridView = false, _busy = false;
  String? _loadError;
  int _loadRevision = 0;

  String get _business => widget.facts.businessName.trim().isEmpty
      ? 'Servicios Tecnológicos de DevEmmai'
      : widget.facts.businessName.trim();
  int get _totalSize =>
      _allDocuments.fold<int>(0, (sum, d) => sum + d.sizeBytes);

  List<BusinessDocument> get _visibleDocuments {
    var list = _documents.where((d) {
      final q = _query.toLowerCase().trim();
      final matchesQuery =
          q.isEmpty ||
          d.name.toLowerCase().contains(q) ||
          d.category.toLowerCase().contains(q);
      final matchesType = switch (_fileType) {
        'pdf' => d.isPdf,
        'sheet' => d.isSheet,
        'image' => d.isImage,
        'video' => d.isVideo,
        _ => true,
      };
      return matchesQuery && matchesType;
    }).toList();
    switch (_sortBy) {
      case 'name':
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
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
    _refresh();
  }

  Future<void> _refresh() async {
    final rev = ++_loadRevision;
    try {
      final f = await _library.listFolders(_business);
      final d = await _library.list(_business, _category);
      final all = _category == BusinessDocumentLibrary.allCategory
          ? d
          : await _library.list(_business, BusinessDocumentLibrary.allCategory);
      if (mounted && rev == _loadRevision) {
        setState(() {
          _folders = f;
          _documents = d;
          _allDocuments = all;
          _loadError = null;
        });
      }
    } catch (e) {
      if (mounted && rev == _loadRevision) {
        setState(() => _loadError = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) => _buildLibrary(context);
}
