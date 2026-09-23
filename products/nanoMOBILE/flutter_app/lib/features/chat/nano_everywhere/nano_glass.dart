// nano_glass.dart — Cápsula de vidrio óptico para el panel flotante.
// QUÉ: Contenedor glassmorphism con blur, gradiente y borde luminoso.
// CÓMO: BackdropFilter blur 17/17 + DecoratedBox con gradiente adaptativo.
//       RepaintBoundary aisla el blur en su propia capa GPU.
// POR QUÉ: Sin paquetes externos; funciona sobre contenido Flutter (no sistema).
//          El borde aqua en modo oscuro da el estilo Nano Everywhere.
import 'dart:ui';
import 'package:flutter/material.dart';

/// Vidrio óptico sin paquetes adicionales; blur solo de la escena Flutter.
class NanoGlass extends StatelessWidget {
  const NanoGlass({super.key, required this.child, this.radius = 30});
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final rounded = BorderRadius.circular(radius);
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: rounded,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF007BDB).withValues(alpha: .23),
              blurRadius: 28, spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: .17),
              blurRadius: 18, offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: rounded,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 17, sigmaY: 17),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: rounded,
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: dark
                      ? [const Color(0xF11A3155), const Color(0xED071322)]
                      : [const Color(0xF7FFFFFF), const Color(0xE6DDEBFF)],
                ),
                border: Border.all(
                  color: dark ? const Color(0xFF55F0DD) : Colors.white,
                  width: 1.3,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
