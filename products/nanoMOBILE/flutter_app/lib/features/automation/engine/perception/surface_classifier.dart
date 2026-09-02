/// Clasificación determinista de la superficie observada por Automation.
library;

import 'current_situation.dart';
import 'entity_identity_resolver.dart';
import 'semantic/nano_ui_object.dart';
import 'semantic/screen_graph.dart';
import 'semantic/semantic_role.dart';

/// Único dueño de la transformación `ScreenGraph → CurrentSituation`.
///
/// Solo usa señales positivas ya normalizadas desde accesibilidad. No examina
/// paquetes, marcas ni texto específico de una aplicación; si no hay evidencia
/// semántica suficiente conserva la situación como [CurrentSurfaceKind.unknown].
final class SurfaceClassifier {
  const SurfaceClassifier();

  CurrentSituation? classify(
    ScreenGraph graph, {
    required DateTime observedAt,
  }) {
    if (graph.isEmpty) return null;

    final observed = graph.objects
        .where(_isGroundedVisibleObject)
        .toList(growable: false);
    final (kind, evidence) = _classify(observed);
    // Identidad activa estructural: el nombre del chat en el header de una
    // superficie editable. Texto visible incidental nunca es identidad.
    final identity = const EntityIdentityResolver().resolve(graph, kind);
    return CurrentSituation(
      structuralEvidence: graph,
      surfaceKind: kind,
      classificationEvidence: [
        for (final object in evidence)
          SituationEvidence(
            objectId: object.id,
            role: object.role,
            confidence: object.confidence,
            sources: object.evidence,
          ),
      ],
      entity: identity?.entity,
      entityEvidence: identity?.evidence ?? const [],
      observedAt: observedAt,
    );
  }

  (CurrentSurfaceKind, List<NanoUiObject>) _classify(
    List<NanoUiObject> observed,
  ) {
    final dialogs = _withRoles(observed, const {SemanticRole.dialog});
    if (dialogs.isNotEmpty) return (CurrentSurfaceKind.dialog, dialogs);

    // Un campo de búsqueda observado domina sobre la superficie de escritura:
    // buscar y conversar son estados distintos para el diff, aunque ambos
    // expongan un campo editable. El diálogo conserva prioridad porque puede
    // contener su propio searchField (filtro) y debe cerrarse primero.
    final searches = _withRoles(observed, const {SemanticRole.searchField});
    if (searches.isNotEmpty) return (CurrentSurfaceKind.search, searches);

    final editables = observed
        .where((object) => object.isEditableRole)
        .toList(growable: false);
    if (editables.isNotEmpty) {
      return (CurrentSurfaceKind.editable, editables);
    }

    final collections = _withRoles(observed, const {
      SemanticRole.list,
      SemanticRole.listItem,
      SemanticRole.grid,
    });
    if (collections.isNotEmpty) {
      return (CurrentSurfaceKind.collection, collections);
    }

    final content = observed
        .where((object) => object.role != SemanticRole.keyboard)
        .toList(growable: false);
    if (content.isNotEmpty) return (CurrentSurfaceKind.content, content);

    return (CurrentSurfaceKind.unknown, const []);
  }

  List<NanoUiObject> _withRoles(
    List<NanoUiObject> objects,
    Set<SemanticRole> roles,
  ) => objects
      .where((object) => roles.contains(object.role))
      .toList(growable: false);

  bool _isGroundedVisibleObject(NanoUiObject object) =>
      object.visible &&
      object.role != SemanticRole.unknown &&
      object.evidence.isNotEmpty;
}
