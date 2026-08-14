import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Componentes de animación viva compartidos por Chat y Modelos.
///
/// Reglas de consumo mínimo (móvil con inferencia local):
/// - Solo animan ESTADOS e interacciones, nunca mueven la pantalla entera.
/// - Todas respetan `MediaQuery.disableAnimationsOf` (accesibilidad).
/// - Los controllers son tickers vsync: sin frames programados no corren
///   (app en segundo plano = animaciones efectivamente detenidas).

/// Entrada fade + slide de un mensaje nuevo.
///
/// Usar con `key: ValueKey(message.id)`: la animación corre una sola vez
/// por mensaje; los rebuilds del streaming no la reinician.
class AnimatedMessageEntry extends StatelessWidget {
  const AnimatedMessageEntry({
    super.key,
    required this.child,
    required this.isUser,
  });

  final Widget child;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (reduceMotion) return child;

    return TweenAnimationBuilder<double>(
      key: key,
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final horizontalDirection = isUser ? 12.0 : -12.0;

        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(horizontalDirection * (1 - value), 6 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Cursor respirando al final del texto durante la generación streaming.
class StreamingCursor extends StatefulWidget {
  const StreamingCursor({super.key});

  @override
  State<StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<StreamingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    )..repeat(reverse: true);

    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const _CursorShape();
    }

    return FadeTransition(opacity: _opacity, child: const _CursorShape());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _CursorShape extends StatelessWidget {
  const _CursorShape();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 17,
      margin: const EdgeInsets.only(left: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF21F2B2),
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF21F2B2).withValues(alpha: 0.55),
            blurRadius: 7,
          ),
        ],
      ),
    );
  }
}

/// Indicador de "pensando" con tres puntos en onda. Se muestra mientras el
/// modelo genera y aún no hay texto streaming.
class ThinkingIndicator extends StatefulWidget {
  const ThinkingIndicator({super.key});

  @override
  State<ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final phase = (_controller.value - index * 0.16) % 1.0;
            final wave = reduceMotion
                ? 0.5
                : (1 - (phase * 2 - 1).abs()).clamp(0.0, 1.0);

            return Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              transform: Matrix4.translationValues(0, -3 * wave, 0),
              decoration: BoxDecoration(
                color: Color.lerp(
                  Colors.white.withValues(alpha: 0.32),
                  const Color(0xFF21F2B2),
                  wave,
                ),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Flotación vertical mínima (±2px) para el icono del modelo activo.
/// Envuelve el icono existente — no define su apariencia.
class FloatingModelIcon extends StatefulWidget {
  const FloatingModelIcon({
    super.key,
    required this.active,
    required this.child,
  });

  final bool active;
  final Widget child;

  @override
  State<FloatingModelIcon> createState() => _FloatingModelIconState();
}

class _FloatingModelIconState extends State<FloatingModelIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _movement;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _movement = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.active) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant FloatingModelIcon oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.active && !oldWidget.active) {
      _controller.repeat(reverse: true);
    } else if (!widget.active && oldWidget.active) {
      _controller.stop();
      _controller.value = 0.5;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (!widget.active || reduceMotion) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _movement,
      builder: (_, child) {
        return Transform.translate(
          offset: Offset(0, _movement.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Borde degradado giratorio + resplandor respirando para la tarjeta activa.
/// Un solo controller sirve ambos efectos: el degradado rota y la sombra
/// exterior respira con la misma fase (sin controllers extra por tarjeta).
class AnimatedActiveBorder extends StatefulWidget {
  const AnimatedActiveBorder({
    super.key,
    required this.active,
    required this.child,
    this.borderRadius = 19,
  });

  final bool active;
  final Widget child;
  final double borderRadius;

  @override
  State<AnimatedActiveBorder> createState() => _AnimatedActiveBorderState();
}

class _AnimatedActiveBorderState extends State<AnimatedActiveBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    if (widget.active) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedActiveBorder oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.active && !oldWidget.active) {
      _controller.repeat();
    } else if (!widget.active && oldWidget.active) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    if (!widget.active || reduceMotion) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        // Respiración de la iluminación: fase sinusoidal 0..1 sobre la
        // misma rotación (misma señal, distintos mapeos).
        final breath = 0.5 + 0.5 * math.sin(_controller.value * 2 * math.pi);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: SweepGradient(
              transform: GradientRotation(_controller.value * 2 * math.pi),
              colors: const [
                Color(0xFF21F2B2),
                Color(0x3342D9FF),
                Color(0xFF42D9FF),
                Color(0x3321F2B2),
                Color(0xFF21F2B2),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF21F2B2,
                ).withValues(alpha: 0.10 + breath * 0.14),
                blurRadius: 22,
              ),
            ],
          ),
          padding: const EdgeInsets.all(1.2),
          child: child,
        );
      },
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Respuesta táctil de botones: presión 1.0 → 0.97 con rebote suave.
/// Usa Listener (no GestureDetector): no compite por el gesto del botón.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.pressedScale = 0.97,
  });

  final Widget child;
  final double pressedScale;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }

    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
