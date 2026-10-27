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
          color: const Color(0xB2162535),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0x16FFFFFF)),
        ),
        child: compact ? _compactLayout() : _wideLayout(),
      );
    },
  );

  /// Dos filas dejan áreas táctiles completas sin abreviar etiquetas.
  Widget _compactLayout() => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        children: [
          _viewControls(),
          const SizedBox(width: 8),
          Expanded(child: _selectionButton()),
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
  Widget _wideLayout() => Row(
    children: [
      _viewControls(),
      const SizedBox(width: 8),
      Flexible(child: _selectionButton()),
      const Spacer(),
      SizedBox(
        width: 92,
        child: BusinessLibraryToolbarMenu(
          kind: BusinessLibraryMenuKind.sort,
          value: sortBy,
          onChanged: onSortChange,
        ),
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
  Widget _viewControls() => Container(
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: const Color(0x80101B28),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _viewButton(CupertinoIcons.list_bullet, !isGridView),
        _viewButton(CupertinoIcons.square_grid_2x2, isGridView),
      ],
    ),
  );

  Widget _viewButton(IconData icon, bool selected) => CupertinoButton(
    onPressed: selected ? null : onToggleGridView,
    minimumSize: const Size.square(32),
    padding: EdgeInsets.zero,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 34,
      height: 32,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF168BFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 16,
        color: selected ? Colors.white : const Color(0xFF8FA5BB),
      ),
    ),
  );

  /// Activa selección explícitamente; las filas no esconden selección implícita.
  Widget _selectionButton() => CupertinoButton(
    onPressed: onToggleSelectionMode,
    minimumSize: const Size.square(36),
    padding: EdgeInsets.zero,
    child: _labelSurface(
      isSelectionMode
          ? CupertinoIcons.check_mark_circled_solid
          : CupertinoIcons.check_mark_circled,
      isSelectionMode ? 'Cancelar selección' : 'Seleccionar archivos',
      active: isSelectionMode,
    ),
  );

  /// Superficie común mantiene tipografía, alineación y altura coherentes.
  Widget _labelSurface(IconData icon, String text, {bool active = false}) =>
      Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: active ? const Color(0x332C9CFF) : const Color(0x66101B28),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: active ? const Color(0xFF55B2FF) : const Color(0xFFA7B8CA),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active
                      ? const Color(0xFF72BEFF)
                      : const Color(0xFFC2CEDA),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}
