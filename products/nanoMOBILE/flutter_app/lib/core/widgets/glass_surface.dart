import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nanoai/core/theme/design_tokens.dart';

/// Superficie de Vidrio Líquido hiperrealista estilo iOS (GlassSurface).
///
/// Inspirado en la arquitectura óptica nativa de `@rbayuokt/expo-adaptive-glass`
/// e iOS Liquid Glass:
/// 1. **BackdropFilter adaptativo**: Desenfoque óptico en tiempo real.
/// 2. **Doble control de apariencia**:
///    - `opacity`: Densidad y masa del sustrato vítreo (0.05 etéreo - 1.00 sólido).
///    - `clarity`: Transparencia y pureza estilo iOS (0.00 esmerilado mate - 1.00 cristalino puro).
/// 3. **Borde Fresnel perimetral**: Bisel cromático con refracción especular.
/// 4. **Respuesta interactiva táctil**: Micro-inclinación 3D en perspectiva,
///    desplazamiento especular dinámico (`specularDrift`) y resorte elástico iOS.
class GlassSurface extends StatefulWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.opacity = 0.70,
    this.clarity = 0.85,
    this.blur = 18.0,
    this.intensity = 0.65,
    this.tint,
    this.radius = 24.0,
    this.customBorderRadius,
    this.borderWidth = 1.2,
    this.interactive = true,
    this.tiltIntensity = 0.12,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.width,
    this.height,
    this.onTap,
  });

  final Widget child;

  /// Opacidad del sustrato vítreo (0.05 a 1.0).
  final double opacity;

  /// Claridad iOS (0.0 = Frosted/Esmerilado denso, 1.0 = Clear/Cristalino puro).
  final double clarity;

  /// Radio de desenfoque sigma de la capa de fondo.
  final double blur;

  /// Intensidad de los reflejos y destello especular (0.0 a 1.0).
  final double intensity;

  /// Tinte de color del vidrio. Si es null, utiliza la paleta dinámica iOS.
  final Color? tint;

  /// Radio de curvatura squircle de las esquinas.
  final double radius;

  /// Radio personalizado si no es uniforme.
  final BorderRadius? customBorderRadius;

  /// Grosor del borde perimetral refractivo.
  final double borderWidth;

  /// Habilitar respuesta táctil interactiva (inclinación 3D y brillo móvil).
  final bool interactive;

  /// Intensidad del micro-giro 3D al tocar o interactuar.
  final double tiltIntensity;

  /// Espaciado interno.
  final EdgeInsetsGeometry padding;

  /// Espaciado externo opcional.
  final EdgeInsetsGeometry? margin;

  final double? width;
  final double? height;

  /// Callback de toque con háptica iOS.
  final VoidCallback? onTap;

  @override
  State<GlassSurface> createState() => _GlassSurfaceState();
}

class _GlassSurfaceState extends State<GlassSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ambientReflectionController =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 3200),
      )..repeat();

  double _specularDriftX = 0.0;
  double _specularDriftY = 0.0;
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  bool _isPressed = false;

  @override
  void dispose() {
    _ambientReflectionController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent e) {
    if (!widget.interactive) return;
    _updatePointer(e.position);
    setState(() => _isPressed = true);
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!widget.interactive) return;
    _updatePointer(e.position);
  }

  void _onPointerUp(PointerUpEvent e) {
    if (!widget.interactive) return;
    _resetPointer();
  }

  void _onPointerCancel(PointerCancelEvent e) {
    if (!widget.interactive) return;
    _resetPointer();
  }

  void _updatePointer(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || box.size.isEmpty) return;
    final local = box.globalToLocal(globalPosition);
    final nx = (local.dx / box.size.width).clamp(0.0, 1.0);
    final ny = (local.dy / box.size.height).clamp(0.0, 1.0);

    setState(() {
      _specularDriftX = (nx - 0.5) * 0.7;
      _specularDriftY = (ny - 0.5) * 0.7;
      _tiltY = (nx - 0.5) * widget.tiltIntensity;
      _tiltX = -(ny - 0.5) * widget.tiltIntensity;
    });
  }

  void _resetPointer() {
    setState(() {
      _isPressed = false;
      _tiltX = 0.0;
      _tiltY = 0.0;
      _specularDriftX = 0.0;
      _specularDriftY = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = NanoThemeExtension.of(context);
    final colors = theme.colors;
    final isDark = colors is NanoDarkColors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final borderRadius =
        widget.customBorderRadius ?? BorderRadius.circular(widget.radius);

    // Ajuste dinámico de desenfoque según claridad y accesibilidad
    final effectiveBlur = reduceMotion
        ? 0.0
        : (widget.blur * (0.55 + 0.45 * (1.0 - widget.clarity * 0.35)))
            .clamp(0.0, 40.0);

    // Color base y sustrato translúcido (adaptativo iOS)
    final baseTint = widget.tint ?? (isDark ? const Color(0xFF0C1425) : Colors.white);
    final effectiveOpacity = widget.opacity.clamp(0.05, 1.0);
    final clarityFactor = widget.clarity.clamp(0.0, 1.0);

    // En iOS Liquid Glass, mayor claridad aumenta la transparencia del cuerpo
    // pero conserva la definición del borde y el brillo especular.
    final substrateAlpha = (isDark
            ? (0.35 + 0.55 * effectiveOpacity) * (1.15 - clarityFactor * 0.45)
            : (0.40 + 0.50 * effectiveOpacity) * (1.10 - clarityFactor * 0.35))
        .clamp(0.05, 0.96);

    final substrateEndAlpha = (substrateAlpha * 0.72).clamp(0.03, 0.90);

    // Sombras multicapa cinemáticas
    final shadows = <BoxShadow>[
      BoxShadow(
        color: (isDark ? Colors.black : const Color(0xFF0F172A)).withValues(
          alpha: (isDark ? 0.32 : 0.08) * (1.0 + (_isPressed ? -0.2 : 0.0)),
        ),
        blurRadius: _isPressed ? 14 : 28,
        spreadRadius: _isPressed ? -4 : -6,
        offset: Offset(0, _isPressed ? 6 : 14),
      ),
      if (widget.intensity > 0.1)
        BoxShadow(
          color: (widget.tint ?? colors.primary).withValues(
            alpha: (isDark ? 0.09 : 0.03) * widget.intensity,
          ),
          blurRadius: 20,
          spreadRadius: -4,
        ),
    ];

    // Bisel metálico perimetral con halo Fresnel
    final borderGradient = SweepGradient(
      center: Alignment(
        _specularDriftX.clamp(-1.0, 1.0),
        _specularDriftY.clamp(-1.0, 1.0),
      ),
      colors: isDark
          ? [
              Colors.white.withValues(alpha: 0.35 * widget.intensity),
              colors.accentSky.withValues(alpha: 0.28 * widget.intensity),
              colors.accentLavender.withValues(alpha: 0.20 * widget.intensity),
              Colors.white.withValues(alpha: 0.12 * widget.intensity),
              Colors.white.withValues(alpha: 0.35 * widget.intensity),
            ]
          : [
              Colors.white.withValues(alpha: 0.90 * widget.intensity),
              colors.metalSilver.withValues(alpha: 0.45 * widget.intensity),
              colors.accentCyan.withValues(alpha: 0.35 * widget.intensity),
              Colors.white.withValues(alpha: 0.60 * widget.intensity),
              Colors.white.withValues(alpha: 0.90 * widget.intensity),
            ],
    );

    Widget surface = AnimatedScale(
      scale: (_isPressed && widget.interactive && !reduceMotion) ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0013)
          ..rotateX(_tiltX)
          ..rotateY(_tiltY),
        child: Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            boxShadow: shadows,
          ),
          child: Container(
            padding: EdgeInsets.all(widget.borderWidth),
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: borderGradient,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                (widget.radius - widget.borderWidth).clamp(0.0, 999.0),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: effectiveBlur,
                  sigmaY: effectiveBlur,
                ),
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    // 1. Sustrato de vidrio con opacidad graduada
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              baseTint.withValues(alpha: substrateAlpha),
                              baseTint.withValues(alpha: substrateEndAlpha),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 2. Destello especular móvil interactivo (luz que sigue el toque)
                    if (widget.intensity > 0.05)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedBuilder(
                            animation: _ambientReflectionController,
                            builder: (context, _) {
                              final animProgress =
                                  reduceMotion ? 0.5 : _ambientReflectionController.value;
                              final sweepX = _isPressed
                                  ? _specularDriftX
                                  : (-1.0 + animProgress * 2.0);

                              return DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    center: Alignment(
                                      sweepX,
                                      _isPressed ? _specularDriftY : -0.7,
                                    ),
                                    radius: 1.1,
                                    colors: [
                                      Colors.white.withValues(
                                        alpha: (isDark ? 0.18 : 0.35) *
                                            widget.intensity *
                                            (0.4 + 0.6 * clarityFactor),
                                      ),
                                      Colors.white.withValues(alpha: 0.0),
                                    ],
                                    stops: const [0.0, 0.75],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                    // 3. Refracción cromática sutil en los extremos
                    Positioned(
                      top: -40,
                      right: -30,
                      child: IgnorePointer(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                (isDark ? colors.accentSky : colors.accentCyan)
                                    .withValues(
                                  alpha: (isDark ? 0.14 : 0.08) *
                                      widget.intensity *
                                      clarityFactor,
                                ),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 4. Contenido del hijo con padding
                    Padding(
                      padding: widget.padding,
                      child: widget.child,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    if (widget.onTap != null) {
      surface = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            widget.onTap?.call();
          },
          behavior: HitTestBehavior.opaque,
          child: surface,
        ),
      );
    }

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: surface,
    );
  }
}
