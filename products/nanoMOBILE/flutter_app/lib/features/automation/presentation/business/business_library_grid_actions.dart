import 'package:flutter/cupertino.dart';
import '../../engine/business/business_document_library.dart';

/// Menú compacto de la cuadrícula con acciones reales en una hoja iOS.
class BusinessLibraryGridActions extends StatelessWidget {
  final BusinessDocument document;
  final ValueChanged<BusinessDocument> onOpen, onShare, onRename, onDelete;

  const BusinessLibraryGridActions({
    super.key,
    required this.document,
    required this.onOpen,
    required this.onShare,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => CupertinoButton(
    onPressed: () => _show(context),
    minimumSize: const Size.square(32),
    padding: EdgeInsets.zero,
    child: const Icon(
      CupertinoIcons.ellipsis,
      size: 17,
      color: Color(0xFF9DAFC0),
    ),
  );

  /// Devuelve una clave y llama una sola función para evitar acciones dobles.
  Future<void> _show(BuildContext context) async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(document.name),
        actions: [
          _action(sheetContext, 'open', 'Abrir'),
          _action(sheetContext, 'share', 'Compartir'),
          _action(sheetContext, 'rename', 'Renombrar'),
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
    if (action == 'open') onOpen(document);
    if (action == 'share') onShare(document);
    if (action == 'rename') onRename(document);
    if (action == 'delete') onDelete(document);
  }

  CupertinoActionSheetAction _action(
    BuildContext context,
    String value,
    String label,
  ) => CupertinoActionSheetAction(
    onPressed: () => Navigator.pop(context, value),
    child: Text(label),
  );
}
