// business_library_section_tabs.dart
//
// QUÉ HACE:
// Barra de pestañas segmentada estilo iOS para alternar entre "Documentos" y "Tienda" en la Biblioteca.
//
// CÓMO FUNCIONA:
// - Despliega botones redondeados translúcidos con indicadores numéricos para cada sección.
// - Aplica transición fluida y retroalimentación táctil de selección activa.
//
// POR QUÉ:
// Separa el selector de sección del header principal respetando el límite estricto de < 120 líneas.

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
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Container(
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest.withValues(alpha: .30),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.outlineVariant),
        ),
        child: Row(
          children: [
            // Pestaña Documentos
            Expanded(
              child: _TabButton(
                icon: CupertinoIcons.folder_fill,
                label: 'Archivos',
                count: documentsCount,
                isSelected: currentSection == BusinessLibrarySection.documents,
                onTap: () => onSectionChanged(BusinessLibrarySection.documents),
              ),
            ),
            const SizedBox(width: 4),
            // Pestaña Tienda / Catálogo
            Expanded(
              child: _TabButton(
                icon: CupertinoIcons.bag_fill,
                label: 'Tienda',
                count: productsCount,
                isSelected: currentSection == BusinessLibrarySection.store,
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
  final VoidCallback onTap;

  const _TabButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return CupertinoButton(
      onPressed: onTap,
      padding: EdgeInsets.zero,
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected ? colors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [BoxShadow(color: colors.shadow.withValues(alpha: .06), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: isSelected ? colors.onPrimary : colors.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? colors.onPrimary : colors.onSurface,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? colors.onPrimary.withValues(alpha: .15) : colors.onSurface.withValues(alpha: .06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? colors.onPrimary : colors.onSurfaceVariant,
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
