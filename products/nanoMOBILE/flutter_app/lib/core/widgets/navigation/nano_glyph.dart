import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'nano_nav_tokens.dart';

enum NanoGlyphType {
  home,
  chat,
  models,
  terminal,
  settings,
  automation,
  microphone,
  arrowForward,
  search,
  attachment,
  close,
  send,
  clock,
  rules,
  tuning,
  reply,
  bluetooth,
  browser,
  linux,
  notification,
  files,
  back,
  chevronDown,
  chevronUp,
  statusOk,
  statusWarning,
  statusError,
  security,
  voice,
  memory,
  cpu,
}

enum NanoIconState {
  normal,
  active,
  selected,
  disabled,
}

/// Componente centralizado de iconografía Nano Design System v1.
///
/// Soporta Canvas vectorial de alta precisión, micro-resorte físico al tocar
/// (1.0 → 0.965 → 1.0) y resplandor de neón controlado sin deformación de trazo.
class NanoIcon extends StatefulWidget {
  const NanoIcon({
    super.key,
    required this.type,
    this.color,
    this.size = 22,
    this.strokeWidth = 1.75,
    this.glow,
    this.state = NanoIconState.normal,
    this.onTap,
  });

  final NanoGlyphType type;
  final Color? color;
  final double size;
  final double strokeWidth;
  final bool? glow;
  final NanoIconState state;
  final VoidCallback? onTap;

  @override
  State<NanoIcon> createState() => _NanoIconState();
}

class _NanoIconState extends State<NanoIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.965).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null && widget.state != NanoIconState.disabled) {
      _anim.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null && widget.state != NanoIconState.disabled) {
      _anim.reverse();
    }
  }

  void _onTapCancel() {
    _anim.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = NanoNavTokens.activeAccent(Theme.of(context).brightness);
    final effectiveColor = widget.color ??
        (widget.state == NanoIconState.selected || widget.state == NanoIconState.active
            ? themeColor
            : (widget.state == NanoIconState.disabled
                ? Colors.grey.withValues(alpha: 0.4)
                : (Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFE6EDF6)
                    : const Color(0xFF0F172A))));
    final effectiveGlow = widget.glow ??
        (widget.state == NanoIconState.active || widget.state == NanoIconState.selected);

    Widget iconWidget = NanoGlyph(
      type: widget.type,
      color: effectiveColor,
      size: widget.size,
      strokeWidth: widget.strokeWidth,
      glow: effectiveGlow,
    );

    if (widget.onTap != null) {
      return GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.state == NanoIconState.disabled ? null : widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) => Transform.scale(
            scale: _scale.value,
            child: child,
          ),
          child: iconWidget,
        ),
      );
    }

    return iconWidget;
  }
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
      case NanoGlyphType.microphone:
        _mic(c, w, h, stroke, fill);
        break;
      case NanoGlyphType.arrowForward:
        _arrowForward(c, w, h, stroke);
        break;
      case NanoGlyphType.search:
        _search(c, w, h, stroke);
        break;
      case NanoGlyphType.attachment:
        _attachment(c, w, h, stroke);
        break;
      case NanoGlyphType.close:
        _close(c, w, h, stroke);
        break;
      case NanoGlyphType.send:
        _send(c, w, h, stroke, fill);
        break;
      case NanoGlyphType.clock:
        _clock(c, w, h, stroke);
        break;
      case NanoGlyphType.rules:
        _rules(c, w, h, stroke, fill);
        break;
      case NanoGlyphType.tuning:
        _tuning(c, w, h, stroke, fill);
        break;
      case NanoGlyphType.reply:
        _reply(c, w, h, stroke);
        break;
      case NanoGlyphType.bluetooth:
        _bluetooth(c, w, h, stroke);
        break;
      case NanoGlyphType.browser:
        _browser(c, w, h, stroke, fill);
        break;
      case NanoGlyphType.linux:
        _linux(c, w, h, stroke, fill);
        break;
      case NanoGlyphType.notification:
        _notification(c, w, h, stroke, fill);
        break;
      case NanoGlyphType.files:
        _files(c, w, h, stroke);
        break;
      case NanoGlyphType.back:
        _back(c, w, h, stroke);
        break;
      case NanoGlyphType.chevronDown:
        _chevronDown(c, w, h, stroke);
        break;
      case NanoGlyphType.chevronUp:
        _chevronUp(c, w, h, stroke);
        break;
      case NanoGlyphType.statusOk:
        _statusOk(c, w, h, stroke);
        break;
      case NanoGlyphType.statusWarning:
        _statusWarning(c, w, h, stroke, fill);
        break;
      case NanoGlyphType.statusError:
        _statusError(c, w, h, stroke);
        break;
      case NanoGlyphType.security:
        _security(c, w, h, stroke);
        break;
      case NanoGlyphType.voice:
        _voice(c, w, h, stroke);
        break;
      case NanoGlyphType.memory:
        _memory(c, w, h, stroke);
        break;
      case NanoGlyphType.cpu:
        _cpu(c, w, h, stroke, fill);
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

  void _search(Canvas c, double w, double h, Paint stroke) {
    c.drawCircle(Offset(w * .42, h * .42), w * .24, stroke);
    c.drawLine(Offset(w * .60, h * .60), Offset(w * .82, h * .82), stroke);
  }

  void _attachment(Canvas c, double w, double h, Paint stroke) {
    final p = Path()
      ..moveTo(w * .65, h * .38)
      ..lineTo(w * .40, h * .63)
      ..arcToPoint(Offset(w * .28, h * .63), radius: Radius.circular(w * .08), clockwise: false)
      ..arcToPoint(Offset(w * .28, h * .51), radius: Radius.circular(w * .08), clockwise: false)
      ..lineTo(w * .56, h * .23)
      ..arcToPoint(Offset(w * .74, h * .23), radius: Radius.circular(w * .12))
      ..arcToPoint(Offset(w * .74, h * .41), radius: Radius.circular(w * .12))
      ..lineTo(w * .46, h * .69)
      ..arcToPoint(Offset(w * .28, h * .69), radius: Radius.circular(w * .12), clockwise: false)
      ..arcToPoint(Offset(w * .20, h * .51), radius: Radius.circular(w * .16), clockwise: false)
      ..lineTo(w * .20, h * .45);
    c.drawPath(p, stroke);
  }

  void _close(Canvas c, double w, double h, Paint stroke) {
    c.drawLine(Offset(w * .28, h * .28), Offset(w * .72, h * .72), stroke);
    c.drawLine(Offset(w * .72, h * .28), Offset(w * .28, h * .72), stroke);
  }

  void _send(Canvas c, double w, double h, Paint stroke, Paint fill) {
    final p = Path()
      ..moveTo(w * .50, h * .20)
      ..lineTo(w * .22, h * .48)
      ..moveTo(w * .50, h * .20)
      ..lineTo(w * .78, h * .48)
      ..moveTo(w * .50, h * .20)
      ..lineTo(w * .50, h * .80);
    c.drawPath(p, stroke);
  }

  void _clock(Canvas c, double w, double h, Paint stroke) {
    c.drawCircle(Offset(w * .50, h * .50), w * .34, stroke);
    c.drawLine(Offset(w * .50, h * .50), Offset(w * .50, h * .28), stroke);
    c.drawLine(Offset(w * .50, h * .50), Offset(w * .68, h * .50), stroke);
  }

  void _rules(Canvas c, double w, double h, Paint stroke, Paint fill) {
    c.drawLine(Offset(w * .20, h * .36), Offset(w * .80, h * .36), stroke);
    c.drawCircle(Offset(w * .40, h * .36), w * .07, fill);
    c.drawLine(Offset(w * .20, h * .64), Offset(w * .80, h * .64), stroke);
    c.drawCircle(Offset(w * .62, h * .64), w * .07, fill);
  }

  void _tuning(Canvas c, double w, double h, Paint stroke, Paint fill) {
    c.drawLine(Offset(w * .32, h * .20), Offset(w * .32, h * .80), stroke);
    c.drawCircle(Offset(w * .32, h * .42), w * .07, fill);
    c.drawLine(Offset(w * .68, h * .20), Offset(w * .68, h * .80), stroke);
    c.drawCircle(Offset(w * .68, h * .58), w * .07, fill);
  }

  void _reply(Canvas c, double w, double h, Paint stroke) {
    final p = Path()
      ..moveTo(w * .38, h * .30)
      ..lineTo(w * .20, h * .48)
      ..lineTo(w * .38, h * .66)
      ..moveTo(w * .20, h * .48)
      ..lineTo(w * .58, h * .48)
      ..arcToPoint(Offset(w * .78, h * .68), radius: Radius.circular(w * .20));
    c.drawPath(p, stroke);
  }

  void _bluetooth(Canvas c, double w, double h, Paint stroke) {
    final p = Path()
      ..moveTo(w * .32, h * .34)
      ..lineTo(w * .68, h * .68)
      ..lineTo(w * .50, h * .86)
      ..lineTo(w * .50, h * .14)
      ..lineTo(w * .68, h * .32)
      ..lineTo(w * .32, h * .66);
    c.drawPath(p, stroke);
  }

  void _browser(Canvas c, double w, double h, Paint stroke, Paint fill) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .16, h * .20, w * .68, h * .60),
      Radius.circular(w * .14),
    );
    c.drawRRect(r, stroke);
    c.drawLine(Offset(w * .16, h * .38), Offset(w * .84, h * .38), stroke);
    c.drawCircle(Offset(w * .28, h * .29), w * .035, fill);
    c.drawCircle(Offset(w * .38, h * .29), w * .035, fill);
  }

  void _linux(Canvas c, double w, double h, Paint stroke, Paint fill) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .18, h * .18, w * .64, h * .64),
      Radius.circular(w * .16),
    );
    c.drawRRect(r, stroke);
    final p = Path()
      ..moveTo(w * .32, h * .40)
      ..lineTo(w * .44, h * .50)
      ..lineTo(w * .32, h * .60);
    c.drawPath(p, stroke);
    c.drawLine(Offset(w * .52, h * .60), Offset(w * .68, h * .60), stroke);
  }

  void _notification(Canvas c, double w, double h, Paint stroke, Paint fill) {
    final p = Path()
      ..moveTo(w * .28, h * .66)
      ..lineTo(w * .72, h * .66)
      ..lineTo(w * .68, h * .42)
      ..arcToPoint(Offset(w * .32, h * .42), radius: Radius.circular(w * .18))
      ..close();
    c.drawPath(p, stroke);
    c.drawArc(
      Rect.fromCenter(center: Offset(w * .50, h * .68), width: w * .20, height: h * .16),
      0,
      3.14159,
      false,
      stroke,
    );
  }

  void _files(Canvas c, double w, double h, Paint stroke) {
    final p = Path()
      ..moveTo(w * .24, h * .18)
      ..lineTo(w * .56, h * .18)
      ..lineTo(w * .76, h * .38)
      ..lineTo(w * .76, h * .82)
      ..lineTo(w * .24, h * .82)
      ..close()
      ..moveTo(w * .56, h * .18)
      ..lineTo(w * .56, h * .38)
      ..lineTo(w * .76, h * .38);
    c.drawPath(p, stroke);
  }

  void _back(Canvas c, double w, double h, Paint stroke) {
    final p = Path()
      ..moveTo(w * .72, h * .50)
      ..lineTo(w * .25, h * .50)
      ..moveTo(w * .46, h * .31)
      ..lineTo(w * .25, h * .50)
      ..lineTo(w * .46, h * .69);
    c.drawPath(p, stroke);
  }

  void _chevronDown(Canvas c, double w, double h, Paint stroke) {
    final p = Path()
      ..moveTo(w * .28, h * .40)
      ..lineTo(w * .50, h * .62)
      ..lineTo(w * .72, h * .40);
    c.drawPath(p, stroke);
  }

  void _chevronUp(Canvas c, double w, double h, Paint stroke) {
    final p = Path()
      ..moveTo(w * .28, h * .60)
      ..lineTo(w * .50, h * .38)
      ..lineTo(w * .72, h * .60);
    c.drawPath(p, stroke);
  }

  void _statusOk(Canvas c, double w, double h, Paint stroke) {
    c.drawCircle(Offset(w * .50, h * .50), w * .34, stroke);
    final p = Path()
      ..moveTo(w * .34, h * .50)
      ..lineTo(w * .46, h * .62)
      ..lineTo(w * .66, h * .38);
    c.drawPath(p, stroke);
  }

  void _statusWarning(Canvas c, double w, double h, Paint stroke, Paint fill) {
    final p = Path()
      ..moveTo(w * .50, h * .18)
      ..lineTo(w * .82, h * .78)
      ..lineTo(w * .18, h * .78)
      ..close();
    c.drawPath(p, stroke);
    c.drawLine(Offset(w * .50, h * .40), Offset(w * .50, h * .58), stroke);
    c.drawCircle(Offset(w * .50, h * .68), w * .035, fill);
  }

  void _statusError(Canvas c, double w, double h, Paint stroke) {
    c.drawCircle(Offset(w * .50, h * .50), w * .34, stroke);
    c.drawLine(Offset(w * .36, h * .36), Offset(w * .64, h * .64), stroke);
    c.drawLine(Offset(w * .64, h * .36), Offset(w * .36, h * .64), stroke);
  }

  void _security(Canvas c, double w, double h, Paint stroke) {
    final p = Path()
      ..moveTo(w * .50, h * .16)
      ..lineTo(w * .78, h * .26)
      ..lineTo(w * .78, h * .52)
      ..quadraticBezierTo(w * .76, h * .74, w * .50, h * .84)
      ..quadraticBezierTo(w * .24, h * .74, w * .24, h * .52)
      ..lineTo(w * .24, h * .26)
      ..close();
    c.drawPath(p, stroke);
  }

  void _voice(Canvas c, double w, double h, Paint stroke) {
    final p = Path()
      ..moveTo(w * .24, h * .40)
      ..lineTo(w * .38, h * .40)
      ..lineTo(w * .52, h * .28)
      ..lineTo(w * .52, h * .72)
      ..lineTo(w * .38, h * .60)
      ..lineTo(w * .24, h * .60)
      ..close();
    c.drawPath(p, stroke);
    c.drawArc(
      Rect.fromCenter(center: Offset(w * .48, h * .50), width: w * .32, height: h * .36),
      -0.9,
      1.8,
      false,
      stroke,
    );
    c.drawArc(
      Rect.fromCenter(center: Offset(w * .48, h * .50), width: w * .52, height: h * .56),
      -0.9,
      1.8,
      false,
      stroke,
    );
  }

  void _memory(Canvas c, double w, double h, Paint stroke) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .26, h * .26, w * .48, h * .48),
      Radius.circular(w * .10),
    );
    c.drawRRect(r, stroke);
    for (double i = 0.38; i <= 0.62; i += 0.12) {
      c.drawLine(Offset(w * i, h * .14), Offset(w * i, h * .26), stroke);
      c.drawLine(Offset(w * i, h * .74), Offset(w * i, h * .86), stroke);
      c.drawLine(Offset(w * .14, h * i), Offset(w * .26, h * i), stroke);
      c.drawLine(Offset(w * .74, h * i), Offset(w * .86, h * i), stroke);
    }
  }

  void _cpu(Canvas c, double w, double h, Paint stroke, Paint fill) {
    final r = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * .24, h * .24, w * .52, h * .52),
      Radius.circular(w * .12),
    );
    c.drawRRect(r, stroke);
    c.drawRect(Rect.fromLTWH(w * .40, h * .40, w * .20, h * .20), fill);
    for (double i = 0.36; i <= 0.64; i += 0.14) {
      c.drawLine(Offset(w * i, h * .12), Offset(w * i, h * .24), stroke);
      c.drawLine(Offset(w * i, h * .76), Offset(w * i, h * .88), stroke);
      c.drawLine(Offset(w * .12, h * i), Offset(w * .24, h * i), stroke);
      c.drawLine(Offset(w * .76, h * i), Offset(w * .88, h * i), stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _NanoGlyphPainter oldDelegate) =>
      oldDelegate.type != type ||
      oldDelegate.color != color ||
      oldDelegate.sw != sw ||
      oldDelegate.glow != glow;
}
