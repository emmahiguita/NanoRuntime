import 'dart:ui';
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../theme/nano_type.dart';
import 'nano_optical_surface.dart';

export 'nano_optical_surface.dart';

/// ── Componentes de tema compartidos ──
///
/// Cada componente inyecta TIPOGRAFÍA (NanoType) y COLORES (NanoColors)
/// desde el tema activo: una pantalla que los usa queda automáticamente
/// correcta en modo claro y oscuro, sin TextStyle crudos ni hex sueltos.

/// Tarjeta de superficie con glassmorphism óptico y bisel metálico perimetral.
class NanoCard extends StatelessWidget {
  const NanoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NanoSpacing.md),
    this.margin,
    this.onTap,
    this.highlight = false,
    this.borderRadius = NanoRadius.large,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final bool highlight;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return NanoOpticalSurface(
      borderRadius: borderRadius,
      margin: margin,
      padding: padding,
      isActive: highlight,
      onTap: onTap,
      child: child,
    );
  }
}

/// Encabezado de sección: icono dentro de un contenedor tintado + título
/// (NanoType.title) + subtítulo opcional (NanoType.caption).
class NanoSectionHeader extends StatelessWidget {
  const NanoSectionHeader(
    this.title,
    this.icon, {
    super.key,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Padding(
      padding: const EdgeInsets.only(bottom: NanoSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: NanoShapes.small,
            ),
            child: Icon(icon, size: NanoIcons.medium, color: colors.primary),
          ),
          const SizedBox(width: NanoSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: NanoType.title(colors.onSurface)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: NanoType.caption(colors.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Píldora de estado con semántica de color (no hex sueltos).
/// `kind` mapea a los tokens: success/warning/danger/info/accent/neutral.
class NanoBadge extends StatelessWidget {
  const NanoBadge(
    this.label, {
    super.key,
    this.kind = BadgeKind.neutral,
    this.dot = true,
  });

  final String label;
  final BadgeKind kind;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final tint = switch (kind) {
      BadgeKind.success => colors.success,
      BadgeKind.warning => colors.warning,
      BadgeKind.danger => colors.danger,
      BadgeKind.info => colors.info,
      BadgeKind.accent => colors.accent,
      BadgeKind.neutral => colors.onSurfaceVariant,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: NanoShapes.full,
        border: Border.all(color: tint.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(label, style: NanoType.overline(tint)),
        ],
      ),
    );
  }
}

enum BadgeKind { success, warning, danger, info, accent, neutral }

/// Número de métrica grande (RAM, temperatura, batería, etc.) con
/// NanoType.metric y unidad opcional en caption.
class NanoMetricText extends StatelessWidget {
  const NanoMetricText(
    this.value, {
    super.key,
    this.unit,
    this.color,
  });

  final String value;
  final String? unit;
  /// Tinte opcional del número; por defecto onSurface.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: NanoType.metric(color ?? colors.onSurface),
        ),
        if (unit != null) ...[
          const SizedBox(width: 3),
          Text(
            unit!,
            style: NanoType.caption(colors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Botón de acción estandarizado: primario (relleno) u outline, con icono
/// opcional y texto siempre en NanoType.label. Los colores de fondo/texto
/// siguen la convención del theme (negro sobre verde neón en oscuro,
/// blanco sobre esmeralda en claro).
class NanoActionButton extends StatelessWidget {
  const NanoActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
    this.expanded = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final labelStyle = primary
        ? NanoType.label(
            colors is NanoDarkColors ? const Color(0xFF000000) : Colors.white)
        : NanoType.label(colors.primary);

    final button = primary
        ? ElevatedButton.icon(
            onPressed: onPressed,
            icon: icon != null ? Icon(icon, size: NanoIcons.small) : null,
            label: Text(label, style: labelStyle),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: icon != null ? Icon(icon, size: NanoIcons.small) : null,
            label: Text(label, style: labelStyle),
          );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Elemento para el carrusel
class CarouselItem {
  final String imageUrl;
  final String title;
  final String? subtitle;

  const CarouselItem({
    required this.imageUrl,
    required this.title,
    this.subtitle,
  });
}

/// Tarjeta tipo Carrusel con imágenes y texto, usando Material 3 Expressive
class NanoCarouselCard extends StatefulWidget {
  final List<CarouselItem> items;
  final double height;

  const NanoCarouselCard({
    super.key,
    required this.items,
    this.height = 200.0,
  });

  @override
  State<NanoCarouselCard> createState() => _NanoCarouselCardState();
}

class _NanoCarouselCardState extends State<NanoCarouselCard> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return NanoCard(
      padding: EdgeInsets.zero, // Sin padding para que la imagen ocupe todo el ancho
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Imagen de fondo
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28.0),
                      child: Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: colors.primary.withValues(alpha: 0.1),
                            child: Icon(Icons.image_not_supported, color: colors.primary, size: 40),
                          );
                        },
                      ),
                    ),
                    // Gradiente superpuesto para legibilidad del texto
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28.0),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                    // Textos
                    Positioned(
                      bottom: NanoSpacing.md,
                      left: NanoSpacing.md,
                      right: NanoSpacing.md,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: NanoType.title(Colors.white),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.subtitle != null) ...[
                            const SizedBox(height: NanoSpacing.xs),
                            Text(
                              item.subtitle!,
                              style: NanoType.caption(Colors.white70),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            // Indicadores de página (dots)
            Positioned(
              bottom: 8.0,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.items.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    width: _currentIndex == index ? 16.0 : 6.0,
                    height: 6.0,
                    decoration: BoxDecoration(
                      color: _currentIndex == index ? colors.primary : Colors.white54,
                      borderRadius: BorderRadius.circular(3.0),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Efecto de máquina de escribir
class NanoTypingText extends StatefulWidget {
  const NanoTypingText({
    super.key,
    required this.text,
    this.style,
    this.duration = const Duration(milliseconds: 1500),
    this.maxLines,
  });

  final String text;
  final TextStyle? style;
  final Duration duration;
  final int? maxLines;

  @override
  State<NanoTypingText> createState() => _NanoTypingTextState();
}

class _NanoTypingTextState extends State<NanoTypingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _charCount;
  String _currentText = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _setupAnimation();
    _controller.forward();
  }

  @override
  void didUpdateWidget(NanoTypingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _setupAnimation();
      _controller.forward(from: 0.0);
    }
  }

  void _setupAnimation() {
    _currentText = widget.text;
    _charCount = StepTween(begin: 0, end: _currentText.length).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _charCount,
      builder: (context, child) {
        String visibleString = _currentText.substring(0, _charCount.value);
        // cursor blinks if it's done typing, or is solid while typing
        bool isTyping = _controller.isAnimating;
        
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(text: visibleString),
              if (isTyping)
                const TextSpan(text: '█')
              else
                // we can blink a cursor here if we want, or remove it. I'll just remove it for clean UI
                const TextSpan(text: ''),
            ],
          ),
          style: widget.style,
          maxLines: widget.maxLines, 
          overflow: widget.maxLines == 1 ? TextOverflow.ellipsis : TextOverflow.fade,
        );
      },
    );
  }
}

/// Tarjeta horizontal con imagen a la izquierda, y texto a la derecha
/// que se escribe progresivamente, más un botón de acción inferior.
class NanoTypingCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onButtonPressed;
  final double height;

  const NanoTypingCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onButtonPressed,
    this.height = 180.0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;

    return NanoCard(
      padding: EdgeInsets.zero, // Sin padding interno general, controlamos el interior
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sección de la Imagen (Izquierda)
            Expanded(
              flex: 2,
              child: ClipRRect(
                // Solo redondear las esquinas izquierdas (igual que la tarjeta contenedora)
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28.0),
                  bottomLeft: Radius.circular(28.0),
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: colors.primary.withValues(alpha: 0.1),
                      child: Icon(Icons.image_not_supported, color: colors.primary, size: 40),
                    );
                  },
                ),
              ),
            ),
            // Sección de Contenido (Derecha)
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(NanoSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título (normal)
                    Text(
                      title,
                      style: NanoType.title(colors.onSurface),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: NanoSpacing.sm),
                    // Descripción con efecto Typing
                    Expanded(
                      child: NanoTypingText(
                        text: description,
                        style: NanoType.caption(colors.onSurfaceVariant),
                      ),
                    ),
                    // Botón inferior alineado a la derecha
                    Align(
                      alignment: Alignment.bottomRight,
                      child: ElevatedButton(
                        onPressed: onButtonPressed,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        child: Text(buttonText),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ── NanoMetalSurface (Glass Metálico Redesign) ──
///
/// Contenedor premium que combina desenfoque profundo (glass),
/// reflejos sutiles (metal) y bordes cromáticos translúcidos.
class NanoMetalSurface extends StatelessWidget {
  const NanoMetalSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.borderRadius,
    this.height,
    this.width,
    this.borderColor,
    this.gradientColors,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final double? height;
  final double? width;
  final Color? borderColor;
  final List<Color>? gradientColors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<NanoThemeExtension>()!.colors;
    final radius = borderRadius ?? BorderRadius.circular(24.0);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    Widget surface = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: reduceMotion ? 0.0 : 18.0, 
          sigmaY: reduceMotion ? 0.0 : 18.0
        ),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors ?? [
                colors.glass100.withValues(alpha: 0.5),
                colors.glass300.withValues(alpha: 0.3),
              ],
              stops: const [0.1, 0.9],
            ),
            border: Border.all(
              color: borderColor ?? colors.metalPearl.withValues(alpha: 0.12),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.bgMiddle.withValues(alpha: 0.4),
                blurRadius: 15,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              )
            ]
          ),
          // Decoración interna para reflejos metálicos cálidos/fríos
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Reflejo oblicuo suave
              Positioned(
                top: -20,
                left: -20,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        colors.warmReflect1.withValues(alpha: 0.03),
                        colors.warmReflect1.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          highlightColor: colors.metalWhite.withValues(alpha: 0.05),
          splashColor: colors.nanoCyan.withValues(alpha: 0.1),
          child: surface,
        ),
      );
    }
    return surface;
  }
}

/// ── NanoGlassSurface ──
///
/// Contenedor premium que combina radios y difuminado dinámicos, Fresnel Edge,
/// refracción cromática en bordes metálicos, reflejos especulares animados
/// y respuesta táctil interactiva.
class NanoGlassSurface extends StatefulWidget {
  const NanoGlassSurface({
    super.key,
    required this.child,
    this.radius = 24.0,
    this.blur = 16.0,
    this.opacity,
    this.accent,
    this.depth = 1.0,
    this.reflectionIntensity = 0.5,
    this.refractionIntensity = 0.15,
    this.animated = true,
    this.interactive = true,
    this.padding = const EdgeInsets.all(16.0),
    this.onTap,
    this.reflectionController,
  });

  final Widget child;
  final double radius;
  final double blur;
  final double? opacity;
  final Color? accent;
  final double depth;
  final double reflectionIntensity;
  final double refractionIntensity;
  final bool animated;
  final bool interactive;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final AnimationController? reflectionController;

  @override
  State<NanoGlassSurface> createState() => _NanoGlassSurfaceState();
}

class _NanoGlassSurfaceState extends State<NanoGlassSurface>
    with SingleTickerProviderStateMixin {
  AnimationController? _localSpecularController;
  bool _isPressed = false;

  AnimationController get _specularController =>
      widget.reflectionController ?? _localSpecularController!;

  @override
  void initState() {
    super.initState();
    if (widget.reflectionController == null) {
      _localSpecularController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 10),
      );
      if (widget.animated) {
        _localSpecularController!.repeat();
      }
    }
  }

  @override
  void didUpdateWidget(covariant NanoGlassSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reflectionController == null && _localSpecularController == null) {
      _localSpecularController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 10),
      );
      if (widget.animated) {
        _localSpecularController!.repeat();
      }
    } else if (widget.reflectionController != null && _localSpecularController != null) {
      _localSpecularController!.dispose();
      _localSpecularController = null;
    }
    
    if (_localSpecularController != null) {
      if (widget.animated && !oldWidget.animated) {
        _localSpecularController!.repeat();
      } else if (!widget.animated && oldWidget.animated) {
        _localSpecularController!.stop();
      }
    }
  }

  @override
  void dispose() {
    _localSpecularController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = NanoThemeExtension.of(context).colors;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final accentColor = widget.accent ?? colors.primary;

    final double activeBlur = reduceMotion ? 0.0 : widget.blur;
    final double activeOpacity = widget.opacity ?? (colors is NanoDarkColors ? colors.glassMedium : 0.60);

    // Interaction scale
    final scale = (widget.interactive && _isPressed && !reduceMotion) ? 0.985 : 1.0;

    // Organized Tokens: Shadows, Metallic Rims, Glass Substrate, Fresnel & Sheen
    final shadows = NanoShadows.ambient(colors, depth: widget.depth, accent: widget.accent);
    final borderGradient = NanoBorders.metallicRim(
      colors,
      accent: widget.accent,
      refractionIntensity: widget.refractionIntensity,
    );
    final baseGlassGradient = NanoGlass.substrate(colors, opacity: activeOpacity);
    final accentTintGradient = NanoGlass.accentTint(accentColor, depth: widget.depth);
    final fresnelGlowGradient = NanoMetallic.fresnelGlow(colors, intensity: widget.reflectionIntensity);
    final specularSheenGradient = NanoGlass.specularSheen(colors, intensity: widget.reflectionIntensity);

    Widget surfaceContent = Stack(
      fit: StackFit.loose,
      children: [
        // 1. Base Glass with Opacity
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: baseGlassGradient,
            ),
          ),
        ),

        // 2. Internal Tint / Accentcore
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: accentTintGradient,
            ),
          ),
        ),

        // 3. Fresnel Edge / Metallic Specular Glow
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.radius),
                gradient: fresnelGlowGradient,
              ),
            ),
          ),
        ),

        // 4. Specular Highlight Animation (diagonal sheen)
        if (widget.animated && !reduceMotion)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _specularController,
              builder: (context, child) {
                final progress = _specularController.value;
                final slideOffset = -1.5 + (progress * 3.0);
                return ClipRRect(
                  borderRadius: BorderRadius.circular(widget.radius),
                  child: IgnorePointer(
                    child: Transform.translate(
                      offset: Offset(MediaQuery.sizeOf(context).width * slideOffset, 0),
                      child: Transform.rotate(
                        angle: -0.34,
                        child: Center(
                          child: Container(
                            width: 150,
                            decoration: BoxDecoration(
                              gradient: specularSheenGradient,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

        // Content padding and child
        Padding(
          padding: widget.padding,
          child: widget.child,
        ),
      ],
    );

    Widget surface = AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          boxShadow: shadows,
        ),
        child: Container(
          padding: const EdgeInsets.all(1.2), // border thickness
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: borderGradient,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.radius - 1),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: activeBlur,
                sigmaY: activeBlur,
              ),
              child: surfaceContent,
            ),
          ),
        ),
      ),
    );

    if (widget.onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.interactive ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: widget.interactive ? (_) => setState(() => _isPressed = false) : null,
        onTapCancel: widget.interactive ? () => setState(() => _isPressed = false) : null,
        onTap: widget.onTap,
        child: surface,
      );
    }
    return surface;
  }
}


