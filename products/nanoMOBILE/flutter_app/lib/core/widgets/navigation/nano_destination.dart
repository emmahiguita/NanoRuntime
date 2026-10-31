// nano_destination.dart — Destinos principales de navegación de Nano AI.
// QUÉ HACE: Modela las secciones de la app manteniendo Clean Architecture.
// CÓMO FUNCIONA: Asocia etiqueta, icono vectorial NanoGlyph y ruta de navegación.
// POR QUÉ: Desacopla la lógica de navegación de los componentes visuales (< 45 líneas).
library;

import 'nano_glyph.dart';

/// Destinos principales de navegación de Nano AI.
enum NanoDestination {
  automation('Inicio', NanoGlyphType.home, '/dashboard'),
  models('Modelos', NanoGlyphType.models, '/models'),
  terminal('Terminal', NanoGlyphType.terminal, '/terminal'),
  settings('Ajustes', NanoGlyphType.settings, '/settings');

  const NanoDestination(this.label, this.glyph, this.route);

  final String label;
  final NanoGlyphType glyph;
  final String route;

  /// Destinos canónicos exclusivos de la barra inferior (exactamente tres).
  /// Ajustes se reserva para el Drawer y rutas directas sin saturar el dock.
  static const List<NanoDestination> bottomBarDestinations = [
    automation,
    models,
    terminal,
  ];

  static NanoDestination fromIndex(int index) {
    if (index >= 0 && index < values.length) {
      return values[index];
    }
    return values.first;
  }
}
