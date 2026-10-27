import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'business_library_action_menu.dart';

enum BusinessLibraryMenuKind { sort, filter }

/// Menú iOS reutilizable de orden o formato; conserva una sola altura visual.
class BusinessLibraryToolbarMenu extends StatelessWidget {
  final BusinessLibraryMenuKind kind;
  final String value;
  final ValueChanged<String> onChanged;

  const BusinessLibraryToolbarMenu({super.key, required this.kind, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final filtering = kind == BusinessLibraryMenuKind.filter;
    final active = filtering && value != 'all';
    return CupertinoButton(
      onPressed: () => _showOptions(context),
      minimumSize: const Size.square(36),
      padding: EdgeInsets.zero,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: active ? colors.primaryContainer.withValues(alpha: .5) : colors.surface.withValues(alpha: .30),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              filtering ? CupertinoIcons.slider_horizontal_3 : CupertinoIcons.arrow_up_arrow_down,
              size: 15,
              color: active ? colors.onPrimaryContainer : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                active
                    ? 'Filtro activo'
                    : filtering
                    ? 'Filtrar'
                    : 'Ordenar',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? colors.onPrimaryContainer : colors.onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 3),
            Icon(CupertinoIcons.chevron_down, size: 10, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  /// Presenta opciones amplias y marca la selección actual sin menú Material.
  Future<void> _showOptions(BuildContext context) async {
    final filtering = kind == BusinessLibraryMenuKind.filter;
    final options = filtering ? _filterOptions : _sortOptions;
    final selected = await showBusinessLibraryMenu(
      context,
      title: filtering ? 'Filtrar por formato' : 'Ordenar archivos',
      selectedValue: value,
      options: [for (final option in options.entries) BusinessLibraryOption(option.key, option.value)],
    );
    if (!context.mounted) return;
    if (selected != null && selected != value) onChanged(selected);
  }

  static const _sortOptions = {'date': 'Más recientes', 'name': 'Nombre (A-Z)', 'size': 'Mayor tamaño'};
  static const _filterOptions = {
    'all': 'Todos los formatos',
    'pdf': 'PDF',
    'sheet': 'Hojas de cálculo',
    'image': 'Imágenes',
    'video': 'Videos',
  };
}
