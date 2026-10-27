import 'package:flutter/cupertino.dart';

/// Acciones secundarias del pie agrupadas en una hoja nativa de estilo iOS.
class BusinessLibraryBottomActions extends StatelessWidget {
  final bool allSelected, canGenerate;
  final VoidCallback onSelectAll, onGenerate;

  const BusinessLibraryBottomActions({
    super.key,
    required this.allSelected,
    required this.canGenerate,
    required this.onSelectAll,
    required this.onGenerate,
  });

  @override
  Widget build(BuildContext context) => CupertinoButton(
    onPressed: () => _show(context),
    minimumSize: const Size.square(44),
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: const Icon(
      CupertinoIcons.ellipsis,
      size: 19,
      color: Color(0xFFA8B9CA),
    ),
  );

  /// Ejecuta solamente la acción elegida; cancelar no modifica la selección.
  Future<void> _show(BuildContext context) async {
    final action = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(sheetContext, 'all'),
            child: Text(
              allSelected ? 'Deseleccionar todo' : 'Seleccionar todo',
            ),
          ),
          if (canGenerate)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(sheetContext, 'catalog'),
              child: const Text('Crear catálogo PDF'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (action == 'all') onSelectAll();
    if (action == 'catalog') onGenerate();
  }
}
