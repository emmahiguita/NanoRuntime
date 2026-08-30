/// Clasificación determinista de la superficie observada por Automation.
library;

import 'current_situation.dart';
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
      observedAt: observedAt,
    );
  }

  (CurrentSurfaceKind, List<NanoUiObject>) _classify(
    List<NanoUiObject> observed,
  ) {
    final dialogs = _withRoles(observed, const {SemanticRole.dialog});
    if (dialogs.isNotEmpty) return (CurrentSurfaceKind.dialog, dialogs);

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
