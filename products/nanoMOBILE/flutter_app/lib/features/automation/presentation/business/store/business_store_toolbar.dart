// business_store_toolbar.dart
//
// QUÉ HACE:
// Barra de herramientas compacta de la tienda: buscador horizontal y controles en fila única.
//
// CÓMO FUNCIONA:
// - Buscador de 44 dp con fondo neutro y botón de limpiar integrado.
// - Fila compacta de ordenamiento (Nombre, Precio, Stock) y alternancia Lista/Cuadrícula.
// - Elimina el botón redundante de 'Añadir producto' que ahora reside en el encabezado.
//
// POR QUÉ:
// Optimiza el espacio vertical y evita el desbordamiento de botones (< 120 líneas).

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../business_library_search_bar.dart';
import '../business_library_action_menu.dart';

class BusinessStoreToolbar extends StatelessWidget {
  const BusinessStoreToolbar({
    super.key,
    required this.query,
    required this.sortBy,
    required this.isGridView,
    required this.onQueryChanged,
    required this.onSortChanged,
    required this.onToggleView,
    this.onAddProduct,
  });

  final String query, sortBy;
  final bool isGridView;
  final ValueChanged<String> onQueryChanged, onSortChanged;
  final VoidCallback onToggleView;
  final VoidCallback? onAddProduct;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SortMenuButton(sortBy: sortBy, onSortChanged: onSortChanged),
              _ViewToggleButton(
                isGridView: isGridView,
                onToggle: onToggleView,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ViewToggleButton extends StatelessWidget {
  const _ViewToggleButton({required this.isGridView, required this.onToggle});
  final bool isGridView;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoButton(
      onPressed: onToggle,
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 32),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: isDark ? 0.35 : 0.20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isGridView ? CupertinoIcons.list_bullet : CupertinoIcons.square_grid_2x2,
              size: 14,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              isGridView ? 'Lista' : 'Cuadrícula',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 32),
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
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: isDark ? 0.35 : 0.20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.arrow_up_arrow_down, size: 13, color: colors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              _labels[sortBy] ?? 'Ordenar',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
