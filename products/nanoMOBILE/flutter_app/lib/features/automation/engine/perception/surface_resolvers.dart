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
import 'surface_profiles.dart';

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
  if (o.label.isNotEmpty) return 'text=${o.label}';
  return 'editable=true';
}

/// Encuentra un nodo editable REAL para escribir (composer, buscador, campo).
///
/// La intención de la operación filtra los campos antes de priorizarlos: una
/// búsqueda no puede escribir en el compositor, ni un mensaje en el buscador.
/// Solo `any` admite el fallback a cualquier editable visible.
class InputSurfaceResolver {
  const InputSurfaceResolver({
    SurfaceProfileSource profiles = const SurfaceProfileRegistry(),
  }) : _profiles = profiles;

  final SurfaceProfileSource _profiles;

  ResolvedSurface? resolve(
    ScreenGraph graph, {
    InputSurfaceKind kind = InputSurfaceKind.any,
  }) {
    // Un snapshot truncado invalida una conclusión negativa, pero no una
    // superficie positiva ya observada y anclada. Los árboles profundos pueden
    // superar el límite en una rama irrelevante mientras el input buscado sí
    // está presente. El ejecutor volverá a resolver el
    // selector sobre un snapshot fresco y exigirá unicidad/actionability.
    final editables = graph.objects
        .where((o) => o.visible && o.editable)
        .toList(growable: false);
    if (editables.isEmpty) return null;

    final profiles = _profiles.resolve(graph.package, _elementKindFor(kind));
    for (final profile in profiles) {
      final candidates = editables
          .where((o) => _matchesKind(o, kind, profile))
          .toList(growable: false);
      if (candidates.isEmpty) continue;

      for (final o in candidates) {
        if (o.focused) {
          return ResolvedSurface(
            o,
            surfaceSelectorFor(o),
            'focused editable (${profile.sourceProfileId})',
          );
        }
      }
      for (final o in candidates) {
        if (profile.matchesRole(o.role)) {
          return ResolvedSurface(
            o,
            surfaceSelectorFor(o),
            '${o.role.name} role (${profile.sourceProfileId})',
          );
        }
      }
      final o = candidates.first;
      return ResolvedSurface(
        o,
        surfaceSelectorFor(o),
        'matching editable (${profile.sourceProfileId})',
      );
    }
    return null;
  }

  bool _matchesKind(
    NanoUiObject object,
    InputSurfaceKind kind,
    ResolvedSurfaceProfile profile,
  ) {
    if (kind == InputSurfaceKind.any) return true;

    final hay = '${object.text} ${object.description} ${object.label}'
        .toLowerCase();
    return profile.matchesRole(object.role) || profile.matchesTerms(hay);
  }

  SurfaceElementKind _elementKindFor(InputSurfaceKind kind) => switch (kind) {
    InputSurfaceKind.any => SurfaceElementKind.anyInput,
    InputSurfaceKind.message => SurfaceElementKind.messageInput,
    InputSurfaceKind.search => SurfaceElementKind.searchInput,
  };
}

/// Encuentra el botón de ACCIÓN semántica (enviar/buscar/ir) asociado al input
/// activo. Sustituye `tap('desc=Enviar')`: el botón se identifica por rol
/// (button/iconButton) + términos semánticos, y se prefiere el más cercano al
/// input activo (relación de posición con el compositor).
class ActionSurfaceResolver {
  const ActionSurfaceResolver({
    SurfaceProfileSource profiles = const SurfaceProfileRegistry(),
  }) : _profiles = profiles;

  final SurfaceProfileSource _profiles;

  ResolvedSurface? resolve(ScreenGraph graph, {String kind = 'send'}) {
    // Igual que en InputSurfaceResolver: la truncación impide afirmar
    // ausencia, no descarta evidencia positiva ya observada. La acción final
    // conserva re-resolución, estabilidad y actionability en el executor.
    final elementKind = switch (kind) {
      'send' => SurfaceElementKind.sendAction,
      'search' => SurfaceElementKind.searchAction,
      _ => null,
    };
    if (elementKind == null) return null;
    final profiles = _profiles.resolve(graph.package, elementKind);
    for (final profile in profiles) {
      final buttons = graph.objects
          .where((o) {
            if (!o.visible || !o.enabled) return false;
            final matchesRole = profile.matchesRole(o.role);
            if (!matchesRole &&
                !(profile.allowClickableContainer && o.clickable)) {
              return false;
            }
            final hay = '${o.label} ${o.text} ${o.description} ${o.resourceId}'
                .toLowerCase();
            return profile.matchesTerms(hay);
          })
          .toList(growable: false);
      if (buttons.isEmpty) continue;

      var best = buttons.first;
      var reason = 'action button ($kind, ${profile.sourceProfileId})';
      final input = InputSurfaceResolver(profiles: _profiles).resolve(
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
        reason = 'action button ($kind, ${profile.sourceProfileId}) near input';
      }
      return ResolvedSurface(best, surfaceSelectorFor(best), reason);
    }
    return null;
  }
}
