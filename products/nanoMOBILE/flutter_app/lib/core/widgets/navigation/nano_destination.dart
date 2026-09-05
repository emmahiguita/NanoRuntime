import 'nano_glyph.dart';

/// Destinos principales del dock de navegación de Nano AI.
///
/// Modela las 6 secciones de la aplicación manteniendo una arquitectura
/// limpia e independiente de routers concretos.
enum NanoDestination {
  home('Inicio', NanoGlyphType.home, '/dashboard'),
  chat('Chat', NanoGlyphType.chat, '/chat'),
  models('Modelos', NanoGlyphType.models, '/models'),
  terminal('Terminal', NanoGlyphType.terminal, '/terminal'),
  settings('Ajustes', NanoGlyphType.settings, '/settings'),
  automation('Automatización', NanoGlyphType.automation, '/automation');

  const NanoDestination(this.label, this.glyph, this.route);

  final String label;
  final NanoGlyphType glyph;
  final String route;

  static NanoDestination fromIndex(int index) {
    if (index >= 0 && index < values.length) {
      return values[index];
    }
    return values.first;
  }
}
