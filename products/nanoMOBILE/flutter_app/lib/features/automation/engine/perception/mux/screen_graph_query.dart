/// ScreenGraphQuery (A8) — matching semántico sobre el ScreenGraph.
///
/// Determinista, sin LLM. Matching por label/text/description/resourceId, con
/// filtro de [SemanticRole] y resolución relationship-aware (labelFor → campo).
library;

import '../semantic/nano_ui_object.dart';
import '../semantic/screen_graph.dart';
import '../semantic/screen_relation.dart';
import '../semantic/semantic_role.dart';
import 'perception_contracts.dart';

class ScreenGraphMatch {
  final NanoUiObject object;
  final double confidence;

  const ScreenGraphMatch({required this.object, required this.confidence});
}

class ScreenGraphQuery {
  const ScreenGraphQuery();

  List<ScreenGraphMatch> query(ScreenGraph graph, PerceptionRequest request) {
    final concept = request.targetConcept.trim().toLowerCase();
    final matches = <ScreenGraphMatch>[];

    // 1. matching directo con filtro de role.
    for (final obj in graph.objects) {
      if (!obj.visible) continue;
      if (request.expectedRole != null && obj.role != request.expectedRole) {
        continue;
      }
      final score = _matchScore(obj, concept);
      if (score > 0) {
        matches.add(ScreenGraphMatch(object: obj, confidence: score));
      }
    }

    // 2. relationship-aware: el concepto matchea un label que apunta (labelFor)
    //    a un campo editable → resuelve el campo, no el label.
    if (request.expectedRole != null && _isEditable(request.expectedRole!)) {
      for (final obj in graph.objects) {
        if (obj.role != SemanticRole.text || !obj.visible) continue;
        final labelScore = _matchScore(obj, concept);
        if (labelScore <= 0) continue;
        for (final r in graph.relationsOf(obj.id)) {
          if (r.type != ScreenRelationType.labelFor) continue;
          final field = graph.objectById(r.targetId);
          if (field != null && field.role == request.expectedRole) {
            matches.add(
              ScreenGraphMatch(object: field, confidence: labelScore * 0.95),
            );
          }
        }
      }
    }

    matches.sort((a, b) => b.confidence.compareTo(a.confidence));
    return matches;
  }

  double _matchScore(NanoUiObject obj, String concept) {
    final label = obj.label.trim().toLowerCase();
    final text = obj.text.trim().toLowerCase();
    final desc = obj.description.trim().toLowerCase();
    final id = obj.resourceId.toLowerCase();
    if (label.isNotEmpty && label == concept) return 0.98;
    if (text.isNotEmpty && text == concept) return 0.95;
    if (desc.isNotEmpty && desc == concept) return 0.92;
    if (id.isNotEmpty && id.contains(concept)) return 0.85;
    if (label.isNotEmpty && label.contains(concept)) return 0.75;
    if (text.isNotEmpty && text.contains(concept)) return 0.70;
    if (desc.isNotEmpty && desc.contains(concept)) return 0.70;
    return 0.0;
  }

  bool _isEditable(SemanticRole r) =>
      r == SemanticRole.textField ||
      r == SemanticRole.searchField ||
      r == SemanticRole.passwordField;
}
