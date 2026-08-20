import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

/// Estados semánticos de la IA en NanoAI (Regla 23).
enum NanoOrbState {
  idle,
  working,
  searching,
  reasoning,
  listening,
  connecting,
  generating,
  complete,
  error,
}

/// Tamaños estandarizados del Orb (Regla 34).
enum NanoOrbSize {
  inline(20.0),
  status(36.0),
  assistant(64.0);

  final double dimension;
  const NanoOrbSize(this.dimension);
}

/// Widget NanoThinkingOrb: Indicador visual de estado de IA de precisión óptica.
/// Implementado con Canvas 2D y CustomPainter para máximo rendimiento y cero lag.
class NanoThinkingOrb extends StatefulWidget {
  const NanoThinkingOrb({
    super.key,
    this.state = NanoOrbState.idle,
    this.size = NanoOrbSize.status,
    this.customDimension,
    this.audioAmplitude = 0.0,
    this.onTap,
  });

  final NanoOrbState state;
  final NanoOrbSize size;
  final double? customDimension;

  /// Amplitud de audio real (0.0 a 1.0) para el estado `listening`.
  final double audioAmplitude;

  final VoidCallback? onTap;

  @override
  State<NanoThinkingOrb> createState() => _NanoThinkingOrbState();
}

class _NanoThinkingOrbState extends State<NanoThinkingOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _durationForState(widget.state),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant NanoThinkingOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _controller.duration = _durationForState(widget.state);
      if (widget.state == NanoOrbState.complete || widget.state == NanoOrbState.error) {
        _controller.forward(from: 0.0);
      } else if (!_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  Duration _durationForState(NanoOrbState state) {
    switch (state) {
      case NanoOrbState.idle:
        return const Duration(milliseconds: 3600);
      case NanoOrbState.working:
        return const Duration(milliseconds: 2200);
      case NanoOrbState.searching:
        return const Duration(milliseconds: 1800);
      case NanoOrbState.reasoning:
        return const Duration(milliseconds: 2400);
      case NanoOrbState.listening:
        return const Duration(milliseconds: 1400);
      case NanoOrbState.connecting:
        return const Duration(milliseconds: 2000);
      case NanoOrbState.generating:
        return const Duration(milliseconds: 1600);
      case NanoOrbState.complete:
        return const Duration(milliseconds: 900);
      case NanoOrbState.error:
        return const Duration(milliseconds: 800);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final dimension = widget.customDimension ?? widget.size.dimension;

    return Semantics(
      label: 'NanoAI Status: ${widget.state.name}',
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: dimension,
          height: dimension,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ThinkingOrbPainter(
                    progress: reduceMotion ? 0.5 : _controller.value,
                    state: widget.state,
                    colors: colors,
                    isDark: isDark,
                    audioAmplitude: widget.audioAmplitude,
                    reduceMotion: reduceMotion,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ThinkingOrbPainter extends CustomPainter {
  _ThinkingOrbPainter({
    required this.progress,
    required this.state,
    required this.colors,
    required this.isDark,
    required this.audioAmplitude,
    required this.reduceMotion,
  });

  final double progress;
  final NanoOrbState state;
  final NanoColors colors;
  final bool isDark;
  final double audioAmplitude;
  final bool reduceMotion;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) * 0.88;

    // Paleta de precisión óptica
    final cActive = isDark ? colors.accent : colors.accentCyan;
    final cSecondary = isDark ? colors.secondary : colors.accentBlue;
    final cTertiary = isDark ? colors.success : colors.accentMint;
    final cError = colors.danger;
    final cBase = isDark
        ? const Color(0xFF0F172A).withValues(alpha: 0.70)
        : const Color(0xFFEFF7FC).withValues(alpha: 0.85);

    // 1. Núcleo base translúcido con gradiente esférico
    final corePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.25),
        radius: 0.9,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: 0.18),
                cBase,
                colors.backgroundPrimary.withValues(alpha: 0.9),
              ]
            : [
                Colors.white.withValues(alpha: 0.95),
                const Color(0xFFF8FAFC),
                const Color(0xFFE2EDF8),
              ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, corePaint);

    // 2. Anillo de bisel exterior de titanio/cristal
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, radius * 0.06)
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.50 : 0.90),
          cActive.withValues(alpha: 0.40),
          cSecondary.withValues(alpha: 0.30),
          Colors.white.withValues(alpha: isDark ? 0.30 : 0.80),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, rimPaint);

    // 3. Renderizado de estado específico
    switch (state) {
      case NanoOrbState.idle:
        _paintIdle(canvas, center, radius, cActive, cSecondary);
        break;
      case NanoOrbState.working:
        _paintWorking(canvas, center, radius, cActive, cSecondary);
        break;
      case NanoOrbState.searching:
        _paintSearching(canvas, center, radius, cActive, cSecondary);
        break;
      case NanoOrbState.reasoning:
        _paintReasoning(canvas, center, radius, cActive, cSecondary, cTertiary);
        break;
      case NanoOrbState.listening:
        _paintListening(canvas, center, radius, cActive, cSecondary);
        break;
      case NanoOrbState.connecting:
        _paintConnecting(canvas, center, radius, cActive, cSecondary);
        break;
      case NanoOrbState.generating:
        _paintGenerating(canvas, center, radius, cActive, cSecondary, cTertiary);
        break;
      case NanoOrbState.complete:
        _paintComplete(canvas, center, radius, cTertiary);
        break;
      case NanoOrbState.error:
        _paintError(canvas, center, radius, cError);
        break;
    }

    // 4. Reflejo especular superior izquierdo (Gloss Highlight)
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        radius: 0.45,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.60 : 0.85),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.6));

    canvas.drawCircle(
      Offset(center.dx - radius * 0.28, center.dy - radius * 0.28),
      radius * 0.32,
      highlightPaint,
    );
  }

  void _paintIdle(Canvas canvas, Offset center, double radius, Color c1, Color c2) {
    final breath = math.sin(progress * math.pi * 2) * 0.08;
    final r = radius * (0.45 + breath);

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          c1.withValues(alpha: 0.45),
          c2.withValues(alpha: 0.15),
          c1.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: r * 1.6));

    canvas.drawCircle(center, r * 1.5, glowPaint);
    canvas.drawCircle(center, r * 0.8, Paint()..color = c1.withValues(alpha: 0.5));
  }

  void _paintWorking(Canvas canvas, Offset center, double radius, Color c1, Color c2) {
    const particleCount = 6;
    for (int i = 0; i < particleCount; i++) {
      final angle = (progress * math.pi * 2) + (i * (math.pi * 2 / particleCount));
      final orbitR = radius * (0.50 + 0.18 * math.sin(angle * 2));
      final x = center.dx + orbitR * math.cos(angle);
      final y = center.dy + orbitR * math.sin(angle);
      final pColor = i.isEven ? c1 : c2;

      final pPaint = Paint()
        ..color = pColor.withValues(alpha: 0.75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

      canvas.drawCircle(Offset(x, y), radius * 0.12, pPaint);
    }
  }

  void _paintSearching(Canvas canvas, Offset center, double radius, Color c1, Color c2) {
    final scanAngle = progress * math.pi * 2;
    final scanPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.12
      ..shader = SweepGradient(
        startAngle: scanAngle - 0.8,
        endAngle: scanAngle + 0.8,
        colors: [
          c1.withValues(alpha: 0.0),
          c1.withValues(alpha: 0.85),
          c2.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.65));

    canvas.drawCircle(center, radius * 0.65, scanPaint);
  }

  void _paintReasoning(Canvas canvas, Offset center, double radius, Color c1, Color c2, Color c3) {
    for (int i = 0; i < 3; i++) {
      final rot = (progress * math.pi * 2 * (i == 1 ? -1 : 1)) + (i * math.pi / 3);
      final r = radius * (0.35 + i * 0.18);
      final rect = Rect.fromCenter(
        center: center,
        width: r * 2 * (0.85 + 0.15 * math.sin(progress * math.pi * 2 + i)),
        height: r * 2 * (0.85 + 0.15 * math.cos(progress * math.pi * 2 + i)),
      );

      final bandPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.06
        ..color = (i == 0 ? c1 : (i == 1 ? c2 : c3)).withValues(alpha: 0.60);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rot);
      canvas.translate(-center.dx, -center.dy);
      canvas.drawOval(rect, bandPaint);
      canvas.restore();
    }
  }

  void _paintListening(Canvas canvas, Offset center, double radius, Color c1, Color c2) {
    final amp = (audioAmplitude.clamp(0.0, 1.0) * 0.40) + 0.15;
    final path = Path();
    const points = 32;

    for (int i = 0; i <= points; i++) {
      final theta = (i / points) * math.pi * 2;
      final wave = math.sin((theta * 4) + (progress * math.pi * 4)) * (radius * amp);
      final r = radius * 0.60 + wave;
      final x = center.dx + r * math.cos(theta);
      final y = center.dy + r * math.sin(theta);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final fillPaint = Paint()
      ..shader = RadialGradient(
        colors: [c1.withValues(alpha: 0.50), c2.withValues(alpha: 0.15)],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.8));

    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.07
      ..color = c1.withValues(alpha: 0.85);

    canvas.drawPath(path, strokePaint);
  }

  void _paintConnecting(Canvas canvas, Offset center, double radius, Color c1, Color c2) {
    const nodes = 5;
    final offsets = <Offset>[];

    for (int i = 0; i < nodes; i++) {
      final angle = (i * (math.pi * 2 / nodes)) + (progress * math.pi);
      final dist = radius * (0.35 + 0.25 * math.sin((progress * math.pi * 2) + i));
      offsets.add(Offset(center.dx + dist * math.cos(angle), center.dy + dist * math.sin(angle)));
    }

    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = c1.withValues(alpha: 0.35);

    for (int i = 0; i < nodes; i++) {
      final next = offsets[(i + 1) % nodes];
      canvas.drawLine(offsets[i], next, linePaint);
    }

    for (final node in offsets) {
      canvas.drawCircle(node, radius * 0.09, Paint()..color = c2.withValues(alpha: 0.85));
    }
  }

  void _paintGenerating(Canvas canvas, Offset center, double radius, Color c1, Color c2, Color c3) {
    const rays = 8;
    for (int i = 0; i < rays; i++) {
      final baseAngle = (i * (math.pi * 2 / rays)) + (progress * math.pi * 2);
      final rayLen = radius * (0.30 + 0.45 * math.cos((progress * math.pi * 3) + i).abs());
      final start = Offset(center.dx + radius * 0.2 * math.cos(baseAngle), center.dy + radius * 0.2 * math.sin(baseAngle));
      final end = Offset(center.dx + rayLen * math.cos(baseAngle), center.dy + rayLen * math.sin(baseAngle));

      final rayPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.06
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [c1.withValues(alpha: 0.9), c2.withValues(alpha: 0.1)],
        ).createShader(Rect.fromPoints(start, end));

      canvas.drawLine(start, end, rayPaint);
    }
  }

  void _paintComplete(Canvas canvas, Offset center, double radius, Color cSuccess) {
    final p = progress.clamp(0.0, 1.0);
    final checkRadius = radius * (0.4 + 0.2 * (1.0 - p));

    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.1
      ..color = cSuccess.withValues(alpha: 0.9);

    canvas.drawCircle(center, checkRadius, circlePaint);
    canvas.drawCircle(center, checkRadius * 0.5, Paint()..color = cSuccess.withValues(alpha: 0.35));
  }

  void _paintError(Canvas canvas, Offset center, double radius, Color cError) {
    final jitter = math.sin(progress * math.pi * 8) * (radius * 0.06);
    final errCenter = Offset(center.dx + jitter, center.dy);

    final errorPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.12
      ..color = cError.withValues(alpha: 0.85);

    canvas.drawCircle(errCenter, radius * 0.6, errorPaint);
  }

  @override
  bool shouldRepaint(covariant _ThinkingOrbPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.state != state ||
        oldDelegate.audioAmplitude != audioAmplitude ||
        oldDelegate.isDark != isDark;
  }
}
