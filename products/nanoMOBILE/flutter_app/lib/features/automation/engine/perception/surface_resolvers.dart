/// T2.0 — SurfaceResolvers: resuelven superficies UI REALES (input editable y
/// botón de acción) desde el ScreenGraph, devolviendo un selector grounded.
///
/// Sustituyen el patrón roto de escribir en un selector vacío (`write('', text)`)
/// y de tocar un `desc=Enviar` hardcodeado. Direct-first, 0 LLM: el objeto sale
/// de la OBSERVACIÓN real de la pantalla (Accessibility → ScreenGraph), nunca de
/// un string inventado por el modelo.
///
/// Puro Dart: dependen solo del modelo semántico (ScreenGraph/NanoUiObject).
/// El snapshot/IO lo hace el llamador (composition root).
library;

import 'semantic/nano_ui_object.dart';
import 'semantic/screen_graph.dart';
import 'semantic/semantic_role.dart';

/// Superficie UI grounded: el objeto observado + el selector para re-encontrarlo
/// en el ejecutor + el motivo que la hizo ganar (diagnóstico honesto).
class ResolvedSurface {
  final NanoUiObject object;
  final String selector;
  final String reason;

  const ResolvedSurface(this.object, this.selector, this.reason);
}

/// Intención de la superficie editable. `any` queda para los consumidores
/// genéricos; las acciones mutantes deben pedir una superficie específica.
enum InputSurfaceKind { any, message, search }

/// Selector más grounded posible para un objeto: resourceId > text > desc >
/// flag estructural. El resourceId es el más estable; `editable=true` es el
/// último recurso (puede ser ambiguo, pero nunca inventa un id/text).
String surfaceSelectorFor(NanoUiObject o) {
  if (o.resourceId.isNotEmpty) return 'id=${o.resourceId}';
  if (o.text.isNotEmpty) return 'text=${o.text}';
  if (o.description.isNotEmpty) return 'desc=${o.description}';
  return 'editable=true';
}

/// Encuentra un nodo editable REAL para escribir (composer, buscador, campo).
///
/// La intención de la operación filtra los campos antes de priorizarlos: una
/// búsqueda no puede escribir en el compositor, ni un mensaje en el buscador.
/// Solo `any` admite el fallback a cualquier editable visible.
class InputSurfaceResolver {
  const InputSurfaceResolver();

  static const _messageHints = [
    'mensaje',
    'message',
    'escribe',
    'type',
    'compose',
  ];

  static const _searchHints = ['buscar', 'search', 'busca', 'consulta', 'find'];

  ResolvedSurface? resolve(
    ScreenGraph graph, {
    InputSurfaceKind kind = InputSurfaceKind.any,
  }) {
    // Un snapshot truncado invalida una conclusión negativa, pero no una
    // superficie positiva ya observada y anclada. Apps con árboles profundos
    // (WhatsApp) pueden superar el límite en una rama irrelevante mientras el
    // input buscado sí está presente. El ejecutor volverá a resolver el
    // selector sobre un snapshot fresco y exigirá unicidad/actionability.
    final editables = graph.objects
        .where((o) => o.visible && o.editable)
        .toList(growable: false);
    if (editables.isEmpty) return null;

    final candidates = editables
        .where((o) => _matchesKind(o, kind))
        .toList(growable: false);
    if (candidates.isEmpty) return null;

    for (final o in candidates) {
      if (o.focused) {
        return ResolvedSurface(o, surfaceSelectorFor(o), 'focused editable');
      }
    }
    for (final o in candidates) {
      if (_matchesRole(o, kind)) {
        return ResolvedSurface(o, surfaceSelectorFor(o), '${o.role.name} role');
      }
    }
    final o = candidates.first;
    return ResolvedSurface(o, surfaceSelectorFor(o), 'matching editable');
  }

  bool _matchesKind(NanoUiObject object, InputSurfaceKind kind) {
    if (kind == InputSurfaceKind.any) return true;

    final hints = switch (kind) {
      InputSurfaceKind.message => _messageHints,
      InputSurfaceKind.search => _searchHints,
      InputSurfaceKind.any => const <String>[],
    };
    final roleMatches = _matchesRole(object, kind);
    final hay = '${object.text} ${object.description} ${object.label}'
        .toLowerCase();
    return roleMatches || hints.any(hay.contains);
  }

  bool _matchesRole(NanoUiObject object, InputSurfaceKind kind) =>
      switch (kind) {
        InputSurfaceKind.any =>
          object.role == SemanticRole.textField ||
              object.role == SemanticRole.searchField,
        InputSurfaceKind.message => object.role == SemanticRole.textField,
        InputSurfaceKind.search => object.role == SemanticRole.searchField,
      };
}

/// Encuentra el botón de ACCIÓN semántica (enviar/buscar/ir) asociado al input
/// activo. Sustituye `tap('desc=Enviar')`: el botón se identifica por rol
/// (button/iconButton) + términos semánticos, y se prefiere el más cercano al
/// input activo (relación de posición con el compositor).
class ActionSurfaceResolver {
  const ActionSurfaceResolver();

  final InputSurfaceResolver _input = const InputSurfaceResolver();

  static const _sendTerms = [
    'enviar',
    'send',
    'enviar mensaje',
    'send message',
  ];

  /// Términos del punto de ENTRADA de búsqueda (lupa/icono). Deliberadamente
  /// SIN 'ir'/'go'/'siguiente': esos son submit (teclado) y darían falsos
  /// positivos en el fallback de conversación.
  static const _searchTerms = [
    'buscar',
    'search',
    'busca',
    'busqueda',
    'búsqueda',
    'find',
  ];

  ResolvedSurface? resolve(ScreenGraph graph, {String kind = 'send'}) {
    // Igual que en InputSurfaceResolver: la truncación impide afirmar
    // ausencia, no descarta evidencia positiva ya observada. La acción final
    // conserva re-resolución, estabilidad y actionability en el executor.
    final terms = kind == 'search' ? _searchTerms : _sendTerms;

    final buttons = graph.objects
        .where((o) {
          if (!o.visible || !o.enabled) return false;
          final isSemanticButton =
              o.role == SemanticRole.button ||
              o.role == SemanticRole.iconButton;
          // Algunas apps modernas (WhatsApp incluido) modelan la barra que
          // abre la búsqueda como un contenedor clickable con hijos. El
          // normalizador la clasifica correctamente como `card`, no como
          // botón. Para `search` aceptamos esa superficie accionable siempre
          // que tenga evidencia semántica explícita; para `send` mantenemos el
          // contrato estricto de botón y evitamos tocar contenedores amplios.
          if (!isSemanticButton && !(kind == 'search' && o.clickable)) {
            return false;
          }
          final hay = '${o.label} ${o.text} ${o.description} ${o.resourceId}'
              .toLowerCase();
          return terms.any(hay.contains);
        })
        .toList(growable: false);
    if (buttons.isEmpty) return null;

    var best = buttons.first;
    var reason = 'action button ($kind)';
    final input = _input.resolve(
      graph,
      kind: kind == 'search'
          ? InputSurfaceKind.search
          : InputSurfaceKind.message,
    );
    if (input != null) {
      var bestDist = double.infinity;
      for (final b in buttons) {
        final d = b.bounds.distanceTo(input.object.bounds).toDouble();
        if (d < bestDist) {
          bestDist = d;
          best = b;
        }
      }
      reason = 'action button ($kind) near input';
    }
    return ResolvedSurface(best, surfaceSelectorFor(best), reason);
  }
}
