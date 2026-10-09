// business_store_category_filters.dart
//
// QUÉ HACE:
// Barra horizontal de categorías para la tienda comercial de Nano.
// Permite filtrar instantáneamente los productos por categoría con estética iOS Glass Pills.
//
// CÓMO FUNCIONA:
// - Genera chips interactivos para 'Todos' y cada categoría detectada en el catálogo.
// - Muestra contador de elementos disponibles por categoría.
// - Resalta la categoría activa con tono azul iOS y borde iluminado.
//
// POR QUÉ:
// Mantiene desacoplado el componente de filtrado por facetas garantizando archivos < 120 líneas.

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BusinessStoreCategoryFilters extends StatelessWidget {
  final List<String> categories;
  final Map<String, int> categoryCounts;
  final String selectedCategory;
  final int totalCount;
  final ValueChanged<String> onCategorySelected;

  const BusinessStoreCategoryFilters({
    super.key,
    required this.categories,
    required this.categoryCounts,
    required this.selectedCategory,
    required this.totalCount,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final allCategories = ['Todos', ...categories];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: allCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = allCategories[index];
          final isSelected = (cat == 'Todos' && selectedCategory.isEmpty) ||
              (cat == selectedCategory);
          final count = cat == 'Todos' ? totalCount : (categoryCounts[cat] ?? 0);

          return _CategoryPill(
            label: cat,
            count: count,
            isSelected: isSelected,
            onTap: () => onCategorySelected(cat == 'Todos' ? '' : cat),
          );
        },
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryPill({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 32),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF087BFF)
              : const Color(0x661E2D3D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF64B5F6)
                : const Color(0x2E81A8CD),
            width: isSelected ? 1.2 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF087BFF).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            // Badge numérico sutil estilo iOS
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0x33000000),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
