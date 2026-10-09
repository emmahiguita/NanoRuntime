import 'package:flutter/cupertino.dart';

enum BusinessLibraryMenuKind { sort, filter }

/// Menú iOS reutilizable de orden o formato; conserva una sola altura visual.
class BusinessLibraryToolbarMenu extends StatelessWidget {
  final BusinessLibraryMenuKind kind;
  final String value;
  final ValueChanged<String> onChanged;

  const BusinessLibraryToolbarMenu({
    super.key,
    required this.kind,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
          color: active ? const Color(0x332C9CFF) : const Color(0x66101B28),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              filtering
                  ? CupertinoIcons.slider_horizontal_3
                  : CupertinoIcons.arrow_up_arrow_down,
              size: 15,
              color: active ? const Color(0xFF55B2FF) : const Color(0xFFA7B8CA),
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
                  color: active
                      ? const Color(0xFF72BEFF)
                      : const Color(0xFFC2CEDA),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              CupertinoIcons.chevron_down,
              size: 10,
              color: Color(0xFF7E94AA),
            ),
          ],
        ),
      ),
    );
  }

  /// Presenta opciones amplias y marca la selección actual sin menú Material.
  Future<void> _showOptions(BuildContext context) async {
    final filtering = kind == BusinessLibraryMenuKind.filter;
    final options = filtering ? _filterOptions : _sortOptions;
    final selected = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(filtering ? 'Filtrar por formato' : 'Ordenar archivos'),
        actions: [
          for (final option in options.entries)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.pop(sheetContext, option.key),
              isDefaultAction: value == option.key,
              child: Text(option.value),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(sheetContext),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (selected != null && selected != value) onChanged(selected);
  }

  static const _sortOptions = {
    'date': 'Más recientes',
    'name': 'Nombre (A-Z)',
    'size': 'Mayor tamaño',
  };
  static const _filterOptions = {
    'all': 'Todos los formatos',
    'pdf': 'PDF',
    'sheet': 'Hojas de cálculo',
    'image': 'Imágenes',
    'video': 'Videos',
  };
}
