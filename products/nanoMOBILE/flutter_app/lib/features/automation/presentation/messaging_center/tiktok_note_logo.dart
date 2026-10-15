// tiktok_note_logo.dart
//
// QUÉ HACE: dibuja la nota musical característica de TikTok en blanco puro.
// CÓMO FUNCIONA: CustomPainter con el path vectorial oficial de la marca
// (viewBox 24×24) escalado proporcionalmente al tamaño solicitado.
// POR QUÉ: mantener el logo en archivo propio (<200 líneas) permite
// reutilizarlo en el acceso directo del Centro de Mensajería sin acoplar
// los painters de otras plataformas (SRP / SOLID).

import 'package:flutter/material.dart';

class TikTokNoteLogo extends StatelessWidget {
  final double size;

  const TikTokNoteLogo({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _TikTokNotePainter()),
    );
  }
}

/// Pinta la silueta oficial de TikTok con coordenadas normalizadas 0–24.
class _TikTokNotePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    /// Escala una coordenada del viewBox 24×24 al tamaño real.
    double s(double v, {required bool x}) => v / 24 * (x ? w : h);

    final p = Path()
      // Tallo superior: arco de entrada de la nota
      ..moveTo(s(16.6, x: true), s(5.82, x: false))
      ..arcToPoint(
        Offset(s(15.54, x: true), s(3.0, x: false)),
        radius: Radius.circular(s(4.278, x: true)),
        clockwise: true,
      )
      // Descenso del tallo hasta la cabeza
      ..lineTo(s(12.45, x: true), s(3.0, x: false))
      ..lineTo(s(12.45, x: true), s(15.4, x: false))
      // Cabeza izquierda redondeada
      ..arcToPoint(
        Offset(s(9.86, x: true), s(17.9, x: false)),
        radius: Radius.circular(s(2.592, x: true)),
        clockwise: true,
      )
      ..cubicTo(
        s(8.44, x: true), s(17.9, x: false),
        s(7.26, x: true), s(16.74, x: false),
        s(7.26, x: true), s(15.3, x: false),
      )
      ..cubicTo(
        s(7.26, x: true), s(13.58, x: false),
        s(8.92, x: true), s(12.29, x: false),
        s(10.63, x: true), s(12.82, x: false),
      )
      // Vuelta del tallo hacia arriba
      ..lineTo(s(10.63, x: true), s(9.66, x: false))
      ..cubicTo(
        s(7.18, x: true), s(9.20, x: false),
        s(4.16, x: true), s(11.88, x: false),
        s(4.16, x: true), s(15.3, x: false),
      )
      // Base de la cabeza derecha
      ..cubicTo(
        s(4.16, x: true), s(18.63, x: false),
        s(6.92, x: true), s(21.0, x: false),
        s(9.85, x: true), s(21.0, x: false),
      )
      ..cubicTo(
        s(12.99, x: true), s(21.0, x: false),
        s(15.54, x: true), s(18.45, x: false),
        s(15.54, x: true), s(15.3, x: false),
      )
      ..lineTo(s(15.54, x: true), s(9.01, x: false))
      // Arco superior del tallo (contra las agujas del reloj)
      ..arcToPoint(
        Offset(s(19.84, x: true), s(10.39, x: false)),
        radius: Radius.circular(s(7.35, x: true)),
        clockwise: false,
      )
      ..lineTo(s(19.84, x: true), s(7.3, x: false))
      ..cubicTo(
        s(19.84, x: true), s(7.3, x: false),
        s(17.96, x: true), s(7.39, x: false),
        s(16.6, x: true), s(5.82, x: false),
      )
      ..close();

    canvas.drawPath(p, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
