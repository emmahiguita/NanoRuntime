import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Fondo ambiental de marca compartido por todas las pantallas nanoai.
///
/// Unifica el gradiente + los dos glows radiales que antes estaban
/// duplicados entre el dashboard (_CrystalBackground) y el shell de
/// pantallas (_AmbientBackground) con valores casi idénticos.
///
/// Adaptativo: azul marino profundo en modo oscuro; en claro, tintes
/// cian/verde muy sutiles sobre blanco para no ensuciar el glassmorphism.
class NanoAmbientBackground extends StatelessWidget {
  const NanoAmbientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()?.colors;
    final dark = colors == null || colors is NanoDarkColors;

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: dark
          ? const [
              Color(0xFF020611),
              Color(0xFF04101D),
              Color(0xFF001326),
              Color(0xFF02050C),
            ]
          : const [
              Color(0xFFFCFCFD),
              Color(0xFFEFF8FC),
              Color(0xFFF0F9FF), // Sky 50 (era teal — gama unificada cyan)
              Color(0xFFFCFCFD),
            ],
    );

    // En claro los glows bajan de intensidad (fondo blanco los satura) pero
    // se mantienen presentes: el BackdropFilter de las cards necesita
    // variación de color detrás o el glass se ve plano y sin profundidad.
    final glowAlpha = dark ? 0.20 : 0.14;

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: Stack(
          children: [
            Positioned(
              top: 160,
              right: -130,
              child: _Glow(
                size: 340,
                color: const Color(0xFF0EA5E9), // Sky 500 — cyan (era azul/verde)
                alpha: glowAlpha,
              ),
            ),
            Positioned(
              top: 380,
              left: -170,
              child: _Glow(
                size: 390,
                color: const Color(0xFF06B6D4), // Cyan 500 — gama única (era verde)
                alpha: glowAlpha,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color, required this.alpha});

  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
