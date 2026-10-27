part of 'automation_visual_theme.dart';

/// Tarjeta de superficie de Automatización que delega en [GlassSurface]
/// universal para proporcionar el mismo efecto iOS Frosted Liquid Glass y
/// respuesta elástica en toda la aplicación.
class AutomationSurfaceCard extends StatelessWidget {
  const AutomationSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
    this.radius = 24,
    this.blurSigma = 18,
    this.surfaceTint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final double blurSigma;

  /// Tinte opcional del inicio; conserva la paleta de las demás pantallas.
  final Color? surfaceTint;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return GlassSurface(
      radius: radius,
      blur: blurSigma,
      padding: padding,
      tint: surfaceTint ?? visual.resolvedColors.surface,
      onTap: onTap,
      child: child,
    );
  }
}

class AutomationSectionLabel extends StatelessWidget {
  const AutomationSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8, top: 12),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: 'Inter',
          color: visual.textMuted.withValues(alpha: 0.88),
          fontSize: 11.0,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Marca NANO AI única del módulo (DRY): 'NANO ' en color de texto, 'AI' en
/// accent.
class AutomationBrand extends StatelessWidget {
  const AutomationBrand({super.key, this.fontSize = 23, this.letterSpacing = 1.6});

  final double fontSize;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontFamily: 'Inter',
          color: visual.text,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: letterSpacing,
        ),
        children: [
          const TextSpan(text: 'NANO '),
          TextSpan(
            text: 'AI',
            style: TextStyle(color: NanoTextColors.forText(visual.accent, visual.resolvedColors)),
          ),
        ],
      ),
    );
  }
}

/// Cabecera de sub-pantalla del módulo: 52px, botón atrás a la izquierda y
/// marca alineada al inicio.
class AutomationBackHeader extends StatelessWidget {
  const AutomationBackHeader({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Semantics(
            label: 'Atrás',
            button: true,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 24),
            ),
          ),
          const AutomationBrand(),
          const Spacer(),
        ],
      ),
    );
  }
}

/// Fondo compartido del módulo — fondo de pantalla celestial del Búho en
/// vertical con gradiente scrim para contraste y legibilidad óptima.
class AutomationBackdrop extends StatelessWidget {
  const AutomationBackdrop({super.key, this.scrimOpacity, this.useImage = false});

  final double? scrimOpacity;
  final bool useImage;

  @override
  Widget build(BuildContext context) {
    if (!useImage) {
      return const BuhoWallpaper(useImage: false);
    }

    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (landscape) {
      return BuhoWallpaper(scrimOpacity: scrimOpacity, useImage: true);
    }

    final baseScrim = isDark ? 0.35 : 0.52;
    final scrim = scrimOpacity ?? baseScrim;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/automation/automation_bg_portrait.jpg',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [
                      Colors.black.withValues(alpha: (scrim * 1.5).clamp(0.0, 1.0)),
                      Colors.black.withValues(alpha: (scrim * 0.9).clamp(0.0, 1.0)),
                      Colors.black.withValues(alpha: (scrim * 1.6).clamp(0.0, 1.0)),
                    ]
                  : [
                      const Color(0xFFE2E8F0).withValues(alpha: 0.85),
                      const Color(0xFFF1F5F9).withValues(alpha: 0.75),
                      const Color(0xFFCBD5E1).withValues(alpha: 0.90),
                    ],
              stops: const [0.0, 0.40, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
