// nano_glass_dialog.dart
//
// QUÉ HACE:
// Contenedor modal profesional con diseño iOS Frosted Glass, borde metálico reflectante,
// compatibilidad fluida en orientación vertical y horizontal, y tipografía de alta jerarquía.
//
// CÓMO FUNCIONA:
// - Despliega un modal con BackdropFilter (desenfoque gaussiano 24px) y fondo translúcido.
// - Aplica borde metálico con gradiente especular (luz superior blanca/plata).
// - Calcula límites adaptativos en orientación horizontal para evitar desbordamientos.
//
// POR QUÉ:
// Estandariza la experiencia visual de todos los diálogos y modales de la aplicación bajo SOLID.

import 'dart:ui';
import 'package:flutter/material.dart';

class NanoGlassDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget content;
  final List<Widget>? actions;
  final VoidCallback? onClose;

  const NanoGlassDialog({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    required this.content,
    this.actions,
    this.onClose,
  });

  /// Método estático de conveniencia para mostrar el diálogo con animación nativa.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    IconData? icon,
    Color? iconColor,
    required Widget content,
    List<Widget>? actions,
  }) {
    return showDialog<T>(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => NanoGlassDialog(
        title: title,
        subtitle: subtitle,
        icon: icon,
        iconColor: iconColor,
        content: content,
        actions: actions,
        onClose: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    final isLandscape = media.orientation == Orientation.landscape;

    final dialogWidth = isLandscape
        ? (media.size.width * 0.60).clamp(320.0, 500.0)
        : (media.size.width * 0.90).clamp(280.0, 420.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      elevation: 0,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              width: dialogWidth,
              constraints: BoxConstraints(
                maxHeight: isLandscape ? media.size.height * 0.88 : media.size.height * 0.80,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A).withValues(alpha: 0.82)
                    : Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.90),
                  width: 1.1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cabecera del diálogo
                    Row(
                      children: [
                        if (icon != null) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (iconColor ?? const Color(0xFF2563EB)).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: (iconColor ?? const Color(0xFF2563EB)).withValues(alpha: 0.30),
                                width: 0.8,
                              ),
                            ),
                            child: Icon(
                              icon,
                              size: 18,
                              color: iconColor ?? (isDark ? Colors.white : const Color(0xFF2563EB)),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  subtitle!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (onClose != null)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                            ),
                            onPressed: onClose,
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Contenido principal
                    content,
                    if (actions != null && actions!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      // Fila de acciones
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          for (int i = 0; i < actions!.length; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            actions![i],
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
