import 'package:flutter/material.dart';

/// Fondo ambiental de marca compartido por todas las pantallas nanoai.
///
/// Unifica el gradiente oscuro + los dos glows radiales que antes estaban
/// duplicados entre el dashboard (_CrystalBackground) y el shell de
/// pantallas (_AmbientBackground) con valores casi idénticos.
class NanoAmbientBackground extends StatelessWidget {
  const NanoAmbientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF020611),
              Color(0xFF04101D),
              Color(0xFF001326),
              Color(0xFF02050C),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 160,
              right: -130,
              child: _Glow(size: 340, color: Color(0xFF0066CC)),
            ),
            Positioned(
              top: 380,
              left: -170,
              child: _Glow(size: 390, color: Color(0xFF00C896)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.20), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
