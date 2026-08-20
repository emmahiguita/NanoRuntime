import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/nano_motion.dart';

/// Fondo ambiental dinámico de marca compartido por todas las pantallas nanoai.
///
/// Unifica el gradiente óptico + resplandores orbitales puros que respiran
/// sutilmente con física armónica y reaccionan al acento cromático activo,
/// garantizando máxima nitidez, colores puros y cero halos sucios en modo claro.
class NanoAmbientBackground extends StatefulWidget {
  final bool animated;
  final Color? activeAccent;

  const NanoAmbientBackground({
    super.key,
    this.animated = true,
    this.activeAccent,
  });

  @override
  State<NanoAmbientBackground> createState() => _NanoAmbientBackgroundState();
}

class _NanoAmbientBackgroundState extends State<NanoAmbientBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _orbitController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );

    if (widget.animated) {
      _orbitController.repeat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.animated && !_orbitController.isAnimating) {
        _orbitController.repeat();
      }
    } else {
      if (_orbitController.isAnimating) {
        _orbitController.stop();
      }
    }
  }

  @override
  void didUpdateWidget(covariant NanoAmbientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated != oldWidget.animated) {
      if (widget.animated) {
        _orbitController.repeat();
      } else {
        _orbitController.stop();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _orbitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;
    final reduceMotion = NanoMotion.reduceMotion(context);

    if (reduceMotion || !widget.animated) {
      return _buildStaticBackground(colors, isDark);
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _orbitController,
        builder: (context, _) {
          final t = _orbitController.value * 2 * math.pi;
          // Ondas de desfase armónico orbital
          final ox1 = math.sin(t) * 24.0;
          final oy1 = math.cos(t * 0.8) * 18.0;
          final ox2 = math.cos(t + 1.2) * 28.0;
          final oy2 = math.sin((t + 1.2) * 0.9) * 22.0;
          final ox3 = math.sin(t + 2.4) * 20.0;
          final oy3 = math.cos(t + 2.4) * 16.0;

          final activeColor = widget.activeAccent ?? (isDark ? colors.accent : colors.accentCyan);

          if (!isDark) {
            // Modo Claro: Canvas Blanco Hielo Puro + Resplandores Radiales Cristalinos
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFCFDFF),
                    Color(0xFFF6F9FD),
                    Color(0xFFF1F6FB),
                    Color(0xFFF8FAFD),
                  ],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Positioned(
                    left: -100 + ox1,
                    top: 140 + oy1,
                    child: const _Glow(
                      size: 420,
                      color: Color(0xFFC4B5FD), // Lavanda hielo puro
                      alpha: 0.16,
                    ),
                  ),
                  Positioned(
                    right: -100 + ox2,
                    top: 280 + oy2,
                    child: const _Glow(
                      size: 460,
                      color: Color(0xFF7DD3FC), // Cian celestial puro
                      alpha: 0.20,
                    ),
                  ),
                  Positioned(
                    left: 40 + ox3,
                    bottom: 60 + oy3,
                    child: const _Glow(
                      size: 380,
                      color: Color(0xFF93C5FD), // Azul zafiro suave
                      alpha: 0.14,
                    ),
                  ),
                  if (widget.activeAccent != null)
                    Positioned(
                      top: 180 + oy3,
                      right: 40 + ox1,
                      child: _Glow(
                        size: 300,
                        color: activeColor,
                        alpha: 0.15,
                      ),
                    ),
                ],
              ),
            );
          }

          // Modo Oscuro: Sustrato Deep Navy + Resplandores Vivos
          final gradient = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colors.bgTop,
              colors.bgMiddle,
              colors.bgBottom,
            ],
          );

          return DecoratedBox(
            decoration: BoxDecoration(gradient: gradient),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: -60 + oy1,
                  right: -110 + ox1,
                  child: _Glow(
                    size: 420,
                    color: Color.lerp(colors.nanoBlue, activeColor, 0.35)!,
                    alpha: 0.16,
                  ),
                ),
                Positioned(
                  bottom: -110 + oy2,
                  left: -160 + ox2,
                  child: _Glow(
                    size: 520,
                    color: Color.lerp(colors.nanoCyan, activeColor, 0.45)!,
                    alpha: 0.16,
                  ),
                ),
                if (widget.activeAccent != null)
                  Positioned(
                    top: 200 + oy3,
                    left: 40 + ox3,
                    child: _Glow(
                      size: 260,
                      color: widget.activeAccent!,
                      alpha: 0.08,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStaticBackground(NanoColors colors, bool isDark) {
    if (!isDark) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFCFDFF),
              Color(0xFFF6F9FD),
              Color(0xFFF1F6FB),
              Color(0xFFF8FAFD),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: -100,
              top: 160,
              child: _Glow(
                size: 400,
                color: Color(0xFFC4B5FD),
                alpha: 0.15,
              ),
            ),
            Positioned(
              right: -100,
              top: 300,
              child: _Glow(
                size: 440,
                color: Color(0xFF7DD3FC),
                alpha: 0.18,
              ),
            ),
          ],
        ),
      );
    }

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        colors.bgTop,
        colors.bgMiddle,
        colors.bgBottom,
      ],
    );

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: gradient),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -50,
              right: -100,
              child: _Glow(
                size: 400,
                color: colors.nanoBlue,
                alpha: 0.15,
              ),
            ),
            Positioned(
              bottom: -100,
              left: -150,
              child: _Glow(
                size: 500,
                color: colors.nanoCyan,
                alpha: 0.15,
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
