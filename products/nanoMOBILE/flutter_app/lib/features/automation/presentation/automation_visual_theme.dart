import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:nanoai/core/theme/design_tokens.dart';
import 'package:nanoai/core/widgets/liquid_fluid_background.dart';

/// Lenguaje visual local de Automatización.
///
/// Está deliberadamente acotado a este módulo: no cambia el tema elegido por
/// el usuario ni la apariencia de Chat, Terminal, Modelos o Ajustes.
enum AutomationVisualMode { system, lightGlass, dark }

abstract final class AutomationVisual {
  /// NAV-BAR-FIX-05 — acento del módulo = accentBlue de la barra de
  /// navegación (NanoNavTokens). La identidad clásica es el azul cósmico.
  static const lightAccent = Color(0xFF2A7FFF);

  static AutomationVisualMode modeFromSetting(String themeMode) =>
      switch (themeMode) {
        'Claro' => AutomationVisualMode.lightGlass,
        'Oscuro' => AutomationVisualMode.dark,
        _ => AutomationVisualMode.system,
      };

  /// Paleta semántica del módulo derivada del tema real de la aplicación.
  ///
  /// Automatización conserva su identidad de acento, pero no mantiene una
  /// segunda fuente de verdad para claro/oscuro. Esto evita que una ruta
  /// fuerce el modo claro cuando el usuario eligió Oscuro o Sistema.
  static AutomationVisualPalette of(BuildContext context) {
    final scoped = Theme.of(context).extension<AutomationVisualTheme>();
    if (scoped != null) return scoped.palette;
    return _paletteFor(context, AutomationVisualMode.system);
  }

  static AutomationVisualPalette _paletteFor(
    BuildContext context,
    AutomationVisualMode mode,
  ) {
    final inheritedColors = NanoThemeExtension.of(context).colors;
    // UI-REV-09: el ramo visual sigue a la familia instalada por el tema real,
    // no al setting ni al brightness. Con "Claro" la app instala la familia
    // oscura de Dev (NanoClassicDarkColors): automation pinta vidrio
    // oscuro con acento azul barra — nunca vidrio claro sobre fondo oscuro.
    // "Oscuro" (familia oscura azul barra, NAV-BAR-FIX-06) conserva el acento
    // del shell nocturno; "Sistema"-claro conserva la familia clara.
    final isDark = inheritedColors is NanoDarkColors;
    // El modo Oscuro explícito adopta el accentMint de la familia (hoy azul
    // eléctrico de la barra); el resto conserva el accentBlue de la barra.
    final usesDarkAccent = mode == AutomationVisualMode.dark;
    final colors = inheritedColors;
    return AutomationVisualPalette(
      // UI-REV-02: familia de colores RESUELTA para el scope. Antes el
      // ThemeData del scope preservaba la NanoThemeExtension global
      // original (p.ej. oscura con modo Claro glass): las secciones que
      // leen NanoThemeExtension.of (notificaciones, console, c14, skills,
      // engine status) pintaban textos/acentos del tema oscuro sobre
      // canvas claro — mezcla de modos ilegible.
      resolvedColors: colors,
      isDark: isDark,
      accent: usesDarkAccent ? colors.accentMint : lightAccent,
      onAccent: usesDarkAccent ? colors.onAccent : Colors.white,
      accentSoft: usesDarkAccent
          ? colors.accentMint.withValues(alpha: 0.14)
          : const Color(0xB8EAF2FF),
      canvas: colors.backgroundPrimary,
      surface: isDark
          ? colors.glassPrimary.withValues(alpha: 0.72)
          : colors.glassSurface,
      inputFill: isDark
          ? colors.backgroundDeep.withValues(alpha: 0.62)
          : colors.glassSecondary.withValues(alpha: 0.56),
      text: colors.textPrimary,
      textMuted: colors.textSecondary,
      line: colors.borderSecondaryColor,
      outline: isDark ? colors.outline : const Color(0xFFC9CDD3),
      // Vidrio líquido iOS con alta transparencia y contraste cinematográfico
      cardStart: isDark
          ? const Color(0x660E182D) // ~40% zafiro obsidiana esmerilado
          : const Color(0x750E182D), // ~46% zafiro obsidiana esmerilado
      cardEnd: isDark
          ? const Color(0x7C080E1D) // ~49% obsidiana cósmica profunda
          : const Color(0x88080E1D), // ~53% obsidiana cósmica profunda
      cardBorder: isDark
          ? Colors.white.withValues(alpha: 0.22)
          : Colors.white.withValues(alpha: 0.35),
      shadow: isDark
          ? const Color(0x35000000)
          : const Color(0x180D1726),
      shadowSoft: isDark
          ? const Color(0x200D1F4A)
          : const Color(0x100D1726),
      success: colors.success,
    );
  }

  /// Adapta los componentes Material del módulo sin sustituir el ThemeData
  /// global. Se preservan extensiones, tipografía, plataforma y transiciones
  /// del diseño clásico de Nano.
  static ThemeData theme(
    BuildContext context, {
    AutomationVisualMode mode = AutomationVisualMode.system,
  }) {
    final base = Theme.of(context);
    final visual = _paletteFor(context, mode);
    final scheme = base.colorScheme.copyWith(
      primary: visual.accent,
      onPrimary: visual.onAccent,
      surface: visual.surface,
      onSurface: visual.text,
      outline: visual.outline,
      outlineVariant: visual.line,
    );
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: visual.canvas,
      extensions: [
        ...base.extensions.values.where(
          (extension) =>
              extension is! AutomationVisualTheme &&
              // UI-REV-02: la extensión global se sustituye por la familia
              // resuelta — fuera la mezcla claro/oscuro de las secciones
              // que leen NanoThemeExtension.of(context).
              extension is! NanoThemeExtension,
        ),
        NanoThemeExtension(colors: visual.resolvedColors),
        AutomationVisualTheme(palette: visual),
      ],
      textTheme: base.textTheme.apply(
        bodyColor: visual.text,
        displayColor: visual.text,
        fontFamily: 'Inter',
      ),
      dividerColor: visual.line,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: visual.inputFill,
        hintStyle: TextStyle(color: visual.textMuted.withValues(alpha: 0.72)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: visual.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: visual.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: visual.accent, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: visual.accent,
          foregroundColor: visual.onAccent,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : const Color(0xFFF4F4F5),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? visual.accent
              : visual.line,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? visual.accent
                : visual.textMuted,
            fontSize: 9.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            letterSpacing: -0.25,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? visual.accent
                : visual.textMuted,
            size: 23,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: visual.surface,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

@immutable
class AutomationVisualPalette {
  const AutomationVisualPalette({
    required this.resolvedColors,
    required this.isDark,
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.canvas,
    required this.surface,
    required this.inputFill,
    required this.text,
    required this.textMuted,
    required this.line,
    required this.outline,
    required this.cardStart,
    required this.cardEnd,
    required this.cardBorder,
    required this.shadow,
    required this.shadowSoft,
    required this.success,
  });

  /// Familia de colores semánticos resuelta para el scope visual (clara u
  /// oscura según el modo). Se instala como NanoThemeExtension dentro del
  /// ThemeData del scope para que los widgets que leen la extensión global
  /// vean colores coherentes con el canvas del módulo.
  final NanoColors resolvedColors;

  final bool isDark;
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color canvas;
  final Color surface;
  final Color inputFill;
  final Color text;
  final Color textMuted;
  final Color line;
  final Color outline;
  final Color cardStart;
  final Color cardEnd;
  final Color cardBorder;
  final Color shadow;
  final Color shadowSoft;
  final Color success;

  AutomationVisualPalette lerp(AutomationVisualPalette other, double t) =>
      AutomationVisualPalette(
        // Lerp campo a campo via _LerpedNanoColors: al animar el cambio de
        // modo (AnimatedTheme) la familia entera transiciona sin salto.
        resolvedColors:
            (NanoThemeExtension(
                      colors: resolvedColors,
                    ).lerp(NanoThemeExtension(colors: other.resolvedColors), t)
                    as NanoThemeExtension)
                .colors,
        isDark: t < 0.5 ? isDark : other.isDark,
        accent: Color.lerp(accent, other.accent, t)!,
        onAccent: Color.lerp(onAccent, other.onAccent, t)!,
        accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
        canvas: Color.lerp(canvas, other.canvas, t)!,
        surface: Color.lerp(surface, other.surface, t)!,
        inputFill: Color.lerp(inputFill, other.inputFill, t)!,
        text: Color.lerp(text, other.text, t)!,
        textMuted: Color.lerp(textMuted, other.textMuted, t)!,
        line: Color.lerp(line, other.line, t)!,
        outline: Color.lerp(outline, other.outline, t)!,
        cardStart: Color.lerp(cardStart, other.cardStart, t)!,
        cardEnd: Color.lerp(cardEnd, other.cardEnd, t)!,
        cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
        shadow: Color.lerp(shadow, other.shadow, t)!,
        shadowSoft: Color.lerp(shadowSoft, other.shadowSoft, t)!,
        success: Color.lerp(success, other.success, t)!,
      );
}

@immutable
class AutomationVisualTheme extends ThemeExtension<AutomationVisualTheme> {
  const AutomationVisualTheme({required this.palette});

  final AutomationVisualPalette palette;

  @override
  AutomationVisualTheme copyWith({AutomationVisualPalette? palette}) =>
      AutomationVisualTheme(palette: palette ?? this.palette);

  @override
  AutomationVisualTheme lerp(
    covariant ThemeExtension<AutomationVisualTheme>? other,
    double t,
  ) => other is AutomationVisualTheme
      ? AutomationVisualTheme(palette: palette.lerp(other.palette, t))
      : this;
}

class AutomationSurfaceCard extends StatefulWidget {
  const AutomationSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
    this.radius = 24,
    this.blurSigma = 18,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final double blurSigma;

  @override
  State<AutomationSurfaceCard> createState() => _AutomationSurfaceCardState();
}

class _AutomationSurfaceCardState extends State<AutomationSurfaceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final visual = AutomationVisual.of(context);
    final borderRadius = BorderRadius.circular(widget.radius);
    final isDark = visual.isDark;

    final card = Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: visual.shadow,
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
          BoxShadow(
            color: visual.accent.withValues(alpha: isDark ? 0.12 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: widget.blurSigma,
            sigmaY: widget.blurSigma,
          ),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [visual.cardStart, visual.cardEnd],
              ),
              borderRadius: borderRadius,
              border: Border.all(
                color: visual.cardBorder,
                width: 1.0,
              ),
            ),
            child: Stack(
              children: [
                // Línea superior de brillo especular de vidrio iOS
                Positioned(
                  top: 0,
                  left: 16,
                  right: 16,
                  height: 1.0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(
                            alpha: isDark ? 0.35 : 0.75,
                          ),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  borderRadius: borderRadius,
                  child: widget.onTap != null
                      ? InkWell(
                          onTap: widget.onTap,
                          borderRadius: borderRadius,
                          splashColor: visual.accent.withValues(alpha: 0.12),
                          highlightColor: visual.accent.withValues(alpha: 0.08),
                          child: Padding(
                            padding: widget.padding,
                            child: widget.child,
                          ),
                        )
                      : Padding(
                          padding: widget.padding,
                          child: widget.child,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.onTap != null) {
      return Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          scale: _pressed ? 0.985 : 1.0,
          child: card,
        ),
      );
    }

    return card;
  }
}

class AutomationSectionLabel extends StatelessWidget {
  const AutomationSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
            decoration: BoxDecoration(
              color: const Color(0x66000000),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.22),
                width: 0.8,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x35000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                shadows: [
                  Shadow(
                    color: Colors.black87,
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Marca NANO AI única del módulo (DRY): 'NANO ' en color de texto, 'AI' en
/// accent. Antes había tres variantes divergentes (Rules usaba texto plano sin
/// accent; Settings duplicaba el RichText; Dashboard lo repetía inline).
class AutomationBrand extends StatelessWidget {
  const AutomationBrand({
    super.key,
    this.fontSize = 23,
    this.letterSpacing = 1.6,
  });

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
            // UI-REV-05: naranja crudo sobre fondo claro ≈ 2.9:1 — ilegible
            // ("NANO AI no se ve"). Variante oscura legible de la familia.
            style: TextStyle(
              color: NanoTextColors.forText(
                visual.accent,
                visual.resolvedColors,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cabecera de sub-pantalla del módulo: 52px, botón atrás a la izquierda y
/// marca alineada al inicio — sin centrado forzado ni contrapesos ciegos
/// (UI-REV-05: aprovecha el ancho y deja el texto completo visible).
class AutomationBackHeader extends StatelessWidget {
  const AutomationBackHeader({super.key, this.onBack});

  /// Si es null, hace Navigator.maybePop() (comportamiento de Settings).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Atrás',
            visualDensity: VisualDensity.compact,
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 24),
          ),
          const SizedBox(width: 4),
          const AutomationBrand(),
          const Spacer(),
        ],
      ),
    );
  }
}

/// Fondo compartido del módulo — fondo de pantalla celestial del Búho en
/// vertical (assets/automation/automation_bg_portrait.jpg) con gradiente
/// scrim para contraste y legibilidad óptima de las tarjetas de cristal; y
/// aurora fluida (LiquidFluidBackground) en horizontal.
class AutomationBackdrop extends StatelessWidget {
  const AutomationBackdrop({super.key, this.scrimOpacity});

  /// Opacidad base del scrim protector sobre la imagen.
  final double? scrimOpacity;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final landscape = size.width > size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (landscape) {
      return const LiquidFluidBackground();
    }

    final baseScrim = isDark ? 0.35 : 0.30;
    final scrim = scrimOpacity ?? baseScrim;

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/automation/automation_bg_portrait.jpg',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
        ),
        // Scrim atmosférico con gradiente: preserva la luminosidad del portal
        // cósmico y del búho mientras garantiza legibilidad del texto y cards.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: (scrim * 1.5).clamp(0.0, 1.0)),
                Colors.black.withValues(alpha: (scrim * 0.9).clamp(0.0, 1.0)),
                Colors.black.withValues(alpha: (scrim * 1.6).clamp(0.0, 1.0)),
              ],
              stops: const [0.0, 0.40, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
