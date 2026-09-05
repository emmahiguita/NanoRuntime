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
/// Proporciona iconografía personalizada y coherente sin dependencias externas
/// de fuentes ni paquetes adicionales, asegurando nitidez 1:1 en cualquier DPI.
class NanoGlyph extends StatelessWidget {
  const NanoGlyph({
    super.key,
    required this.type,
    required this.color,
    this.size = 24,
    this.strokeWidth = 1.9,
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
    if (glow) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw + 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      _paintShape(c, s.width, s.height, glowPaint, pf);
    }
    _paintShape(c, s.width, s.height, p, pf);
  }

  void _paintShape(Canvas c, double w, double h, Paint stroke, Paint fill) {
    switch (type) {
      case NanoGlyphType.home:
        _home(c, w, h, stroke, fill);
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
        _mic(c, w, h, stroke);
        break;
      case NanoGlyphType.arrowForward:
        _arrowForward(c, w, h, stroke);
        break;
      case NanoGlyphType.spark:
        _spark(c, w, h, stroke);
        break;
    }
  }

  void _home(Canvas c, double w, double h, Paint stroke, Paint fill) {
    final path = Path()
      ..moveTo(w * .16, h * .46)
      ..lineTo(w * .50, h * .16)
      ..lineTo(w * .84, h * .46)
      ..moveTo(w * .24, h * .43)
      ..lineTo(w * .24, h * .82)
      ..lineTo(w * .76, h * .82)
      ..lineTo(w * .76, h * .43);
    c.drawPath(path, stroke);
    // Puerta sutil central
    final door = Path()
      ..moveTo(w * .40, h * .82)
      ..lineTo(w * .40, h * .58)
      ..lineTo(w * .60, h * .58)
      ..lineTo(w * .60, h * .82);
    c.drawPath(door, stroke);
  }

  void _chat(Canvas c, double w, double h, Paint stroke, Paint fill) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .14, h * .18, w * .72, h * .52),
      Radius.circular(w * .18),
    );
    c.drawRRect(r, stroke);
    final tail = Path()
      ..moveTo(w * .32, h * .70)
      ..lineTo(w * .26, h * .84)
      ..lineTo(w * .44, h * .70);
    c.drawPath(tail, stroke);
    // 3 puntos de conversación en el centro
    final dotY = h * .44;
    c.drawCircle(Offset(w * .36, dotY), w * .04, fill);
    c.drawCircle(Offset(w * .50, dotY), w * .04, fill);
    c.drawCircle(Offset(w * .64, dotY), w * .04, fill);
  }

  void _models(Canvas c, double w, double h, Paint stroke) {
    Path diamond(double cy, double scale) => Path()
      ..moveTo(w * .50, cy - h * .11 * scale)
      ..lineTo(w * .80, cy)
      ..lineTo(w * .50, cy + h * .11 * scale)
      ..lineTo(w * .20, cy)
      ..close();
    c.drawPath(diamond(h * .28, 1), stroke);
    c.drawPath(diamond(h * .50, 1), stroke);
    c.drawPath(diamond(h * .72, 1), stroke);
  }

  void _terminal(Canvas c, double w, double h, Paint stroke) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .14, h * .20, w * .72, h * .60),
      Radius.circular(w * .14),
    );
    c.drawRRect(r, stroke);
    final chevron = Path()
      ..moveTo(w * .30, h * .40)
      ..lineTo(w * .42, h * .50)
      ..lineTo(w * .30, h * .60);
    c.drawPath(chevron, stroke);
    c.drawLine(Offset(w * .50, h * .60), Offset(w * .68, h * .60), stroke);
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
        center.dx + math.cos(a) * w * .38,
        center.dy + math.sin(a) * h * .38,
      );
      c.drawLine(a0, a1, stroke);
    }
    c.drawCircle(center, w * .055, fill);
  }

  void _automation(Canvas c, double w, double h, Paint stroke, Paint fill) {
    final center = Offset(w * .50, h * .50);
    // Planeta central esférico
    c.drawCircle(center, w * .20, stroke);
    // Anillo orbital inclinado elíptico
    final ringRect = Rect.fromCenter(
      center: center,
      width: w * .76,
      height: h * .34,
    );
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(-0.55);
    c.translate(-center.dx, -center.dy);
    c.drawOval(ringRect, stroke);
    c.restore();
    // Brillos estelares
    c.drawCircle(Offset(w * .72, h * .24), w * .04, fill);
    c.drawCircle(Offset(w * .26, h * .74), w * .035, fill);
  }

  void _search(Canvas c, double w, double h, Paint stroke) {
    c.drawCircle(Offset(w * .44, h * .43), w * .23, stroke);
    c.drawLine(Offset(w * .61, h * .61), Offset(w * .82, h * .82), stroke);
  }

  void _mic(Canvas c, double w, double h, Paint stroke) {
    final mic = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .37, h * .16, w * .26, h * .46),
      Radius.circular(w * .13),
    );
    c.drawRRect(mic, stroke);
    final arc = Path()
      ..moveTo(w * .26, h * .50)
      ..quadraticBezierTo(w * .28, h * .73, w * .50, h * .74)
      ..quadraticBezierTo(w * .72, h * .73, w * .74, h * .50);
    c.drawPath(arc, stroke);
    c.drawLine(Offset(w * .50, h * .74), Offset(w * .50, h * .87), stroke);
    c.drawLine(Offset(w * .38, h * .87), Offset(w * .62, h * .87), stroke);
  }

  void _arrowForward(Canvas c, double w, double h, Paint stroke) {
    final path = Path()
      ..moveTo(w * .26, h * .50)
      ..lineTo(w * .70, h * .50)
      ..moveTo(w * .52, h * .32)
      ..lineTo(w * .72, h * .50)
      ..lineTo(w * .52, h * .68);
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
