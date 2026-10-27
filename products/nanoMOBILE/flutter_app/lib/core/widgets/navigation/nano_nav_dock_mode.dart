// nano_nav_dock_mode.dart — Modos de visualización adaptativa del dock de navegación.
// QUÉ HACE: Define las posibles posiciones del dock (inferior, esquinas contraídas y drawer lateral).
// CÓMO FUNCIONA: Enum tipado con alias semánticos para esquinas inferiores y superiores.
// POR QUÉ: Permite snap adaptativo y persistencia de posición en pantallas horizontales y verticales.
library;

/// Modos de anclaje del dock de navegación de Nano AI.
enum NanoNavDockMode {
  /// Barra cósmica flotante inferior completa (búsqueda universal + 4 destinos).
  bottom,

  /// Barra contraída en la esquina inferior derecha con activador cósmico.
  rightCollapsed,

  /// Barra contraída en la esquina inferior izquierda con activador cósmico.
  leftCollapsed,

  /// Barra contraída en la esquina superior derecha.
  topRight,

  /// Barra contraída en la esquina superior izquierda.
  topLeft,

  /// Panel lateral derecho (drawer glass) con destinos y buscador.
  rightDrawer;

  /// Alias semánticos para posicionamiento intuitivo en esquinas
  static const NanoNavDockMode bottomRight = rightCollapsed;
  static const NanoNavDockMode bottomLeft = leftCollapsed;
}
