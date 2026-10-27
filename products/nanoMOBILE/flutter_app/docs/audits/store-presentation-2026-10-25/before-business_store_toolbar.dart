import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../business_library_search_bar.dart';
import '../business_library_action_menu.dart';

/// Controles de tienda con el tema heredado. Reutiliza el buscador sincronizado
/// de Biblioteca: borrar la consulta limpia tanto el campo como el filtro real.
class BusinessStoreToolbar extends StatelessWidget {
  const BusinessStoreToolbar({
    super.key,
    required this.query,
    required this.sortBy,
    required this.isGridView,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.onToggleView,
    required this.onAddProduct,
  });
  final String query, sortBy;
  final bool isGridView;
  final ValueChanged<String> onQueryChanged, onSortChanged;
  final VoidCallback onToggleView, onAddProduct;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BusinessLibrarySearchBar(
            query: query,
            isDark: Theme.of(context).brightness == Brightness.dark,
            onQuery: onQueryChanged,
            padding: EdgeInsets.zero,
            placeholder: 'Buscar producto, categoría o SKU',
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _SortMenuButton(sortBy: sortBy, onSortChanged: onSortChanged),
              TextButton.icon(
                onPressed: onToggleView,
                icon: Icon(
                  isGridView ? CupertinoIcons.list_bullet : CupertinoIcons.square_grid_2x2,
                  size: 16,
                ),
                label: Text(isGridView ? 'Lista' : 'Cuadrícula'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.onSurface,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
              FilledButton.icon(
                onPressed: onAddProduct,
                icon: const Icon(CupertinoIcons.plus, size: 15),
                label: const Text('Producto'),
                style: FilledButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Devuelve el criterio elegido; cancelar no cambia el orden actual.
class _SortMenuButton extends StatelessWidget {
  const _SortMenuButton({required this.sortBy, required this.onSortChanged});
  final String sortBy;
  final ValueChanged<String> onSortChanged;
  static const _labels = {
    'name': 'Nombre',
    'price_asc': 'Menor precio',
    'price_desc': 'Mayor precio',
    'stock': 'Mayor stock',
  };

  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: const Icon(CupertinoIcons.arrow_up_arrow_down, size: 15),
    label: Text(_labels[sortBy] ?? 'Ordenar'),
    style: TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      textStyle: const TextStyle(fontSize: 12),
    ),
    onPressed: () async {
      final value = await showBusinessLibraryMenu(
        context,
        title: 'Ordenar productos',
        selectedValue: sortBy,
        options: [for (final item in _labels.entries) BusinessLibraryOption(item.key, item.value)],
      );
      if (!context.mounted) return;
      if (value != null && value != sortBy) onSortChanged(value);
    },
  );
}
