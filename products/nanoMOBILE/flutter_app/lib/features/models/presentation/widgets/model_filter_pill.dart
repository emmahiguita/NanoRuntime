// QUÉ: filtro de catálogo con selección neutra y accesible.
// CÓMO: conserva el callback y añade semántica; usa el tema claro u oscuro.
// POR QUÉ: la selección no necesita un contorno ni texto verde.
import 'package:flutter/material.dart';
import 'model_catalog_surface.dart';

class IosSegmentPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const IosSegmentPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? modelCatalogSurface(context) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.outlineVariant, width: 0.8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? colors.onSurface : colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
