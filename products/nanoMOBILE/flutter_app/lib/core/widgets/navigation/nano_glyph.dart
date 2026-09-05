import 'dart:math' as math;
import 'package:flutter/material.dart';

enum NanoGlyphType {
  home,
  chat,
  models,
  terminal,
  settings,
  automation,
  search,
  microphone,
  arrowForward,
  spark,
}

/// Glifo vectorial independiente renderizado sobre Canvas de alta precisión.
///
/// Iconografía personalizada con fidelidad estética 1:1, pulido profesional
/// y efectos de resplandor cósmico de neón.
class NanoGlyph extends StatelessWidget {
  const NanoGlyph({
    super.key,
    required this.type,
    required this.color,
    this.size = 24,
    this.strokeWidth = 1.85,
    this.glow = false,
  });

  final NanoGlyphType type;
  final Color color;
  final double size;
  final double strokeWidth;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _NanoGlyphPainter(type, color, strokeWidth, glow),
    );
  }
}

class _NanoGlyphPainter extends CustomPainter {
  _NanoGlyphPainter(this.type, this.color, this.sw, this.glow);
  final NanoGlyphType type;
  final Color color;
  final double sw;
  final bool glow;

  Paint get p => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = sw
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint get pf => Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;

    // Efecto de halo de neón brillante cuando está activo
    if (glow) {
      final glowOuter = Paint()
        ..color = color.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw + 3.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.5)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final glowInner = Paint()
        ..color = color.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw + 1.4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      _paintShape(c, w, h, glowOuter, pf);
      _paintShape(c, w, h, glowInner, pf);
    }

    _paintShape(c, w, h, p, pf);
  }

  void _paintShape(Canvas c, double w, double h, Paint stroke, Paint fill) {
    switch (type) {
      case NanoGlyphType.home:
        _home(c, w, h, stroke);
        break;
      case NanoGlyphType.chat:
        _chat(c, w, h, stroke, fill);
        break;
      case NanoGlyphType.models:
        _models(c, w, h, stroke);
        break;
      case NanoGlyphType.terminal:
        _terminal(c, w, h, stroke);
        break;
      case NanoGlyphType.settings:
        _settings(c, w, h, stroke, fill);
        break;
      case NanoGlyphType.automation:
        _automation(c, w, h, stroke, fill);
        break;
      case NanoGlyphType.search:
        _search(c, w, h, stroke);
        break;
      case NanoGlyphType.microphone:
        _mic(c, w, h, stroke, fill);
        break;
      case NanoGlyphType.arrowForward:
        _arrowForward(c, w, h, stroke);
        break;
      case NanoGlyphType.spark:
        _spark(c, w, h, stroke);
        break;
    }
  }

  void _home(Canvas c, double w, double h, Paint stroke) {
    final roof = Path()
      ..moveTo(w * .16, h * .46)
      ..lineTo(w * .50, h * .17)
      ..lineTo(w * .84, h * .46);
    c.drawPath(roof, stroke);

    final body = Path()
      ..moveTo(w * .25, h * .43)
      ..lineTo(w * .25, h * .82)
      ..lineTo(w * .75, h * .82)
      ..lineTo(w * .75, h * .43);
    c.drawPath(body, stroke);

    // Puerta con curva superior suave
    final door = Path()
      ..moveTo(w * .41, h * .82)
      ..lineTo(w * .41, h * .62)
      ..arcToPoint(
        Offset(w * .59, h * .62),
        radius: Radius.circular(w * .09),
      )
      ..lineTo(w * .59, h * .82);
    c.drawPath(door, stroke);
  }

  void _chat(Canvas c, double w, double h, Paint stroke, Paint fill) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .14, h * .18, w * .72, h * .52),
      Radius.circular(w * .18),
    );
    c.drawRRect(r, stroke);
    final tail = Path()
      ..moveTo(w * .33, h * .70)
      ..lineTo(w * .25, h * .85)
      ..lineTo(w * .45, h * .70);
    c.drawPath(tail, stroke);

    // 3 puntos de conversación alineados horizontalmente
    final dotY = h * .44;
    c.drawCircle(Offset(w * .36, dotY), w * .04, fill);
    c.drawCircle(Offset(w * .50, dotY), w * .04, fill);
    c.drawCircle(Offset(w * .64, dotY), w * .04, fill);
  }

  void _models(Canvas c, double w, double h, Paint stroke) {
    Path layer(double cy, double scale) => Path()
      ..moveTo(w * .50, cy - h * .105 * scale)
      ..lineTo(w * .82, cy)
      ..lineTo(w * .50, cy + h * .105 * scale)
      ..lineTo(w * .18, cy)
      ..close();

    c.drawPath(layer(h * .28, 1), stroke);
    c.drawPath(layer(h * .50, 1), stroke);
    c.drawPath(layer(h * .72, 1), stroke);
  }

  void _terminal(Canvas c, double w, double h, Paint stroke) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .13, h * .19, w * .74, h * .62),
      Radius.circular(w * .16),
    );
    c.drawRRect(r, stroke);

    // Prompt '>'
    final chevron = Path()
      ..moveTo(w * .29, h * .39)
      ..lineTo(w * .42, h * .50)
      ..lineTo(w * .29, h * .61);
    c.drawPath(chevron, stroke);

    // Cursor '_'
    c.drawLine(Offset(w * .49, h * .61), Offset(w * .68, h * .61), stroke);
  }

  void _settings(Canvas c, double w, double h, Paint stroke, Paint fill) {
    final center = Offset(w * .5, h * .5);
    c.drawCircle(center, w * .18, stroke);
    for (int i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final a0 = Offset(
        center.dx + math.cos(a) * w * .28,
        center.dy + math.sin(a) * h * .28,
      );
      final a1 = Offset(
        center.dx + math.cos(a) * w * .39,
        center.dy + math.sin(a) * h * .39,
      );
      c.drawLine(a0, a1, stroke);
    }
    c.drawCircle(center, w * .06, fill);
  }

  void _automation(Canvas c, double w, double h, Paint stroke, Paint fill) {
    final center = Offset(w * .50, h * .51);

    // 1. Esfera central del planeta
    c.drawCircle(center, w * .21, stroke);

    // 2. Anillo orbital cósmico inclinado a ~-38 grados
    final ringRect = Rect.fromCenter(
      center: center,
      width: w * .78,
      height: h * .34,
    );
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(-0.64);
    c.translate(-center.dx, -center.dy);
    c.drawOval(ringRect, stroke);
    c.restore();

    // 3. Brillo estelar orbital en la parte superior derecha
    c.drawCircle(Offset(w * .73, h * .23), w * .04, fill);
  }

  void _search(Canvas c, double w, double h, Paint stroke) {
    c.drawCircle(Offset(w * .43, h * .43), w * .23, stroke);
    c.drawLine(Offset(w * .60, h * .60), Offset(w * .82, h * .82), stroke);
  }

  void _mic(Canvas c, double w, double h, Paint stroke, Paint fill) {
    final mic = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .37, h * .17, w * .26, h * .45),
      Radius.circular(w * .13),
    );
    c.drawRRect(mic, stroke);

    final arc = Path()
      ..moveTo(w * .25, h * .49)
      ..quadraticBezierTo(w * .27, h * .74, w * .50, h * .75)
      ..quadraticBezierTo(w * .73, h * .74, w * .75, h * .49);
    c.drawPath(arc, stroke);

    c.drawLine(Offset(w * .50, h * .75), Offset(w * .50, h * .88), stroke);
    c.drawLine(Offset(w * .36, h * .88), Offset(w * .64, h * .88), stroke);
  }

  void _arrowForward(Canvas c, double w, double h, Paint stroke) {
    final path = Path()
      ..moveTo(w * .25, h * .50)
      ..lineTo(w * .72, h * .50)
      ..moveTo(w * .52, h * .31)
      ..lineTo(w * .73, h * .50)
      ..lineTo(w * .52, h * .69);
    c.drawPath(path, stroke);
  }

  void _spark(Canvas c, double w, double h, Paint stroke) {
    final center = Offset(w * .5, h * .5);
    final radius = w * .28;
    final path = Path();
    for (int i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * math.pi / 4;
      final r = i.isEven ? radius : radius * .28;
      final pt = Offset(center.dx + math.cos(a) * r, center.dy + math.sin(a) * r);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        path.lineTo(pt.dx, pt.dy);
      }
    }
    path.close();
    c.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _NanoGlyphPainter oldDelegate) =>
      oldDelegate.type != type ||
      oldDelegate.color != color ||
      oldDelegate.sw != sw ||
      oldDelegate.glow != glow;
}
