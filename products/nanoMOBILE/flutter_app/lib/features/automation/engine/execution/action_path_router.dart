/// ActionPathRouter (Fase C6) — elige el mecanismo MÁS EFICIENTE para cada
/// acción, en lugar de ir siempre a Accessibility.
///
/// Prioridad (plan maestro §11):
///   1. Android API / Intent
///   2. herramienta estructurada
///   3. Linux
///   4. Accessibility
///   5. OCR → Vision → coordinates (futuro)
///
/// Ejemplos: "leer un archivo" NO abre la app de Archivos — ruta Linux;
/// "abrir ajustes de Bluetooth" prefiere Intent si está disponible, si no
/// Accessibility.
///
/// Puro y determinista: clasifica un [ToolCall] (+ contexto del goal) y
/// devuelve la ruta recomendada con su justificación. El dispatcher lo
/// consulta para etiquetar cada paso del plan con su ruta (visible en UI).
library;

import 'agent_tool_dispatcher.dart' show ToolCall;

/// Rutas de ejecución disponibles (en orden de preferencia).
enum ExecutionPath {
  androidIntent,
  structuredTool,
  linux,
  accessibility,
  ocr,
  vision,
  coordinates;

  String get label => switch (this) {
    ExecutionPath.androidIntent => 'Android API / Intent',
    ExecutionPath.structuredTool => 'Herramienta estructurada',
    ExecutionPath.linux => 'Linux',
    ExecutionPath.accessibility => 'Accessibility',
    ExecutionPath.ocr => 'OCR',
    ExecutionPath.vision => 'Vision',
    ExecutionPath.coordinates => 'Coordenadas (fallback)',
  };
}

class PathDecision {
  final ExecutionPath path;
  final String reason;
  const PathDecision(this.path, this.reason);
}

/// Clasificador de ruta. DIP: la disponibilidad de rutas (Intent activo,
/// subsistema Linux listo) se inyecta; la heurística es pura.
class ActionPathRouter {
  ActionPathRouter({
    bool Function()? intentAvailable,
    bool Function()? linuxAvailable,
  }) : _intentAvailable = intentAvailable ?? (() => false),
       _linuxAvailable = linuxAvailable ?? (() => false);

  final bool Function() _intentAvailable;
  final bool Function() _linuxAvailable;

  /// Decide la ruta para [call]. [goal] (texto del usuario) refina la
  /// heurística cuando el tool es genérico.
  PathDecision route(ToolCall call, {String? goal}) {
    final tool = call.tool;

    // Herramientas estructuradas existentes: su mecanismo ya está decidido.
    switch (tool) {
      case 'screen':
      case 'resolve':
      case 'tap':
      case 'write':
      case 'back':
        return PathDecision(
          ExecutionPath.accessibility,
          'Herramienta de UI sobre el árbol semántico de Accessibility.',
        );
      case 'notifications':
      case 'reply_notification':
        return PathDecision(
          ExecutionPath.structuredTool,
          'Canal estructurado de notificaciones (sin UI).',
        );
    }

    // Herramientas de alto nivel (futuro): clasificar por objetivo.
    if (tool == 'launch_app' || tool == 'open_app') {
      if (_intentAvailable()) {
        return PathDecision(
          ExecutionPath.androidIntent,
          'Abrir app por Intent es la vía más eficiente.',
        );
      }
      return PathDecision(
        ExecutionPath.accessibility,
        'Sin Intent disponible: abrir por Accessibility.',
      );
    }

    if (tool == 'read_file' ||
        tool == 'list' ||
        tool == 'run_command' ||
        tool == 'analyze') {
      if (_linuxAvailable()) {
        return PathDecision(
          ExecutionPath.linux,
          'Operación de archivos/comando: subsistema Linux directo '
          '(no abrir la app de Archivos).',
        );
      }
      return PathDecision(
        ExecutionPath.accessibility,
        'Linux no disponible: degradar a UI.',
      );
    }

    // Heurística por goal: si el usuario pide leer/analizar, es Linux.
    if (goal != null) {
      final g = goal.toLowerCase();
      if ((g.contains('archivo') ||
              g.contains('proyecto') ||
              g.contains('leer') ||
              g.contains('analiz')) &&
          _linuxAvailable()) {
        return PathDecision(
          ExecutionPath.linux,
          'El objetivo menciona leer/analizar archivos: ruta Linux.',
        );
      }
    }

    return PathDecision(
      ExecutionPath.accessibility,
      'Ruta por defecto: Accessibility.',
    );
  }
}
