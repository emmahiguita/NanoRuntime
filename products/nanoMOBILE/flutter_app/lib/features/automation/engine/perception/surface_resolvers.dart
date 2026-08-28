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
/// Escalera determinista (primero lo más específico):
/// 1. editable enfocado (el usuario/la app ya puso foco ahí);
/// 2. rol textField/searchField (clasificación semántica de Accessibility);
/// 3. editable cuyo hint alude a mensaje/búsqueda ("mensaje", "buscar", "search");
/// 4. cualquier editable visible (fallback honesto).
class InputSurfaceResolver {
  const InputSurfaceResolver();

  static const _messageHints = [
    'mensaje',
    'message',
    'escribe',
    'type',
    'compose',
  ];

  static const _searchHints = [
    'buscar',
    'search',
    'busca',
    'consulta',
    'find',
  ];

  ResolvedSurface? resolve(ScreenGraph graph) {
    final editables = graph.objects
        .where((o) => o.visible && o.editable)
        .toList(growable: false);
    if (editables.isEmpty) return null;

    for (final o in editables) {
      if (o.focused) {
        return ResolvedSurface(o, surfaceSelectorFor(o), 'focused editable');
      }
    }
    for (final o in editables) {
      if (o.role == SemanticRole.textField ||
          o.role == SemanticRole.searchField) {
        return ResolvedSurface(
          o,
          surfaceSelectorFor(o),
          '${o.role.name} role',
        );
      }
    }
    final hints = [..._messageHints, ..._searchHints];
    for (final o in editables) {
      final hay = '${o.text} ${o.description} ${o.label}'.toLowerCase();
      for (final h in hints) {
        if (hay.contains(h)) {
          return ResolvedSurface(o, surfaceSelectorFor(o), 'hint "$h"');
        }
      }
    }
    final o = editables.first;
    return ResolvedSurface(o, surfaceSelectorFor(o), 'visible editable');
  }
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
    final terms = kind == 'search' ? _searchTerms : _sendTerms;

    final buttons = graph.objects.where((o) {
      if (!o.visible) return false;
      if (o.role != SemanticRole.button &&
          o.role != SemanticRole.iconButton) {
        return false;
      }
      final hay = '${o.label} ${o.text} ${o.description}'.toLowerCase();
      return terms.any(hay.contains);
    }).toList(growable: false);
    if (buttons.isEmpty) return null;

    var best = buttons.first;
    var reason = 'action button ($kind)';
    final input = _input.resolve(graph);
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
