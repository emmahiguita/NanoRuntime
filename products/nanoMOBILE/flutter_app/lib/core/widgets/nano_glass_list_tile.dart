// nano_glass_list_tile.dart — Elemento interactivo individual para listas Liquid Glass.
// QUÉ HACE:
// Renderiza un ítem de lista táctil con bordes redondeados (16dp), estados activo/inactivo
// y retroalimentación háptica para ventanas y selectores modales Liquid Glass.
//
// CÓMO FUNCIONA:
// Presenta Material + InkWell con fondo y borde primarios cuando está seleccionado,
// icono indicador (check o custom) y textos jerárquicos de título y descripción.
//
// POR QUÉ:
// Aplica el principio de Responsabilidad Única (SRP) manteniendo nano_glass_list_window.dart < 200 líneas.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NanoGlassListTile extends StatelessWidget {
  const NanoGlassListTile({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.trailing,
    this.isSelected = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final activeBackground = isDark
        ? scheme.primary.withValues(alpha: 0.16)
        : scheme.primary.withValues(alpha: 0.10);
    final activeBorder = isDark
        ? scheme.primary.withValues(alpha: 0.30)
        : scheme.primary.withValues(alpha: 0.20);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: isSelected ? activeBackground : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? activeBorder : Colors.transparent,
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? scheme.primary : scheme.onSurface,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ] else if (isSelected)
                  Icon(Icons.check_rounded, size: 20, color: scheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
