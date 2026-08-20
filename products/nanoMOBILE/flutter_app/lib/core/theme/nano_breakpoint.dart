import 'package:flutter/widgets.dart';

/// Sistema de breakpoints de NanoAI — la ÚNICA fuente de verdad para
/// decisiones de composición responsive (la auditoría encontró 4 fórmulas
/// ad-hoc: `width>600`, `>=900`, `height<520`, `width>height`).
///
/// Los valores derivan del contenido real de la app:
/// - 600: donde el panel dock + contenido dejan de caber en una fila
///   (scaffold_shell auto-minimiza el dock bajo este ancho).
/// - 900: donde una columna de formulario/cards pierde legibilidad y la
///   composición en 2 columnas aporta valor (settings ya lo usaba).
/// - 1280: cota de contenido principal (margen muerto más allá para listas).
/// - 1920: ultrawide (nunca una sola columna estirada).
enum NanoBreakpoint { compact, medium, expanded, large, ultrawide }

abstract final class NanoBreakpoints {
  static const double compactMax = 600;
  static const double mediumMax = 900;
  static const double expandedMax = 1280;
  static const double largeMax = 1920;

  /// Cota máxima de ancho del contenido principal. `compact` usa el ancho
  /// completo (mobile first); medium+ acota para evitar el "estirar una
  /// columna hasta ocupar la pantalla" en tablet/desktop.
  static const double _contentMax = 1280;
  static const double contentMaxWidth = _contentMax;

  /// Clasifica por ancho disponible.
  static NanoBreakpoint of(double width) {
    if (width <= compactMax) return NanoBreakpoint.compact;
    if (width <= mediumMax) return NanoBreakpoint.medium;
    if (width <= expandedMax) return NanoBreakpoint.expanded;
    if (width <= largeMax) return NanoBreakpoint.large;
    return NanoBreakpoint.ultrawide;
  }

  /// Landscape compacto: más ancho que alto y poca altura. Es un flag
  /// ORTOGONAL a [of] — un phone girado tiene width grande pero height
  /// pequeña; la composición debe reaccionar a ambos ejes.
  static bool isCompactLandscape(Size size) =>
      size.width > size.height && size.height < 520;

  /// `true` para [NanoBreakpoint.medium]+: donde los botones primarios
  /// full-width se vuelven botones estirados sin propósito.
  static bool hasHorizontalSpace(NanoBreakpoint b) => b.index >= 1;

  /// Cota de contenido lista para usar: `null` en compact (full width),
  /// [contentMaxWidth] en el resto.
  static BoxConstraints contentBox(double width) {
    final b = of(width);
    if (!hasHorizontalSpace(b)) return const BoxConstraints();
    return const BoxConstraints(maxWidth: _contentMax);
  }
}
