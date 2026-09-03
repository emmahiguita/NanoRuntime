/// CAP-ROUTER-01 — ExecutionPath: las vías de ejecución que Nano puede
/// elegir para satisfacer un [CapabilityIntent]. Es un ENUM descriptivo:
/// quien ejecuta sigue siendo la cadena existente (Policy → Journal →
/// CommitGuard → ejecutor). Elegir una ruta aquí no ejecuta nada.
///
/// Orden de calidad por vía (preferencia general, detalle en
/// capability_path_policy.dart):
///   1. appFunction     — contrato AppFunctions (APPFN-01, futuro).
///   2. androidIntent   — intent directo del sistema (abrir app, navegar).
///   3. remoteInput     — RemoteInput exacto de una notificación observada.
///   4. accessibilityGui— árbol + perfil de superficie + CommitGuard.
///   5. ocr / vision    — SOLO observación suplementaria, jamás ruta
///                        principal de ejecución (estructural primero).
library;

enum ExecutionPath {
  /// Contrato AppFunctions de Android 16+. Hoy nunca se resuelve: APPFN-01
  /// aún no existe y ningún intent debe depender de él.
  appFunction,

  /// Intent directo de Android (lanzar app, ACTION_VIEW…). Vía nativa
  /// existente en Nano para efectos de navegación.
  androidIntent,

  /// RemoteInput de la notificación EXACTA observada y revalidada.
  /// Es la vía de mayor confianza para reply sin abrir la app.
  remoteInput,

  /// Gestos asistidos por el árbol de accesibilidad con perfil de
  /// superficie declarativo y CommitGuard alrededor del único tap.
  accessibilityGui,

  /// Reconocimiento de texto sobre screenshot. Observación suplementaria.
  ocr,

  /// Visión sobre screenshot. Observación suplementaria.
  vision,

  /// Sin vía con evidencia suficiente. El llamador debe tratar esto como
  /// fail-closed: no ejecutar.
  none,
}
