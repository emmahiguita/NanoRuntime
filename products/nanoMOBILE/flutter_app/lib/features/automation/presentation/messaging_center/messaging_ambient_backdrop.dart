import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// Cabecera atmosférica acotada: paisaje, nubes multicapa y fundido a la lista.
class MessagingAmbientBackdrop extends StatefulWidget {
  final bool isDark;

  const MessagingAmbientBackdrop({super.key, required this.isDark});

  @override
  State<MessagingAmbientBackdrop> createState() =>
      _MessagingAmbientBackdropState();
}

class _MessagingAmbientBackdropState extends State<MessagingAmbientBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _atmosphereController;

  @override
  void initState() {
    super.initState();
    _atmosphereController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 48),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _atmosphereController
        ..stop()
        ..value = 0.36;
    } else if (!_atmosphereController.isAnimating) {
      _atmosphereController.repeat();
    }
  }

  @override
  void dispose() {
    _atmosphereController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final headerHeight = landscape
                ? 238.0
                : (constraints.maxWidth * 0.86).clamp(300.0, 366.0);
            final fadeColor = widget.isDark
                ? const Color(0xFF09111F)
                : const Color(0xFFF8FAFC);

            return Align(
              alignment: Alignment.topCenter,
              child: RepaintBoundary(
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: headerHeight,
                  child: ClipRect(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/automation/messaging_ice_header.png',
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          color: widget.isDark
                              ? const Color(0xFF0F172A).withValues(alpha: 0.48)
                              : Colors.white.withValues(alpha: 0.03),
                          colorBlendMode: widget.isDark
                              ? BlendMode.multiply
                              : BlendMode.screen,
                        ),
                        AnimatedBuilder(
                          animation: _atmosphereController,
                          builder: (context, _) {
                            final phase =
                                _atmosphereController.value * math.pi * 2;
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                _CloudLayer(
                                  phase: phase,
                                  phaseOffset: 0.4,
                                  horizontalTravel:
                                      constraints.maxWidth * 0.055,
                                  verticalTravel: 4,
                                  scale: 1.42,
                                  opacity: widget.isDark ? 0.10 : 0.20,
                                  blurSigma: 2.2,
                                  alignment: Alignment.topCenter,
                                ),
                                _CloudLayer(
                                  phase: phase * 0.72,
                                  phaseOffset: 2.25,
                                  horizontalTravel:
                                      constraints.maxWidth * 0.085,
                                  verticalTravel: 7,
                                  scale: 1.27,
                                  opacity: widget.isDark ? 0.13 : 0.27,
                                  blurSigma: 0.8,
                                  alignment: const Alignment(0, 0.05),
                                  flipHorizontally: true,
                                ),
                                _CloudLayer(
                                  phase: phase * 0.46,
                                  phaseOffset: 4.1,
                                  horizontalTravel: constraints.maxWidth * 0.12,
                                  verticalTravel: 5,
                                  scale: 1.58,
                                  opacity: widget.isDark ? 0.08 : 0.17,
                                  blurSigma: 3.6,
                                  alignment: Alignment.bottomCenter,
                                ),
                              ],
                            );
                          },
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: const [0.0, 0.50, 0.78, 1.0],
                              colors: [
                                fadeColor.withValues(alpha: 0.00),
                                fadeColor.withValues(alpha: 0.025),
                                fadeColor.withValues(alpha: 0.52),
                                fadeColor,
                              ],
                            ),
                          ),
                        ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(
                                  alpha: widget.isDark ? 0.02 : 0.14,
                                ),
                                Colors.transparent,
                                const Color(0xFFBFDBFE).withValues(
                                  alpha: widget.isDark ? 0.025 : 0.07,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CloudLayer extends StatelessWidget {
  final double phase;
  final double phaseOffset;
  final double horizontalTravel;
  final double verticalTravel;
  final double scale;
  final double opacity;
  final double blurSigma;
  final Alignment alignment;
  final bool flipHorizontally;

  const _CloudLayer({
    required this.phase,
    required this.phaseOffset,
    required this.horizontalTravel,
    required this.verticalTravel,
    required this.scale,
    required this.opacity,
    required this.blurSigma,
    required this.alignment,
    this.flipHorizontally = false,
  });

  @override
  Widget build(BuildContext context) {
    final wave = phase + phaseOffset;
    final dx = math.sin(wave) * horizontalTravel;
    final dy = math.cos(wave * 0.63) * verticalTravel;
    final breathingScale = scale + (math.sin(wave * 0.41) * 0.025);

    Widget cloud = Image.asset(
      'assets/automation/messaging_cloud_overlay.png',
      fit: BoxFit.cover,
      alignment: alignment,
      filterQuality: FilterQuality.medium,
    );

    if (blurSigma > 0) {
      cloud = ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
          tileMode: TileMode.decal,
        ),
        child: cloud,
      );
    }

    cloud = Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..scaleByDouble(
          flipHorizontally ? -breathingScale : breathingScale,
          breathingScale,
          1,
          1,
        ),
      child: cloud,
    );

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Opacity(opacity: opacity, child: cloud),
    );
  }
}
