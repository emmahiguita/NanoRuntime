// business_store_toolbar.dart
//
// QUÉ HACE:
// Barra de herramientas de la tienda comercial: búsqueda en tiempo real, ordenamiento,
// alternancia de visualización (Cuadrícula / Lista) y acceso directo a nuevo producto.
//
// CÓMO FUNCIONA:
// - Provee un campo de búsqueda iOS Cupertino con botón rápido de limpiar.
// - Menú emergente de ordenamiento por Nombre, Precio y Disponibilidad.
//
// POR QUÉ:
// Mantiene la lógica de control y búsqueda en la tienda en un archivo de < 160 líneas.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BusinessStoreToolbar extends StatelessWidget {
  final String query, sortBy;
  final bool isGridView;
  final ValueChanged<String> onQueryChanged, onSortChanged;
  final VoidCallback onToggleView, onAddProduct;

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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0x66182535),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x2664B5F6)),
            ),
            child: CupertinoTextField(
              placeholder: 'Buscar producto, categoría, SKU o precio...',
              placeholderStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              prefix: const Padding(
                padding: EdgeInsets.only(left: 10, right: 6),
                child: Icon(CupertinoIcons.search, size: 16, color: Color(0xFF94A3B8)),
              ),
              suffix: query.isNotEmpty
                  ? CupertinoButton(
                      padding: const EdgeInsets.only(right: 8),
                      minimumSize: Size.zero,
                      onPressed: () => onQueryChanged(''),
                      child: const Icon(CupertinoIcons.clear_circled_solid, size: 16, color: Color(0xFF94A3B8)),
                    )
                  : null,
              decoration: null,
              onChanged: onQueryChanged,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _SortMenuButton(sortBy: sortBy, onSortChanged: onSortChanged),
              const Spacer(),
              CupertinoButton(
                onPressed: onToggleView,
                padding: EdgeInsets.zero,
                minimumSize: const Size(34, 34),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0x4D1B2A3E),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0x2E81A8CD)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isGridView ? CupertinoIcons.list_bullet : CupertinoIcons.square_grid_2x2,
                        size: 15,
                        color: const Color(0xFF64B5F6),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isGridView ? 'Lista' : 'Cuadrícula',
                        style: const TextStyle(color: Color(0xFFD6E4F0), fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CupertinoButton(
                onPressed: onAddProduct,
                padding: EdgeInsets.zero,
                minimumSize: const Size(34, 34),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF087BFF), Color(0xFF0056B3)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(CupertinoIcons.plus, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text('Producto', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SortMenuButton extends StatelessWidget {
  final String sortBy;
  final ValueChanged<String> onSortChanged;

  const _SortMenuButton({required this.sortBy, required this.onSortChanged});

  @override
  Widget build(BuildContext context) {
    const labels = {'name': 'Nombre', 'price_asc': 'Menor precio', 'price_desc': 'Mayor precio', 'stock': 'Stock'};
    return PopupMenuButton<String>(
      onSelected: onSortChanged,
      color: const Color(0xF2121E2C),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x3364B5F6)),
      ),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'name', child: Text('Nombre', style: TextStyle(color: Colors.white, fontSize: 12.5))),
        const PopupMenuItem(value: 'price_asc', child: Text('Menor precio', style: TextStyle(color: Colors.white, fontSize: 12.5))),
        const PopupMenuItem(value: 'price_desc', child: Text('Mayor precio', style: TextStyle(color: Colors.white, fontSize: 12.5))),
        const PopupMenuItem(value: 'stock', child: Text('Mayor stock', style: TextStyle(color: Colors.white, fontSize: 12.5))),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0x4D1B2A3E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x2E81A8CD)),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.arrow_up_arrow_down, size: 13, color: Color(0xFF64B5F6)),
            const SizedBox(width: 5),
            Text(labels[sortBy] ?? 'Ordenar', style: const TextStyle(color: Color(0xFFD6E4F0), fontSize: 11.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
