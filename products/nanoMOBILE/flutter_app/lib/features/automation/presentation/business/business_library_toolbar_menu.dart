import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
    return PopupMenuButton<String>(
      initialValue: value,
      onSelected: onChanged,
      color: const Color(0xFF172638),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => filtering ? _filterItems : _sortItems,
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
              color: active
                  ? const Color(0xFF55B2FF)
                  : const Color(0xFFA7B8CA),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                active ? 'Filtro activo' : filtering ? 'Filtrar' : 'Ordenar',
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

  static const _sortItems = <PopupMenuEntry<String>>[
    PopupMenuItem(value: 'date', child: Text('Más recientes')),
    PopupMenuItem(value: 'name', child: Text('Nombre (A-Z)')),
    PopupMenuItem(value: 'size', child: Text('Mayor tamaño')),
  ];

  static const _filterItems = <PopupMenuEntry<String>>[
    PopupMenuItem(value: 'all', child: Text('Todos los formatos')),
    PopupMenuItem(value: 'pdf', child: Text('PDF')),
    PopupMenuItem(value: 'sheet', child: Text('Hojas de cálculo')),
    PopupMenuItem(value: 'image', child: Text('Imágenes')),
    PopupMenuItem(value: 'video', child: Text('Videos')),
  ];
}
