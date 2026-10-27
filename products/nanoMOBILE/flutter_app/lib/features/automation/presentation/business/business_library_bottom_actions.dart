import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'business_library_action_menu.dart';

/// Acciones secundarias del pie en un menú flotante con el cristal compartido.
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
    child: Icon(CupertinoIcons.ellipsis, size: 19, color: Theme.of(context).colorScheme.onSurfaceVariant),
  );

  /// Ejecuta solamente la acción elegida; cancelar no modifica la selección.
  Future<void> _show(BuildContext context) async {
    final action = await showBusinessLibraryMenu(
      context,
      title: 'Acciones de archivos',
      options: [
        BusinessLibraryOption('all', allSelected ? 'Deseleccionar todo' : 'Seleccionar todo'),
        if (canGenerate) const BusinessLibraryOption('catalog', 'Crear catálogo PDF'),
      ],
    );
    if (!context.mounted) return;
    if (action == 'all') onSelectAll();
    if (action == 'catalog') onGenerate();
  }
}
