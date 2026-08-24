import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/theme/nano_motion.dart';

/// Geometría de superficie óptica permitida en NanoAI (Regla 13).
enum NanoSurfaceGeometry { roundedRectangle, capsule, circle }

/// Superficie Óptica Central (NanoOpticalSurface).
/// Arquitectura multicapa:
/// 1. Sombra ambiental difusa + sombra de contacto
/// 2. Bisel metálico SweepGradient perimetral
/// 3. BackdropFilter blur
/// 4. Sustrato de vidrio blanco translúcido
/// 5. Refracción azul inferior derecha
/// 6. Refracción violeta lateral
/// 7. Reflejo especular blanco superior derecho
/// 8. Destello móvil opcional (_AnimatedReflection) + curva cáustica
/// 9. Borde óptico interior
/// 10. Respuesta elástica y háptica (escala + sombra + bisel + destello)
class NanoOpticalSurface extends StatefulWidget {
  const NanoOpticalSurface({
    super.key,
    required this.child,
    this.geometry = NanoSurfaceGeometry.roundedRectangle,
    this.borderRadius = NanoRadius.large, // 24.0 por defecto
    this.customBorderRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.blurSigma = 18.0,
    this.borderStrength = 1.0,
    this.reflectionStrength = 1.0,
    this.depth = 1.0,
    this.accent,
    this.isActive = false,
    this.hasBackdropBlur = true,
    this.reflectionController,
    this.specularDrift = 0.0,
    this.glassOpacityScale = 1.0,
    this.onTap,
    this.onLongPress,
    this.tilt = false,
    this.tiltIntensity = 0.035,
    this.autoReflect = false,
  });

  final Widget child;
  final NanoSurfaceGeometry geometry;
  final double borderRadius;
  final BorderRadius? customBorderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double blurSigma;
  final double borderStrength;
  final double reflectionStrength;
  final double depth;
  final Color? accent;
  final bool isActive;
  final bool hasBackdropBlur;
  final AnimationController? reflectionController;
  final double specularDrift;

  /// Escala la opacidad del sustrato de vidrio (cards laterales más
  /// transparentes que la hero). 1.0 = niveles de token originales.
  final double glassOpacityScale;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Inclina la superficie en 3D (rotationX/Y) siguiendo el puntero,
  /// imitando el giro de un panel de vidrio bajo la luz. Opt-in para no
  /// alterar cards estáticas por defecto.
  final bool tilt;

  /// Radiánes máximos de rotación en el borde (puntero en un extremo).
  final double tiltIntensity;

  /// Genera internamente un AnimationController en loop para el barrido
  /// especular ambiental (_AnimatedReflection), sin depender de un
  /// controller externo pasado por el padre. Opt-in.
  final bool autoReflect;

  @override
  State<NanoOpticalSurface> createState() => _NanoOpticalSurfaceState();
}

class _NanoOpticalSurfaceState extends State<NanoOpticalSurface>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  AnimationController? _ambientController;
  late Animation<double> _scaleAnimation;
  bool _isPointerInside = false;
  Alignment _pointerLight = Alignment.center;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: NanoMotionDurations.press,
    );
    _scaleAnimation =
        Tween<double>(begin: 1.0, end: NanoPressResponse.scaleDown).animate(
          CurvedAnimation(
            parent: _pressController,
            curve: NanoMotionCurves.press,
            reverseCurve: NanoMotionCurves.glassSpring,
          ),
        );

    // Barrido especular ambiental propio: al activar autoReflect la card
    // genera su propio AnimationController en loop (sin depender del padre),
    // replicando el destello de luz de las cards de inicio/modelos.
    if (widget.autoReflect) {
      _ambientController = AnimationController(
        vsync: this,
        duration: NanoMotionDurations.ambient,
      )..repeat();
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    _ambientController?.dispose();
    super.dispose();
  }

  /// Progreso normalizado del press: 0 reposo, 1 comprimido.
  double get _pressProgress {
    const span = 1.0 - NanoPressResponse.scaleDown;
    return ((1.0 - _scaleAnimation.value) / span).clamp(0.0, 1.0);
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _pressController.forward();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _pressController.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null || widget.onLongPress != null) {
      _pressController.reverse();
    }
  }

  void _handlePointerHover(PointerHoverEvent event) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox?.size;
    if (size == null || size.isEmpty) return;

    final nextLight = Alignment(
      (event.localPosition.dx / size.width * 2 - 1).clamp(-1.0, 1.0).toDouble(),
      (event.localPosition.dy / size.height * 2 - 1)
          .clamp(-1.0, 1.0)
          .toDouble(),
    );
    if (!_isPointerInside ||
        (nextLight.x - _pointerLight.x).abs() > 0.035 ||
        (nextLight.y - _pointerLight.y).abs() > 0.035) {
      setState(() {
        _isPointerInside = true;
        _pointerLight = nextLight;
      });
    }
  }

  void _handlePointerExit(PointerExitEvent _) {
    if (_isPointerInside) setState(() => _isPointerInside = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final isDark = colors is NanoDarkColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Resolución de radio según geometría
    final BorderRadius resolvedRadius;
    if (widget.geometry == NanoSurfaceGeometry.circle) {
      resolvedRadius = BorderRadius.circular(999);
    } else if (widget.geometry == NanoSurfaceGeometry.capsule) {
      resolvedRadius = BorderRadius.circular(100);
    } else {
      resolvedRadius =
          widget.customBorderRadius ??
          BorderRadius.circular(widget.borderRadius);
    }

    final effectiveAccent =
        widget.accent ??
        (widget.isActive
            ? (isDark ? colors.accent : colors.accentCyan)
            : (isDark ? colors.accent : colors.accentCyan));

    final Widget surface;
    if (widget.onTap != null || widget.onLongPress != null) {
      surface = GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap?.call();
        },
        onLongPress: () {
          HapticFeedback.mediumImpact();
          widget.onLongPress?.call();
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, _) {
            final pressed = reduceMotion ? 0.0 : _pressProgress;
            return Transform.scale(
              scale: reduceMotion ? 1.0 : _scaleAnimation.value,
              child: RepaintBoundary(
                child: _buildSurface(
                  colors,
                  isDark,
                  reduceMotion,
                  resolvedRadius,
                  effectiveAccent,
                  pressed,
                  _isPointerInside && !reduceMotion ? _pointerLight : null,
                ),
              ),
            );
          },
        ),
      );
    } else {
      surface = RepaintBoundary(
        child: _buildSurface(
          colors,
          isDark,
          reduceMotion,
          resolvedRadius,
          effectiveAccent,
          0.0,
          null,
        ),
      );
    }

    final Widget out;
    if (widget.tilt && _isPointerInside && !reduceMotion) {
      // Giro 3D del panel: rota hacia el puntero con perspectiva suave.
      // rotationY -x (se aleja a la derecha), rotationX +y (se inclina
      // hacia atrás arriba), como un vidrio siguiendo la luz.
      final tilt = Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..rotateY(-_pointerLight.x * widget.tiltIntensity)
        ..rotateX(_pointerLight.y * widget.tiltIntensity);
      out = Transform(
        transform: tilt,
        alignment: Alignment.center,
        child: surface,
      );
    } else {
      out = surface;
    }

    return MouseRegion(
      onHover: reduceMotion ? null : _handlePointerHover,
      onExit: _handlePointerExit,
      child: out,
    );
  }

  Widget _buildSurface(
    NanoColors colors,
    bool isDark,
    bool reduceMotion,
    BorderRadius resolvedRadius,
    Color effectiveAccent,
    double pressed,
    Alignment? pointerLight,
  ) {
    // Respuesta física del press (Regla 23): sombra -15%, bisel +7%,
    // destello desplazado 3–5px. Todo deriva del mismo _pressProgress.
    final shadowPressFactor =
        1.0 - (1.0 - NanoPressResponse.shadowScale) * pressed;
    final effectiveBorderStrength =
        widget.borderStrength * (1.0 + 0.07 * pressed);
    final effectiveSpecularDrift = widget.specularDrift + pressed * 0.015;

    // 1. Sombras multicapa (ambiental + contacto + resplandor sutil)
    final shadows = [
      BoxShadow(
        color: (isDark ? const Color(0xFF020711) : const Color(0xFF7F9AB5))
            .withValues(
              alpha: (isDark ? 0.40 : 0.08 * widget.depth) * shadowPressFactor,
            ),
        blurRadius: 32,
        spreadRadius: -6,
        offset: const Offset(0, 12),
      ),
      BoxShadow(
        color: effectiveAccent.withValues(
          alpha: (isDark ? 0.12 : 0.04) * widget.depth * shadowPressFactor,
        ),
        blurRadius: 24,
        spreadRadius: -5,
      ),
      if (widget.isActive)
        BoxShadow(
          color: effectiveAccent.withValues(
            alpha: (isDark ? 0.35 : 0.22) * shadowPressFactor,
          ),
          blurRadius: 20,
          spreadRadius: -2,
        ),
    ];

    // 2. Bisel perimetral continuo SweepGradient
    final borderGradient = SweepGradient(
      colors: isDark
          ? [
              Colors.white.withValues(alpha: 0.30 * effectiveBorderStrength),
              colors.metalSilver.withValues(
                alpha: 0.20 * effectiveBorderStrength,
              ),
              colors.accent.withValues(alpha: 0.50 * effectiveBorderStrength),
              colors.accentSky.withValues(
                alpha: 0.30 * effectiveBorderStrength,
              ),
              colors.accentLavender.withValues(
                alpha: 0.25 * effectiveBorderStrength,
              ),
              Colors.white.withValues(alpha: 0.30 * effectiveBorderStrength),
            ]
          : [
              Colors.white.withValues(alpha: 0.95 * effectiveBorderStrength),
              colors.metalSilver.withValues(
                alpha: 0.70 * effectiveBorderStrength,
              ),
              colors.iceReflection.withValues(
                alpha: 0.60 * effectiveBorderStrength,
              ),
              colors.accentCyan.withValues(
                alpha: 0.40 * effectiveBorderStrength,
              ),
              colors.accentLavender.withValues(
                alpha: 0.30 * effectiveBorderStrength,
              ),
              Colors.white.withValues(alpha: 0.95 * effectiveBorderStrength),
            ],
    );

    // 3. Sustrato de vidrio blanco translúcido (opacidad escalada por
    // glassOpacityScale: hero 1.0, laterales reducidas).
    final opacityScale = widget.glassOpacityScale;
    final glassBodyGradient = isDark
        ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.glass100.withValues(alpha: 0.85 * opacityScale),
              colors.glass200.withValues(alpha: 0.70 * opacityScale),
              colors.glass300.withValues(alpha: 0.55 * opacityScale),
              colors.glass400.withValues(alpha: 0.75 * opacityScale),
            ],
            stops: const [0.0, 0.32, 0.72, 1.0],
          )
        : LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: colors.glassOpaque * opacityScale),
              colors.glassSecondary.withValues(
                alpha: colors.glassStrong * opacityScale,
              ),
              colors.glassGraphite.withValues(
                alpha: colors.glassMedium * opacityScale,
              ),
              Colors.white.withValues(alpha: colors.glassStrong * opacityScale),
            ],
            stops: const [0.0, 0.32, 0.72, 1.0],
          );

    final effectiveReflectionController = widget.reflectionController ??
        (widget.autoReflect ? _ambientController : null);

    Widget opticalStack = Stack(
      fit: StackFit.passthrough,
      children: [
        // Sustrato translúcido
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: resolvedRadius,
              gradient: glassBodyGradient,
            ),
          ),
        ),

        // Refracción azul inferior derecha
        Positioned(
          right: -85,
          bottom: -75,
          child: IgnorePointer(
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    effectiveAccent.withValues(
                      alpha: (isDark ? 0.22 : 0.16) * widget.reflectionStrength,
                    ),
                    colors.accentBlue.withValues(
                      alpha: (isDark ? 0.12 : 0.08) * widget.reflectionStrength,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Refracción violeta lateral izquierda
        Positioned(
          left: -75,
          top: 60,
          child: IgnorePointer(
            child: Container(
              width: 145,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    colors.accentLavender.withValues(
                      alpha: (isDark ? 0.15 : 0.10) * widget.reflectionStrength,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Reflejo metálico blanco superior derecho
        Positioned(
          top: -90,
          right: -70,
          child: IgnorePointer(
            child: Container(
              width: 250,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(
                      alpha: (isDark ? 0.35 : 0.90) * widget.reflectionStrength,
                    ),
                    Colors.white.withValues(
                      alpha: (isDark ? 0.05 : 0.12) * widget.reflectionStrength,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Destello especular móvil + curva cáustica (luz líquida)
        if (effectiveReflectionController != null && !reduceMotion)
          Positioned.fill(
            child: _AnimatedReflection(
              controller: effectiveReflectionController,
              intensity: widget.reflectionStrength,
              specularDrift: effectiveSpecularDrift,
              warmColor: colors.warmReflection,
              cyanColor: colors.accentCyan,
            ),
          ),

        // Luz especular local: acompaña el puntero dentro del material sin
        // alterar texto, iconos o el layout de la pantalla.
        if (pointerLight != null)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: pointerLight,
                    radius: 0.72,
                    colors: [
                      Colors.white.withValues(alpha: isDark ? 0.14 : 0.26),
                      effectiveAccent.withValues(alpha: isDark ? 0.055 : 0.035),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.30, 1.0],
                  ),
                ),
              ),
            ),
          ),

        // Borde interior de precisión
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: resolvedRadius,
                border: Border.all(
                  width: 0.8,
                  color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.72),
                ),
              ),
            ),
          ),
        ),

        // Contenido del usuario con padding
        Container(
          width: widget.width,
          height: widget.height,
          padding: widget.padding,
          child: widget.child,
        ),
      ],
    );

    if (widget.hasBackdropBlur) {
      opticalStack = ClipRRect(
        borderRadius: resolvedRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: reduceMotion ? 0.0 : widget.blurSigma,
            sigmaY: reduceMotion ? 0.0 : widget.blurSigma,
          ),
          child: opticalStack,
        ),
      );
    } else {
      opticalStack = ClipRRect(
        borderRadius: resolvedRadius,
        child: opticalStack,
      );
    }

    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: resolvedRadius,
        boxShadow: shadows,
      ),
      child: Container(
        padding: const EdgeInsets.all(1.35), // Bisel continuo de 1.35px
        decoration: BoxDecoration(
          borderRadius: resolvedRadius,
          gradient: borderGradient,
        ),
        child: opticalStack,
      ),
    );
  }
}

/// Destello de luz móvil con traslación diagonal y gradiente blanco/cyan,
/// más una curva cáustica (pearl + warm + cyan edge) en fase desplazada.
class _AnimatedReflection extends StatelessWidget {
  final AnimationController controller;
  final double intensity;
  final double specularDrift;
  final Color warmColor;
  final Color cyanColor;

  const _AnimatedReflection({
    required this.controller,
    required this.intensity,
    this.specularDrift = 0.0,
    required this.warmColor,
    required this.cyanColor,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final t = Curves.easeInOutSine.transform(controller.value);
              final x =
                  (-constraints.maxWidth * 0.8 +
                      constraints.maxWidth * 1.8 * t) +
                  (specularDrift * constraints.maxWidth * 0.15);

              // Curva cáustica: misma inclinación, fase desplazada +0.35,
              // opacidad muy baja (luz interna del vidrio, no línea fija).
              final tCaustic = (t + 0.35) % 1.0;
              final xCaustic =
                  (-constraints.maxWidth * 0.8 +
                      constraints.maxWidth * 1.8 * tCaustic) +
                  (specularDrift * constraints.maxWidth * 0.15);

              Widget band(Widget child, double xOffset) {
                return Transform.translate(
                  offset: Offset(xOffset, 0),
                  child: Transform.rotate(
                    angle: -0.24,
                    child: Center(child: child),
                  ),
                );
              }

              return Stack(
                fit: StackFit.passthrough,
                children: [
                  // Banda especular ancha y suave
                  band(
                    Container(
                      width: 90,
                      height: constraints.maxHeight * 1.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.015 * intensity),
                            Colors.white.withValues(alpha: 0.20 * intensity),
                            cyanColor.withValues(alpha: 0.04 * intensity),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.30, 0.50, 0.62, 1.0],
                        ),
                      ),
                    ),
                    x,
                  ),
                  // Curva cáustica: pearl + warm + borde cyan, delgada
                  band(
                    Container(
                      width: 34,
                      height: constraints.maxHeight * 1.2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.05 * intensity),
                            warmColor.withValues(alpha: 0.07 * intensity),
                            cyanColor.withValues(alpha: 0.05 * intensity),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.35, 0.50, 0.65, 1.0],
                        ),
                      ),
                    ),
                    xCaustic,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
