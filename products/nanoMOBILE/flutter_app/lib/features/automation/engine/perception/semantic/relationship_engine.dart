/// RelationshipEngine (A7) — infiere relaciones tipadas entre objetos.
///
/// Determinista, sin IO/LLM. Jerarquía (contains/insideOf) del parentId; above/
/// below de bounds alineados; labelFor de proximidad label→campo; belongsToList
/// de listItem→list. Thresholds relativos al viewport (sin números mágicos
/// rígidos por device). O(n²) solo entre objetos visibles (guardrail).
library;

import 'nano_ui_object.dart';
import 'screen_relation.dart';
import 'semantic_role.dart';

class RelationshipEngine {
  const RelationshipEngine();

  List<ScreenRelation> build(List<NanoUiObject> objects) {
    final relations = <ScreenRelation>[];
    final byId = {for (final o in objects) o.id: o};
    final viewport = _viewport(objects);

    // 1. jerarquía (contains / insideOf).
    for (final o in objects) {
      final parent = o.parentId;
      if (parent != null && byId.containsKey(parent)) {
        relations.add(
          ScreenRelation(
            sourceId: parent,
            type: ScreenRelationType.contains,
            targetId: o.id,
            confidence: 1.0,
          ),
        );
        relations.add(
          ScreenRelation(
            sourceId: o.id,
            type: ScreenRelationType.insideOf,
            targetId: parent,
            confidence: 1.0,
          ),
        );
      }
    }

    // 2. espacial + labelFor (solo objetos visibles, O(n²) acotado).
    final visible = objects.where((o) => o.visible).toList(growable: false);
    for (var i = 0; i < visible.length; i++) {
      for (var j = i + 1; j < visible.length; j++) {
        if (visible[i].windowId != visible[j].windowId) continue;
        _addSpatial(visible[i], visible[j], relations, viewport);
        _addLabelFor(visible[i], visible[j], relations, viewport);
      }
    }

    // 3. belongsToList (listItem → list).
    for (final o in objects) {
      if (o.role == SemanticRole.listItem && o.parentId != null) {
        final parent = byId[o.parentId];
        if (parent != null &&
            (parent.role == SemanticRole.list ||
                parent.role == SemanticRole.grid)) {
          relations.add(
            ScreenRelation(
              sourceId: o.id,
              type: ScreenRelationType.belongsToList,
              targetId: parent.id,
              confidence: 0.90,
            ),
          );
        }
      }
    }

    return relations;
  }

  void _addSpatial(
    NanoUiObject a,
    NanoUiObject b,
    List<ScreenRelation> out,
    (int, int) viewport,
  ) {
    final xTolerance = (viewport.$1 * 0.12).clamp(20, 200).toDouble();
    final yThreshold = viewport.$2 * 0.12;
    if ((a.bounds.centerX - b.bounds.centerX).abs() >= xTolerance) return;
    final gap = b.bounds.top - a.bounds.bottom; // a encima de b
    if (gap >= 0 && gap < yThreshold) {
      out.add(
        ScreenRelation(
          sourceId: a.id,
          type: ScreenRelationType.above,
          targetId: b.id,
          confidence: 0.80,
        ),
      );
      out.add(
        ScreenRelation(
          sourceId: b.id,
          type: ScreenRelationType.below,
          targetId: a.id,
          confidence: 0.80,
        ),
      );
    } else if (gap < 0 && -gap < yThreshold) {
      out.add(
        ScreenRelation(
          sourceId: b.id,
          type: ScreenRelationType.above,
          targetId: a.id,
          confidence: 0.80,
        ),
      );
      out.add(
        ScreenRelation(
          sourceId: a.id,
          type: ScreenRelationType.below,
          targetId: b.id,
          confidence: 0.80,
        ),
      );
    }
  }

  void _addLabelFor(
    NanoUiObject a,
    NanoUiObject b,
    List<ScreenRelation> out,
    (int, int) viewport,
  ) {
    final (label, field) = _labelFieldPair(a, b);
    if (label == null || field == null) return;
    final gap = field.bounds.top - label.bounds.bottom;
    if (gap < 0 || gap > viewport.$2 * 0.10) return; // label debe estar arriba
    if (label.bounds.xOverlapRatio(field.bounds) < 0.5) return;
    out.add(
      ScreenRelation(
        sourceId: label.id,
        type: ScreenRelationType.labelFor,
        targetId: field.id,
        confidence: 0.85,
      ),
    );
  }

  (NanoUiObject?, NanoUiObject?) _labelFieldPair(
    NanoUiObject a,
    NanoUiObject b,
  ) {
    if (a.role == SemanticRole.text && b.isEditableRole) return (a, b);
    if (b.role == SemanticRole.text && a.isEditableRole) return (b, a);
    return (null, null);
  }

  (int, int) _viewport(List<NanoUiObject> objects) {
    var w = 0;
    var h = 0;
    for (final o in objects) {
      if (o.bounds.right > w) w = o.bounds.right;
      if (o.bounds.bottom > h) h = o.bounds.bottom;
    }
    return (w, h);
  }
}
