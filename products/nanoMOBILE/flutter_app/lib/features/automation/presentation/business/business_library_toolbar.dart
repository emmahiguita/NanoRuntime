// Barra de herramientas iOS adaptable: nunca fuerza todas las acciones en una fila.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'business_library_toolbar_menu.dart';

class BusinessLibraryToolbar extends StatelessWidget {
  final bool isDark, isGridView, isSelectionMode;
  final String sortBy, fileType;
  final VoidCallback onToggleGridView, onToggleSelectionMode;
  final ValueChanged<String> onSortChange, onFileTypeChange;

  const BusinessLibraryToolbar({
    super.key,
    required this.isDark,
    required this.isGridView,
    required this.isSelectionMode,
    required this.sortBy,
    required this.fileType,
    required this.onToggleGridView,
    required this.onToggleSelectionMode,
    required this.onSortChange,
    required this.onFileTypeChange,
  });

  /// En móvil apila selección y filtros; en ancho grande conserva una fila.
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 430;
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: isDark ? .25 : .35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: compact ? _compactLayout(context) : _wideLayout(context),
      );
    },
  );

  /// Dos filas dejan áreas táctiles completas sin abreviar etiquetas.
  Widget _compactLayout(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          _viewControls(context),
          const SizedBox(width: 8),
          Expanded(child: _selectionButton(context)),
        ],
      ),
      const SizedBox(height: 5),
      Row(
        children: [
          Expanded(
            child: BusinessLibraryToolbarMenu(
              kind: BusinessLibraryMenuKind.sort,
              value: sortBy,
              onChanged: onSortChange,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: BusinessLibraryToolbarMenu(
              kind: BusinessLibraryMenuKind.filter,
              value: fileType,
              onChanged: onFileTypeChange,
            ),
          ),
        ],
      ),
    ],
  );

  /// Una sola fila se reserva para tablets y orientación horizontal holgada.
  Widget _wideLayout(BuildContext context) => Row(
    children: [
      _viewControls(context),
      const SizedBox(width: 8),
      Flexible(child: _selectionButton(context)),
      const Spacer(),
      SizedBox(
        width: 92,
        child: BusinessLibraryToolbarMenu(kind: BusinessLibraryMenuKind.sort, value: sortBy, onChanged: onSortChange),
      ),
      const SizedBox(width: 6),
      SizedBox(
        width: 86,
        child: BusinessLibraryToolbarMenu(
          kind: BusinessLibraryMenuKind.filter,
          value: fileType,
          onChanged: onFileTypeChange,
        ),
      ),
    ],
  );

  /// Selector visual lista/cuadrícula con apariencia de segmented control.
  Widget _viewControls(BuildContext context) => Container(
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _viewButton(context, CupertinoIcons.list_bullet, !isGridView),
        _viewButton(context, CupertinoIcons.square_grid_2x2, isGridView),
      ],
    ),
  );

  Widget _viewButton(BuildContext context, IconData icon, bool selected) => CupertinoButton(
    onPressed: selected ? null : onToggleGridView,
    minimumSize: const Size.square(32),
    padding: EdgeInsets.zero,
    child: AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 160),
      width: 34,
      height: 32,
      decoration: BoxDecoration(
        color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 16,
        color: selected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );

  /// Activa selección explícitamente; las filas no esconden selección implícita.
  Widget _selectionButton(BuildContext context) => CupertinoButton(
    onPressed: onToggleSelectionMode,
    minimumSize: const Size.square(36),
    padding: EdgeInsets.zero,
    child: _labelSurface(
      context,
      isSelectionMode ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.check_mark_circled,
      isSelectionMode ? 'Cancelar selección' : 'Seleccionar archivos',
      active: isSelectionMode,
    ),
  );

  /// Superficie común mantiene tipografía, alineación y altura coherentes.
  Widget _labelSurface(BuildContext context, IconData icon, String text, {bool active = false}) => Container(
    height: 36,
    padding: const EdgeInsets.symmetric(horizontal: 9),
    decoration: BoxDecoration(
      color: active ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .5) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 15,
          color: active
              ? Theme.of(context).colorScheme.onPrimaryContainer
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active
                  ? Theme.of(context).colorScheme.onPrimaryContainer
                  : Theme.of(context).colorScheme.onSurface,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
