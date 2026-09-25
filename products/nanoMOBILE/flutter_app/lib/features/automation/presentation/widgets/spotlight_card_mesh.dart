/// SPOTLIGHT-CARD-MESH — Acabado de cristal tecnológico estilo iOS y sombra 3D.
///
/// QUÉ HACE:
/// Renderiza la superficie física de la tarjeta 3D con reflejo especular dinámico
/// estilo iOS, bisel iluminado y sombra que reacciona a la rotación angular.
///
/// CÓMO FUNCIONA:
/// Aloja la cara activa ([front] o [back]) aplicando corrección de espejo de 180° si está
/// en reverso. Proyecta un brillo especular oblicuo sincronizado con el coseno de [angle].
///
/// POR QUÉ:
/// Ofrece el acabado de alta gama Apple Glass sin consumir ciclos pesados de GPU,
/// manteniendo el código modular y por debajo del límite estricto de 200 líneas.
library;

import 'dart:math' as math;
import 'package:flutter/material.dart';

class SpotlightCardMesh extends StatelessWidget {
  final Widget front;
  final Widget back;
  final bool frontVisible;
  final double angle;

  const SpotlightCardMesh({
    super.key,
    required this.front,
    required this.back,
    required this.frontVisible,
    this.angle = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    // Cálculo de la luz especular móvil estilo iOS
    final sheenPos = (math.sin(angle) * 1.5).clamp(-1.8, 1.8);
    final shadowShiftX = math.sin(angle) * 18.0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          // Sombra ambiental profunda de fondo
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 28,
            offset: Offset(shadowShiftX * 0.5, 14),
          ),
          // Resplandor esmeralda difuso estilo iOS
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.18),
            blurRadius: 32,
            spreadRadius: -2,
            offset: Offset(shadowShiftX * 0.3, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Cara activa (anverso o reverso con corrección de espejo 180°)
            frontVisible
                ? front
                : Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: back,
                  ),
            // 2. Reflejo especular cinemático estilo iOS que recorre el cristal
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(-1.2 + sheenPos, -1.0),
                    end: Alignment(1.2 + sheenPos, 1.0),
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.16),
                      const Color(0xFF44FFCE).withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    stops: const [0.30, 0.48, 0.54, 0.70],
                  ),
                ),
              ),
            ),
            // 3. Bisel de cristal con degradado metálico iOS
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFF44FFCE).withValues(alpha: 0.38),
                    width: 0.9,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
