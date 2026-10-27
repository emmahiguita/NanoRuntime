import 'package:flutter/cupertino.dart';
import 'business_library_style.dart';
import 'business_library_action_menu.dart';

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
    child: Icon(CupertinoIcons.ellipsis, size: 17, color: context.libraryColors.onSurfaceVariant),
  );

  /// El menú flotante conserva las claves y callbacks de las acciones reales.
  Future<void> _showActions(BuildContext context) async {
    final action = await showBusinessLibraryMenu(
      context,
      title: folderName,
      options: const [
        BusinessLibraryOption('open', 'Abrir'),
        BusinessLibraryOption('rename', 'Renombrar'),
        BusinessLibraryOption('delete', 'Eliminar', destructive: true),
      ],
    );
    if (!context.mounted) return;
    if (action == 'open') onOpen(folderName);
    if (action == 'rename') onRename(folderName);
    if (action == 'delete') onDelete(folderName);
  }
}
