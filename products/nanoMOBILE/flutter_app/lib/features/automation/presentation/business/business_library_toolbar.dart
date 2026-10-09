import 'package:flutter/material.dart';

/// Barra única para vista, selección, orden y formato de archivo.
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

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    margin: const EdgeInsets.fromLTRB(16, 5, 16, 4),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0x99162535),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: .08)),
    ),
    child: Row(
      children: [
        _viewButton(Icons.view_list_rounded, !isGridView),
        _viewButton(Icons.grid_view_rounded, isGridView),
        const VerticalDivider(
          width: 14,
          indent: 4,
          endIndent: 4,
          color: Color(0x334D6379),
        ),
        _action(
          isSelectionMode
              ? Icons.check_box_rounded
              : Icons.check_box_outline_blank_rounded,
          isSelectionMode ? 'Cancelar' : 'Seleccionar',
          onToggleSelectionMode,
          active: isSelectionMode,
        ),
        const Spacer(),
        PopupMenuButton<String>(
          initialValue: sortBy,
          onSelected: onSortChange,
          color: const Color(0xFF172638),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'date', child: Text('Más recientes')),
            PopupMenuItem(value: 'name', child: Text('Nombre (A-Z)')),
            PopupMenuItem(value: 'size', child: Text('Mayor tamaño')),
          ],
          child: _label(Icons.swap_vert_rounded, 'Ordenar', false),
        ),
        const SizedBox(width: 3),
        PopupMenuButton<String>(
          initialValue: fileType,
          onSelected: onFileTypeChange,
          color: const Color(0xFF172638),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'all', child: Text('Todos los formatos')),
            PopupMenuItem(value: 'pdf', child: Text('PDF')),
            PopupMenuItem(value: 'sheet', child: Text('Hojas de cálculo')),
            PopupMenuItem(value: 'image', child: Text('Imágenes')),
            PopupMenuItem(value: 'video', child: Text('Videos')),
          ],
          child: _label(
            Icons.filter_alt_outlined,
            'Filtrar',
            fileType != 'all',
          ),
        ),
      ],
    ),
  );

  Widget _viewButton(IconData icon, bool selected) => InkWell(
    onTap: selected ? null : onToggleGridView,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      width: 34,
      height: 32,
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF087BFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: const Color(0xFF087BFF).withValues(alpha: .28),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Icon(
        icon,
        size: 17,
        color: selected ? Colors.white : const Color(0xFF8FA5BB),
      ),
    ),
  );

  Widget _action(
    IconData icon,
    String text,
    VoidCallback tap, {
    bool active = false,
  }) => InkWell(
    onTap: tap,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: _label(icon, text, active),
    ),
  );

  Widget _label(IconData icon, String text, bool active) => SizedBox(
    height: 32,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: active ? const Color(0xFF40A9FF) : const Color(0xFFA7B8CA),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: active ? const Color(0xFF65B8FF) : const Color(0xFFB9C6D5),
            fontSize: 10,
          ),
        ),
        if (text == 'Ordenar' || text == 'Filtrar')
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 14,
            color: Color(0xFF7E94AA),
          ),
      ],
    ),
  );
}
