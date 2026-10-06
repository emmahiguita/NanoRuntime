// nano_border_beam.dart — Widget envolvente de haz perimetral interactivo.
// QUÉ HACE: Envuelve tarjetas, botones o modales y proyecta el haz de luz de Libraries.dev alrededor de su contorno.
// CÓMO FUNCIONA: Controla el ciclo con AnimationController, gestiona el ciclo de vida de la app y respeta reducción de movimiento.
// POR QUÉ: Otorga un acabado hiper-profesional sin recargar el hilo principal de renderizado (< 130 líneas).
library;

import 'package:flutter/material.dart';
import 'nano_border_beam_painter.dart';
import 'nano_border_beam_theme.dart';

class NanoBorderBeam extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final Duration duration;
  final NanoBorderBeamMode mode;
  final NanoBorderBeamPalette palette;
  final double borderWidth;
  final double borderRadius;
  final double beamLengthFraction;
  final double strength;

  const NanoBorderBeam({
    super.key,
    required this.child,
    this.enabled = true,
    this.duration = const Duration(seconds: 4),
    this.mode = NanoBorderBeamMode.rotate,
    this.palette = NanoBorderBeamPalette.colorful,
    this.borderWidth = 1.8,
    this.borderRadius = 16.0,
    this.beamLengthFraction = 0.35,
    this.strength = 1.0,
  });

  @override
  State<NanoBorderBeam> createState() => _NanoBorderBeamState();
}

class _NanoBorderBeamState extends State<NanoBorderBeam>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  bool _isForeground = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    WidgetsBinding.instance.addObserver(this);
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant NanoBorderBeam oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.enabled != widget.enabled) {
      if (widget.enabled && _isForeground) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForeground = state == AppLifecycleState.resumed;
    if (_isForeground && widget.enabled) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      if (_controller.isAnimating) _controller.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnim = MediaQuery.disableAnimationsOf(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        if (widget.enabled && !disableAnim)
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: NanoBorderBeamPainter(
                      progress: _controller.value,
                      mode: widget.mode,
                      palette: widget.palette,
                      borderWidth: widget.borderWidth,
                      borderRadius: widget.borderRadius,
                      beamLengthFraction: widget.beamLengthFraction,
                      strength: widget.strength,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
