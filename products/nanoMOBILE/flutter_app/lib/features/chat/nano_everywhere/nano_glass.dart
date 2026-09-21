// nano_glass.dart — Superficie de vidrio óptico para el panel flotante.
// QUÉ: DecoratedBox + BackdropFilter que simula cristal translúcido.
// CÓMO: RepaintBoundary aísla el blur; BoxDecoration da sombras y borde.
// POR QUÉ: Sin paquetes externos — solo dart:ui + Flutter estándar.
//          Funciona en modo claro y oscuro. No rompe el árbol de clips.
import 'dart:ui';
import 'package:flutter/material.dart';

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
            // Halo azul Nano — intensidad calibrada para no saturar en claro.
            BoxShadow(
              color: const Color(0xFF1464EF).withValues(alpha: .22),
              blurRadius: 28,
              spreadRadius: 1,
            ),
            // Sombra de profundidad (elevación visual).
            BoxShadow(
              color: Colors.black.withValues(alpha: .16),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: rounded,
          child: BackdropFilter(
            // sigmaX/Y 17 → blur perceptible pero no costoso en GPU de gama media.
            filter: ImageFilter.blur(sigmaX: 17, sigmaY: 17),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: rounded,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: dark
                      ? [const Color(0xF11A3155), const Color(0xED071322)]
                      : [const Color(0xF7FFFFFF), const Color(0xE6DDEBFF)],
                ),
                border: Border.all(
                  color: dark ? const Color(0xFF63BEFF) : Colors.white,
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
