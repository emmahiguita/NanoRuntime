part of 'glass_surface.dart';

/// Capas ópticas sin temporizadores: desenfoque recortado, tinte translúcido,
/// borde de luz y contenido. Nunca aplica Opacity al texto ni a los controles.
class _GlassSurfaceBody extends StatelessWidget {
  const _GlassSurfaceBody({required this.widget, required this.light});
  final GlassSurface widget;
  final Offset light;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = NanoThemeExtension.of(context);
    final dark = theme.brightness == Brightness.dark;
    final glass = settings.glassEnabled;
    final radius =
        widget.customBorderRadius ?? BorderRadius.circular(widget.radius);
    final clarity = (settings.glassClarity * widget.clarity / .85).clamp(
      0.0,
      1.0,
    );
    final density =
        (settings.glassOpacity * widget.opacity / .70 * widget.opacityScale)
            .clamp(.05, 1.0);
    // La densidad regula el material; aún al máximo conserva transparencia iOS.
    // Desactivar cristal sí ofrece una superficie sólida accesible.
    final alpha = glass
        ? ((dark ? .26 : .30) + density * .38 - clarity * .10).clamp(.16, .78)
        : 1.0;
    final tint = widget.tint ?? theme.colorScheme.surface;
    final sigma = glass && widget.hasBackdropBlur
        ? (settings.glassBlur * widget.blur / 18 * (1.20 - clarity * .22))
              .clamp(0.0, 42.0)
        : 0.0;
    final strength = widget.intensity.clamp(0.0, 1.5);
    Widget body = Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  tint.withValues(alpha: alpha),
                  tint.withValues(
                    alpha: glass ? (alpha * .80).clamp(.10, .76) : 1,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (glass && strength > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(
                      (light.dx + widget.specularDrift).clamp(-1, 1),
                      light == Offset.zero ? -.88 : light.dy,
                    ),
                    radius: 1.45,
                    colors: [
                      Colors.white.withValues(
                        alpha: (dark ? .15 : .34) * strength,
                      ),
                      Colors.white.withValues(alpha: 0),
                    ],
                    stops: const [0, 1],
                  ),
                ),
              ),
            ),
          ),
        Padding(padding: widget.padding, child: widget.child),
      ],
    );
    if (sigma > 0) {
      body = BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: body,
      );
    }
    // El borde ocupa pintura, no espacio extra: no altera métricas de listas.
    body = ClipRRect(borderRadius: radius, child: body);
    return Container(
      width: widget.width,
      height: widget.height,
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: widget.depth <= 0
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .22 : .08),
                  blurRadius: 20 * widget.depth.clamp(0, 2),
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(
            width: widget.borderWidth.clamp(0.0, 3.0),
            color: widget.isActive
                ? theme.colorScheme.primary.withValues(alpha: .65)
                : (dark ? Colors.white : theme.colorScheme.outline).withValues(
                    alpha: dark ? .22 : .26,
                  ),
          ),
        ),
        child: body,
      ),
    );
  }
}
