import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/nano_motion.dart';
import 'nano_background_controller.dart';
import 'nano_shader_host.dart';

/// Superficie viva Liquid Glass 3D que renderiza el fondo procedural en GPU.
///
/// Ocupa el 100% de la pantalla física de borde a borde (Edge-to-Edge),
/// sin insets ni recortes, respondiendo al tacto y la inercia con física fluida.
class NanoLivingBackground extends StatefulWidget {
  final bool animated;
  final Color? activeAccent;
  final NanoBackgroundController? controller;

  const NanoLivingBackground({
    super.key,
    this.animated = true,
    this.activeAccent,
    this.controller,
  });

  @override
  State<NanoLivingBackground> createState() => _NanoLivingBackgroundState();
}

class _NanoLivingBackgroundState extends State<NanoLivingBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _timeController;
  late final NanoBackgroundController _controller;
  bool _ownsController = false;
  FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = NanoBackgroundController();
      _ownsController = true;
    }

    _timeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    );

    _shader = NanoShaderHost.createLivingShader();

    if (widget.animated) {
      _timeController.repeat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.animated && !_timeController.isAnimating) {
        _timeController.repeat();
      }
    } else {
      if (_timeController.isAnimating) {
        _timeController.stop();
      }
    }
  }

  @override
  void didUpdateWidget(covariant NanoLivingBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated != oldWidget.animated) {
      if (widget.animated) {
        _timeController.repeat();
      } else {
        _timeController.stop();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timeController.dispose();
    _shader?.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent e) {
    _controller.onPointerDown(e.position);
  }

  void _onPointerMove(PointerMoveEvent e) {
    _controller.onPointerMove(e.position);
  }

  void _onPointerUp(PointerUpEvent e) {
    _controller.onPointerUp();
  }

  void _onPointerHover(PointerEvent e) {
    _controller.onPointerMove(e.position);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final reduceMotion = NanoMotion.reduceMotion(context);

    _shader ??= NanoShaderHost.createLivingShader();

    if (reduceMotion || !widget.animated) {
      return _buildStaticFallback(colors);
    }

    return RepaintBoundary(
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: (_) => _controller.onPointerUp(),
        child: MouseRegion(
          onHover: _onPointerHover,
          child: AnimatedBuilder(
            animation: Listenable.merge([_timeController, _controller]),
            builder: (context, _) {
              _controller.tickDecay();

              if (_shader != null) {
                return CustomPaint(
                  painter: NanoLivingBackgroundPainter(
                    shader: _shader!,
                    time: _timeController.value * 60.0,
                    pointer: _controller.pointerPosition,
                    pointerVelocity: _controller.pointerVelocity,
                    pointerEnergy: _controller.pointerEnergy,
                    systemEnergy: _controller.systemEnergy,
                    qualityLevel: _controller.qualityLevel,
                    colors: colors,
                    accentPrimary: widget.activeAccent ?? colors.accentCyan,
                    accentSecondary: colors.accentLavender,
                  ),
                  size: Size.infinite,
                );
              }

              // Fallback armónico de alta fidelidad si el dispositivo no soporta shaders
              return _buildHarmonicFallback(colors);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHarmonicFallback(NanoColors colors) {
    final t = _timeController.value * 2 * math.pi;
    final ox1 = math.sin(t) * 26.0;
    final oy1 = math.cos(t * 0.8) * 20.0;
    final ox2 = math.cos(t + 1.2) * 30.0;
    final oy2 = math.sin((t + 1.2) * 0.9) * 24.0;
    final activeColor = widget.activeAccent ?? colors.accentCyan;

    return ColoredBox(
      color: const Color(0xFF030712),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -60 + oy1,
            right: -110 + ox1,
            child: _HarmonicGlow(
              size: 440,
              color: Color.lerp(const Color(0xFF0A2540), activeColor, 0.35)!,
              alpha: 0.40,
            ),
          ),
          Positioned(
            bottom: -110 + oy2,
            left: -160 + ox2,
            child: _HarmonicGlow(
              size: 540,
              color: Color.lerp(const Color(0xFF00D2FF), activeColor, 0.45)!,
              alpha: 0.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticFallback(NanoColors colors) {
    return const RepaintBoundary(
      child: ColoredBox(
        color: Color(0xFF030712),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -50,
              right: -100,
              child: _HarmonicGlow(
                size: 400,
                color: Color(0xFF0A2540),
                alpha: 0.35,
              ),
            ),
            Positioned(
              bottom: -100,
              left: -150,
              child: _HarmonicGlow(
                size: 500,
                color: Color(0xFF00D2FF),
                alpha: 0.30,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HarmonicGlow extends StatelessWidget {
  const _HarmonicGlow({
    required this.size,
    required this.color,
    required this.alpha,
  });

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
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: alpha * 0.4),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}
