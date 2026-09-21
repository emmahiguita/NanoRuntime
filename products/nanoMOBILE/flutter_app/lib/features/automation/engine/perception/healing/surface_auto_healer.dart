// surface_auto_healer.dart
//
// Motor de auto-reparación semántica y geométrica para aplicaciones actualizadas.
// - ¿Qué hace?: Localiza componentes cuando las apps cambian sus IDs o textos nativos,
//   usando relaciones espaciales y semántica estructural en lugar de strings fijos.
// - ¿Cómo funciona?: Evalúa posición (Y inferior para chat, Y superior para búsqueda),
//   roles de accesibilidad y adyacencia. Si la confianza supera 0.75, repara el perfil
//   y lo guarda en DynamicSurfaceStore; si no, suspende de forma segura.
// - ¿Por qué?: Resuelve la fragilidad ante actualizaciones de WhatsApp, Telegram o Gmail
//   sin requerir intervención humana en el código fuente.

library;

import '../semantic/nano_ui_object.dart';
import '../semantic/screen_graph.dart';
import '../semantic/semantic_role.dart';
import '../surface_profiles.dart';
import '../surface_resolvers.dart';
import 'dynamic_surface_store.dart';
import 'safe_action_suspension.dart';

/// Motor de auto-reparación y localización geométrica ante cambios de interfaz.
final class SurfaceAutoHealer implements SurfaceHealerFallback {
  SurfaceAutoHealer({DynamicSurfaceStore? store})
      : _store = store ?? globalDynamicSurfaceStore;

  final DynamicSurfaceStore _store;

  @override
  ResolvedSurface? tryHealInput(ScreenGraph graph, {required InputSurfaceKind kind}) {
    final (surface, _) = healInput(graph, kind: kind);
    return surface;
  }

  @override
  ResolvedSurface? tryHealAction(ScreenGraph graph, {required String actionKind}) {
    final (surface, _) = healAction(graph, actionKind: actionKind);
    return surface;
  }

  /// Intenta auto-reparar la localización de un campo de entrada editable.
  (ResolvedSurface?, SafeActionSuspension?) healInput(
    ScreenGraph graph, {
    required InputSurfaceKind kind,
  }) {
    final editables = graph.objects
        .where((o) => o.visible && o.editable)
        .toList(growable: false);

    if (editables.isEmpty) {
      return (null, SafeActionSuspension(
        packageName: graph.package,
        targetKind: kind == InputSurfaceKind.search ? SurfaceElementKind.searchInput : SurfaceElementKind.messageInput,
        reason: 'No hay campos editables visibles en la pantalla actual',
        confidence: 0.0,
        timestamp: DateTime.now(),
      ));
    }

    NanoUiObject candidate;
    double confidence = 0.0;

    if (kind == InputSurfaceKind.message) {
      editables.sort((a, b) => b.bounds.bottom.compareTo(a.bounds.bottom));
      candidate = editables.first;
      confidence = candidate.focused ? 0.95 : 0.85;
    } else if (kind == InputSurfaceKind.search) {
      editables.sort((a, b) => a.bounds.top.compareTo(b.bounds.top));
      candidate = editables.first;
      confidence = candidate.focused ? 0.95 : 0.85;
    } else {
      candidate = editables.first;
      confidence = 0.80;
    }

    if (confidence >= 0.75) {
      _learnInput(graph.package, kind, candidate);
      return (ResolvedSurface(
        candidate,
        surfaceSelectorFor(candidate),
        'auto-healed: posición espacial heurística (confianza ${(confidence * 100).toInt()}%)',
      ), null);
    }

    return (null, SafeActionSuspension(
      packageName: graph.package,
      targetKind: kind == InputSurfaceKind.search ? SurfaceElementKind.searchInput : SurfaceElementKind.messageInput,
      reason: 'Confianza de localización insuficiente tras cambio de UI',
      confidence: confidence,
      candidates: editables,
      timestamp: DateTime.now(),
    ));
  }

  /// Intenta auto-reparar la localización de un botón de acción adyacente al compositor.
  (ResolvedSurface?, SafeActionSuspension?) healAction(
    ScreenGraph graph, {
    required String actionKind,
    NanoUiObject? anchorInput,
  }) {
    final buttons = graph.objects
        .where((o) => o.visible && o.enabled && (o.clickable || o.role == SemanticRole.iconButton || o.role == SemanticRole.button))
        .toList(growable: false);

    if (buttons.isEmpty) {
      return (null, SafeActionSuspension(
        packageName: graph.package,
        targetKind: SurfaceElementKind.sendAction,
        reason: 'No se encontraron botones o iconos accionables',
        confidence: 0.0,
        timestamp: DateTime.now(),
      ));
    }

    NanoUiObject? best;
    double bestConfidence = 0.0;

    for (final btn in buttons) {
      double score = 0.0;
      if (btn.role == SemanticRole.iconButton || btn.role == SemanticRole.button) score += 0.4;
      if (anchorInput != null) {
        final centerYDiff = (btn.bounds.centerY - anchorInput.bounds.centerY).abs();
        if (centerYDiff < 120) score += 0.4; // Misma fila inferior
        if (btn.bounds.left >= anchorInput.bounds.right - 40) score += 0.15; // A la derecha
      }
      if (score > bestConfidence) {
        bestConfidence = score;
        best = btn;
      }
    }

    if (bestConfidence >= 0.75 && best != null) {
      _learnAction(graph.package, actionKind, best);
      return (ResolvedSurface(
        best,
        surfaceSelectorFor(best),
        'auto-healed: adyacencia espacial (confianza ${(bestConfidence * 100).toInt()}%)',
      ), null);
    }

    return (null, SafeActionSuspension(
      packageName: graph.package,
      targetKind: SurfaceElementKind.sendAction,
      reason: 'No se encontró un botón con adyacencia segura al compositor',
      confidence: bestConfidence,
      candidates: buttons.take(3).toList(),
      timestamp: DateTime.now(),
    ));
  }

  void _learnInput(String pkg, InputSurfaceKind kind, NanoUiObject obj) {
    final term = obj.description.isNotEmpty ? obj.description : (obj.text.isNotEmpty ? obj.text : obj.resourceId);
    if (term.isEmpty) return;
    _store.registerHealedElement(
      packageName: pkg,
      kind: kind == InputSurfaceKind.search ? SurfaceElementKind.searchInput : SurfaceElementKind.messageInput,
      roles: {obj.role}, terms: [term.toLowerCase()],
    );
  }

  void _learnAction(String pkg, String actionKind, NanoUiObject obj) {
    final term = obj.description.isNotEmpty ? obj.description : obj.label;
    if (term.isEmpty) return;
    _store.registerHealedElement(
      packageName: pkg, kind: SurfaceElementKind.sendAction,
      roles: {obj.role}, terms: [term.toLowerCase()],
      allowClickableContainer: obj.clickable,
    );
  }
}

/// Registro e inicialización global para auto-reparación en tiempo de ejecución.
final globalSurfaceAutoHealer = () {
  final h = SurfaceAutoHealer();
  registerGlobalSurfaceHealer(h);
  return h;
}();
