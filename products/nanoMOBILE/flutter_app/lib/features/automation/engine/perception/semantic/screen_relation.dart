/// ScreenRelation (A7) — relación tipada dirigida entre objetos semánticos.
///
/// `contains` ≠ `insideOf` (dirección). Las relaciones se derivan de la
/// jerarquía (parentId), los bounds espaciales y la proximidad label→field.
library;

enum ScreenRelationType {
  contains,
  insideOf,
  above,
  below,
  leftOf,
  rightOf,
  near,
  labelFor,
  associatedWith,
  belongsToList,
  repeatedWith,
  primaryActionOf,
}

class ScreenRelation {
  final String sourceId;
  final ScreenRelationType type;
  final String targetId;
  final double confidence;

  const ScreenRelation({
    required this.sourceId,
    required this.type,
    required this.targetId,
    required this.confidence,
  });
}
