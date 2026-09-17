import 'package:flutter/foundation.dart';
import 'tool_call.dart';

/// Superficies de automatización soportadas por el runtime multisuperficie de Nano.
enum AutomationSurface {
  /// Fast-path de integración directa: llamadas estructuradas a APIs y servidores MCP.
  apiMcp,

  /// Subsistema Linux determinista: Nanoshell, rootfs, Toybox, IBinExecutor, filesystem, CLI.
  linux,

  /// Navegación Web sobre GeckoView: manipulación semántica directa de DOM sin visión.
  browserDom,

  /// Accesibilidad nativa Android: árbol UI con Resource ID, texto y jerarquía estructural.
  androidAccessibility,

  /// Percepción visual auxiliar: OCR y modelos de visión para elementos sin semántica.
  ocrVision,

  /// Fallback de coordenadas espaciales: último recurso ante canvases o juegos sin semántica.
  coordinates;

  String get displayName => switch (this) {
        AutomationSurface.apiMcp => 'API / MCP Directo',
        AutomationSurface.linux => 'Linux / Nanoshell',
        AutomationSurface.browserDom => 'Browser DOM (GeckoView)',
        AutomationSurface.androidAccessibility => 'Android Accessibility',
        AutomationSurface.ocrVision => 'OCR / Visión',
        AutomationSurface.coordinates => 'Coordenadas Físicas (Fallback)',
      };
}

/// Decisión calculada por el router con causalidad y superficies de respaldo.
@immutable
class CapabilityRoutingDecision {
  final AutomationSurface primarySurface;
  final String rationale;
  final double confidence;
  final List<AutomationSurface> fallbackSurfaces;

  const CapabilityRoutingDecision({
    required this.primarySurface,
    required this.rationale,
    this.confidence = 1.0,
    this.fallbackSurfaces = const [],
  });

  Map<String, dynamic> toJson() => {
        'primarySurface': primarySurface.name,
        'rationale': rationale,
        'confidence': confidence,
        'fallbackSurfaces': fallbackSurfaces.map((s) => s.name).toList(),
      };
}

/// Router de capacidades multisuperficie (CapabilityRouter).
///
/// Implementa la jerarquía estricta de Nano:
/// 1. API / MCP (0 visión, determinista)
/// 2. Linux / Filesystem / CLI (80-90% de tareas técnicas y de datos)
/// 3. Browser DOM (sin visión)
/// 4. Android Accessibility Semántica (Resource ID, text, structural relations)
/// 5. OCR / Visión
/// 6. Coordenadas
class CapabilityRouter {
  final bool Function() _isApiAvailable;
  final bool Function() _isLinuxAvailable;
  final bool Function() _isBrowserAvailable;
  final bool Function() _isAccessibilityAvailable;

  const CapabilityRouter({
    bool Function()? isApiAvailable,
    bool Function()? isLinuxAvailable,
    bool Function()? isBrowserAvailable,
    bool Function()? isAccessibilityAvailable,
  })  : _isApiAvailable = isApiAvailable ?? _defaultTrue,
        _isLinuxAvailable = isLinuxAvailable ?? _defaultTrue,
        _isBrowserAvailable = isBrowserAvailable ?? _defaultTrue,
        _isAccessibilityAvailable = isAccessibilityAvailable ?? _defaultTrue;

  static bool _defaultTrue() => true;

  /// Evalúa un ToolCall y el objetivo del usuario para seleccionar la superficie óptima.
  CapabilityRoutingDecision route(ToolCall call, {String? userGoal}) {
    final tool = call.tool.toLowerCase().trim();

    // 1. Detección explícita de MCP / API
    if (tool.startsWith('mcp.') || tool.startsWith('api.')) {
      if (_isApiAvailable()) {
        return const CapabilityRoutingDecision(
          primarySurface: AutomationSurface.apiMcp,
          rationale: 'Herramienta MCP/API directa con contrato estructurado.',
          confidence: 1.0,
        );
      }
    }

    // 2. Detección de operaciones Linux / Filesystem / CLI
    if (tool.startsWith('nano.linux.') ||
        tool.startsWith('linux.') ||
        _isLinuxIntended(tool, userGoal)) {
      if (_isLinuxAvailable()) {
        return const CapabilityRoutingDecision(
          primarySurface: AutomationSurface.linux,
          rationale: 'Operación determinista de filesystem, proceso o CLI en Linux.',
          confidence: 0.95,
          fallbackSurfaces: [AutomationSurface.androidAccessibility],
        );
      }
    }

    // 3. Detección de navegación Browser Web (GeckoView)
    if (tool.startsWith('web.') || tool.startsWith('browser.') || _isBrowserIntended(userGoal)) {
      if (_isBrowserAvailable()) {
        return const CapabilityRoutingDecision(
          primarySurface: AutomationSurface.browserDom,
          rationale: 'Interacción web en DOM vía GeckoView.',
          confidence: 0.90,
          fallbackSurfaces: [AutomationSurface.androidAccessibility],
        );
      }
    }

    // 4. Android Accessibility Semántica
    if (_isAccessibilityAvailable()) {
      return const CapabilityRoutingDecision(
        primarySurface: AutomationSurface.androidAccessibility,
        rationale: 'Interacción semántica en app Android mediante Accessibility Tree.',
        confidence: 0.85,
        fallbackSurfaces: [AutomationSurface.ocrVision, AutomationSurface.coordinates],
      );
    }

    // 5 y 6. Fallback a visión o coordenadas
    return const CapabilityRoutingDecision(
      primarySurface: AutomationSurface.ocrVision,
      rationale: 'Accesibilidad no disponible: requiriendo visión y OCR.',
      confidence: 0.50,
      fallbackSurfaces: [AutomationSurface.coordinates],
    );
  }

  bool _isLinuxIntended(String tool, String? goal) {
    if (goal == null) return false;
    final g = goal.toLowerCase();
    return g.contains('archivo') ||
        g.contains('descarga') ||
        g.contains('compila') ||
        g.contains('repo') ||
        g.contains('git') ||
        g.contains('terminal') ||
        g.contains('tar') ||
        g.contains('zip') ||
        g.contains('script');
  }

  bool _isBrowserIntended(String? goal) {
    if (goal == null) return false;
    final g = goal.toLowerCase();
    return g.contains('http://') ||
        g.contains('https://') ||
        g.contains('url') ||
        g.contains('página web') ||
        g.contains('sitio web') ||
        g.contains('buscar en la web');
  }
}
