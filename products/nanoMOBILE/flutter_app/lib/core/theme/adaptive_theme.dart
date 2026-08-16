import 'package:flutter/material.dart';

/// Utilidades adaptativas con uso real en la app:
/// - isLandscape: transición de página en AppTheme
/// - getThemeTransitionDuration: AnimatedSwitcher del tema en main.dart
/// - AdaptiveOrientationBuilder: raíz de MaterialApp en main.dart
///
/// Los widgets adaptativos (AdaptiveGrid, AdaptiveList, AdaptiveSafeArea,
/// BreakpointBuilder, AdaptiveGlassContainer) y los helpers de glass/spacing/
/// columns/card-height/overflow se eliminaron: cero callers en lib/.
class AdaptiveTheme {
  /// Detecta si el dispositivo está en modo landscape
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Duración de la transición de tema (más corta en pantallas compactas)
  static Duration getThemeTransitionDuration(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.height < 700;
    return Duration(milliseconds: isCompact ? 600 : 800);
  }
}

/// OrientationBuilder simplificado.
/// Renombrado a AdaptiveOrientationBuilder: "OrientationBuilder" chocaba con
/// el widget homónimo de Flutter — main.dart importa ambos y el compilador
/// no resolvía la ambigüedad (fix del refactor de theme).
class AdaptiveOrientationBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, bool isLandscape) builder;

  const AdaptiveOrientationBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape = AdaptiveTheme.isLandscape(context);
    return builder(context, isLandscape);
  }
}
