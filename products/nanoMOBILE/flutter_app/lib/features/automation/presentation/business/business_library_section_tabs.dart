// business_library_section_tabs.dart
//
// QUÉ HACE:
// Segmented Control profesional estilo iOS para alternar entre "Archivos" y "Tienda".
//
// CÓMO FUNCIONA:
// - Pista neutra suave con cápsula activa elevada (blanco puro en claro, slate en oscuro).
// - Tipografía grafito/blanca con contraste definido y badges numéricos discretos.
//
// POR QUÉ:
// Elimina el aspecto de 'barra de progreso' y adopta diseño Apple nativo (< 130 líneas).

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum BusinessLibrarySection { documents, store }

class BusinessLibrarySectionTabs extends StatelessWidget {
  final BusinessLibrarySection currentSection;
  final int documentsCount;
  final int productsCount;
  final ValueChanged<BusinessLibrarySection> onSectionChanged;

  const BusinessLibrarySectionTabs({
    super.key,
    required this.currentSection,
    required this.documentsCount,
    required this.productsCount,
    required this.onSectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.75)
        : const Color(0xFFF1F5F9).withValues(alpha: 0.95);
    final trackBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: trackBorder, width: 0.8),
        ),
        child: Row(
          children: [
            Expanded(
              child: _TabButton(
                icon: CupertinoIcons.folder_fill,
                label: 'Archivos',
                count: documentsCount,
                isSelected: currentSection == BusinessLibrarySection.documents,
                isDark: isDark,
                onTap: () => onSectionChanged(BusinessLibrarySection.documents),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _TabButton(
                icon: CupertinoIcons.bag_fill,
                label: 'Tienda',
                count: productsCount,
                isSelected: currentSection == BusinessLibrarySection.store,
                isDark: isDark,
                onTap: () => onSectionChanged(BusinessLibrarySection.store),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selectedBg = isDark ? const Color(0xFF334155) : Colors.white;
    final fgColor = isSelected
        ? (isDark ? Colors.white : const Color(0xFF0F172A))
        : (isDark ? Colors.white60 : const Color(0xFF64748B));

    return CupertinoButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.08),
                    blurRadius: 5,
                    offset: const Offset(0, 1.5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: fgColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: fgColor,
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : const Color(0xFFF1F5F9))
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0x0C000000)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? (isDark ? Colors.white12 : const Color(0xFFE2E8F0))
                      : Colors.transparent,
                  width: 0.5,
                ),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: fgColor.withValues(alpha: isSelected ? 0.9 : 0.7),
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
