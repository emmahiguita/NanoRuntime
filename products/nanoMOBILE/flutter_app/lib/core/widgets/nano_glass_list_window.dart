// nano_glass_list_window.dart — Ventana modal estilo Liquid Glass para listas y selectores.
// QUÉ HACE:
// Renderiza ventanas flotantes modales con acabado Liquid Glass optimizadas para listas de opciones,
// eliminando desbordamientos, recortando bordes y unificando la estética de diálogos en Nano AI.
//
// CÓMO FUNCIONA:
// Aloja un GlassSurface con desenfoque óptico de 28dp, tintado dinámico según brillo (dark/light),
// cabecera con tirador táctil y botón de cierre, y área scrolleable con tiles redondeados interactivos.
//
// POR QUÉ:
// Resuelve los problemas de contraste, sangrado de bordes y rigidez en listas modales de opciones
// garantizando accesibilidad WCAG y respetando la directriz de menos de 190 líneas por archivo.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'glass_surface.dart';

export 'nano_glass_list_tile.dart' show NanoGlassListTile;

class NanoGlassListWindow extends StatelessWidget {
  const NanoGlassListWindow({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.leadingIcon,
    this.onClose,
    this.maxWidth = 440.0,
  });

  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final VoidCallback? onClose;
  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final width = math.min(media.size.width - 32, maxWidth);
    final maxHeight = media.size.height * 0.82;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, maxHeight: maxHeight),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: GlassSurface(
            radius: 24,
            blur: 24,
            opacity: 0.96,
            tint: isDark
                ? const Color(0xFF111827).withValues(alpha: 0.88)
                : const Color(0xFFF8FAFC).withValues(alpha: 0.95),
            borderWidth: 0.8,
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Tirador táctil superior
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.20)
                          : Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // 2. Cabecera integrada con título y cierre
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 10, 8),
                  child: Row(
                    children: [
                      if (leadingIcon != null) ...[
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: scheme.primary.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(leadingIcon, size: 16, color: scheme.primary),
                        ),
                        const SizedBox(width: 10),
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
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface,
                                letterSpacing: -0.2,
                              ),
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Cerrar',
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: scheme.onSurfaceVariant,
                        ),
                        onPressed: onClose ?? () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 0.8,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : scheme.outlineVariant.withValues(alpha: 0.40),
                ),
                // 3. Contenido scrolleable de opciones tipo lista
                Flexible(
                  fit: FlexFit.loose,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
