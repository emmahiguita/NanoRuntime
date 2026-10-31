// nano_nav_side_drawer.dart — Ventana lateral Liquid Glass profesional.
// QUÉ HACE:
// Despliega un panel lateral translúcido con los 4 destinos principales y controles
// de restauración cuando el usuario desliza la barra de navegación hacia la izquierda.
//
// CÓMO FUNCIONA:
// Aloja una ventana con GlassSurface, cabecera profesional sin avatares informales,
// tiles verticales con feedback táctil y botón de retorno al dock.
//
// POR QUÉ:
// Mantiene el diseño 100% profesional y limpio acorde a las directrices visuales.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../glass_surface.dart';
import 'nano_destination.dart';
import 'nano_nav_drawer_tile.dart';

class NanoNavSideDrawer extends StatelessWidget {
  const NanoNavSideDrawer({
    super.key,
    required this.selected,
    required this.onDestinationSelected,
    required this.onRestoreBottom,
  });

  final NanoDestination selected;
  final ValueChanged<NanoDestination> onDestinationSelected;
  final VoidCallback onRestoreBottom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final dividerThickness = 1.0 / (pixelRatio > 0 ? pixelRatio : 1.0);

    return RepaintBoundary(
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 200) {
            onRestoreBottom();
          }
        },
        child: SizedBox(
          width: 260,
          child: GlassSurface(
            radius: 22,
            blur: 20,
            opacity: isDark ? 0.88 : 0.92,
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Cabecera profesional: icono badge, título y botón de retorno
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(9),
                          color: scheme.primary.withValues(alpha: isDark ? 0.22 : 0.12),
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: isDark ? 0.32 : 0.20),
                            width: 0.8,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: scheme.primary,
                            size: 17,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Nano AI',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: scheme.onSurface,
                              ),
                            ),
                            Text(
                              'Navegación lateral',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Restaurar barra inferior',
                        iconSize: 20,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          CupertinoIcons.chevron_down_circle,
                          color: scheme.onSurfaceVariant,
                        ),
                        onPressed: onRestoreBottom,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Divider(
                    height: dividerThickness,
                    thickness: dividerThickness,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                // 2. Destinos verticales interactivos
                for (final destination in NanoDestination.values) ...[
                  NanoNavDrawerTile(
                    destination: destination,
                    isSelected: selected == destination,
                    onTap: () => onDestinationSelected(destination),
                  ),
                  const SizedBox(height: 3),
                ],
                const SizedBox(height: 6),
                // 3. Botón inferior para restaurar dock
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: onRestoreBottom,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.arrow_down_to_line,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Dock inferior',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
