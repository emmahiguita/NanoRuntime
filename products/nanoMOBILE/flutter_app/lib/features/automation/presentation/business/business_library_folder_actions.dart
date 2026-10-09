import 'package:flutter/cupertino.dart';

/// Menú iOS de una carpeta; cada opción delega en la lógica real recibida.
class BusinessLibraryFolderActions extends StatelessWidget {
  final String folderName;
  final ValueChanged<String> onOpen, onRename, onDelete;

  const BusinessLibraryFolderActions({
    super.key,
    required this.folderName,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) => CupertinoButton(
    onPressed: () => _showActions(context),
    minimumSize: const Size.square(32),
    padding: EdgeInsets.zero,
    child: const Icon(
      CupertinoIcons.ellipsis,
      size: 17,
      color: Color(0xFF9DAFC0),
    ),
  );

  /// La hoja inferior evita menús pequeños y conserva áreas táctiles de iOS.
  Future<void> _showActions(BuildContext context) async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(folderName),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext, 'open'),
            child: const Text('Abrir'),
          ),
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
    if (action == 'open') onOpen(folderName);
    if (action == 'rename') onRename(folderName);
    if (action == 'delete') onDelete(folderName);
  }
}
