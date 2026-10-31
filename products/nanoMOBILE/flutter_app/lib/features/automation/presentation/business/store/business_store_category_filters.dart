// business_store_category_filters.dart
//
// QUÃ‰ HACE:
// Filtros horizontales discretos por categorÃ­a para la tienda de Nano.
//
// CÃ“MO FUNCIONA:
// - Oculta la fila si sÃ³lo existe una Ãºnica categorÃ­a para no duplicar 'Todos'.
// - Despliega cÃ¡psulas sutiles con altura compacta de 30 dp e indicador de cantidad.
//
// POR QUÃ‰:
// Optimiza el espacio y evita controles redundantes segÃºn la guÃ­a (< 120 lÃ­neas).

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
    if (categories.length <= 1) return const SizedBox.shrink();

    final allCategories = ['Todos', ...categories];

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: allCategories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final cat = allCategories[index];
          final isSelected =
              (index == 0 && selectedCategory.isEmpty) || (index > 0 && cat == selectedCategory);
          final count = index == 0 ? totalCount : (categoryCounts[cat] ?? 0);

          return _CategoryPill(
            label: cat,
            count: count,
            isSelected: isSelected,
            onTap: () => onCategorySelected(index == 0 ? '' : cat),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 30),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
              : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0x0A000000)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.white24 : const Color(0xFFCBD5E1))
                : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$count',
              style: TextStyle(
                color: isSelected
                    ? (isDark ? Colors.white70 : const Color(0xFF475569))
                    : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
