import 'package:flutter/cupertino.dart';
import '../../engine/business/business_document_library.dart';

/// Acciones de una fila: primarias visibles y secundarias agrupadas sin solapar.
class BusinessLibraryFileActions extends StatelessWidget {
  final BusinessDocument document;
  final ValueChanged<BusinessDocument> onOpen, onShare;
  final ValueChanged<BusinessDocument> onRename, onDelete;

  const BusinessLibraryFileActions({
    super.key,
    required this.document,
    required this.onOpen,
    required this.onShare,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _icon(
        CupertinoIcons.book,
        'Abrir',
        () => onOpen(document),
        color: const Color(0xFF168BFF),
      ),
      _icon(CupertinoIcons.share, 'Compartir', () => onShare(document)),
      CupertinoButton(
        onPressed: () => _showMore(context),
        minimumSize: const Size.square(44),
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: const Icon(
          CupertinoIcons.ellipsis,
          size: 18,
          color: Color(0xFFA7B8C9),
        ),
      ),
    ],
  );

  Widget _icon(
    IconData icon,
    String tooltip,
    VoidCallback tap, {
    Color color = const Color(0xFFA7B8C9),
  }) => Semantics(
    label: tooltip,
    button: true,
    child: CupertinoButton(
      onPressed: tap,
      minimumSize: const Size.square(44),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      child: Icon(icon, size: 17, color: color),
    ),
  );

  /// Renombrar y eliminar viven en una hoja iOS para no comprimir la fila.
  Future<void> _showMore(BuildContext context) async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(document.name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext, 'rename'),
            child: const Text('Renombrar'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext, 'delete'),
            isDestructiveAction: true,
            child: const Text('Eliminar'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (action == 'rename') onRename(document);
    if (action == 'delete') onDelete(document);
  }
}
