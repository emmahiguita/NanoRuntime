// nano_m3_drawer_header.dart — Cabecera profesional estilo iOS para el Drawer.
// QUÉ HACE: Presenta la identidad refinada de Nano AI, subtítulo del sistema y botón de cierre.
// CÓMO FUNCIONA: Usa icono de destellos con gradiente iOS, tipografía Inter y CupertinoIcons.xmark.
// POR QUÉ: Diseño 100% profesional sin avatares informales, respetando estética iOS (< 100 líneas).
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NanoM3DrawerHeader extends StatelessWidget {
  const NanoM3DrawerHeader({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 12, 12),
      child: Row(
        children: [
          // 1. Emblema Nano AI con gradiente cósmico iOS
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9.5),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF007AFF).withValues(alpha: isDark ? 0.35 : 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.sparkles,
                color: Colors.white,
                size: 19,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 2. Título de la app y estado del sistema
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Nano AI',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Sistema Autónomo',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          // 3. Botón de cierre iOS
          IconButton(
            tooltip: 'Cerrar menú',
            icon: Icon(
              CupertinoIcons.xmark_circle_fill,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.60),
              size: 24,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              onClose();
            },
          ),
        ],
      ),
    );
  }
}
