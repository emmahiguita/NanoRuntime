/// EDGE-03 — ContextPanel: contrato de los paneles de contexto del búho.
///
/// Adaptación del contrato del plan a la arquitectura real: el overlay nativo
/// es Flutter-free (regla dura de EDGE-01), así que el panel NO construye
/// widgets para la ventana del sistema — produce [NanoEdgeContent] (título +
/// cuerpo) que el overlay nativo dibuja. El mismo contenido alimenta los
/// widgets del dashboard (nano_edge_overlay.dart).
///
/// Reglas duras:
/// - Puro: recibe [NanoEdgeState] y devuelve contenido. Cero imports de
///   execution/governance, cero consultas propias, cero ejecución.
/// - La app NO conoce el panel; el panel conoce la app (OCP correcto).
library;

import '../nano_edge_state.dart';

/// Un panel de contexto para una familia de apps en foreground.
abstract interface class ContextPanel {
  /// Identificador estable (para logs y orden).
  String get id;

  /// true si este panel aplica para [packageName] en foreground.
  bool matches(String packageName);

  /// Contenido que el overlay dibuja para el estado observado.
  NanoEdgeContent contentFor(NanoEdgeState state);
}
