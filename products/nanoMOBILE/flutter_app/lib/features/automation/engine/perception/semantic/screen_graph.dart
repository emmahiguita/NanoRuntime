/// ScreenGraph (A7) — representación semántica de la pantalla actual.
///
/// Contiene package, objetos semánticos y relaciones. Se construye desde un
/// [NanoSnapshot] (Accessibility) vía [SemanticNormalizer] + [RelationshipEngine].
/// Es un modelo de datos transitorio: NO genera prompts, NO persiste, NO ejecuta.
library;

import '../nano_snapshot.dart' show NanoSnapshot, NanoWindow;
import 'nano_ui_object.dart';
import 'relationship_engine.dart';
import 'screen_relation.dart';
import 'semantic_normalizer.dart';
import 'semantic_role.dart';

class ScreenGraph {
  final String package;
  final List<NanoUiObject> objects;
  final List<ScreenRelation> relations;
  final bool truncated;
  final bool nodeLimitReached;
  final bool depthLimitReached;
  final List<NanoWindow> windows;

  final Map<String, NanoUiObject> _byId;
  final Map<String, List<ScreenRelation>> _bySource;

  ScreenGraph({
    required this.package,
    required this.objects,
    required this.relations,
    this.truncated = false,
    this.nodeLimitReached = false,
    this.depthLimitReached = false,
    this.windows = const [],
  }) : _byId = {for (final o in objects) o.id: o},
       _bySource = _index(relations);

  factory ScreenGraph.fromSnapshot(NanoSnapshot snapshot) {
    final objects = const SemanticNormalizer().normalize(snapshot);
    final relations = const RelationshipEngine().build(objects);
    return ScreenGraph(
      package: snapshot.package,
      objects: objects,
      relations: relations,
      truncated: snapshot.truncated,
      nodeLimitReached: snapshot.nodeLimitReached,
      depthLimitReached: snapshot.depthLimitReached,
      windows: snapshot.windows,
    );
  }

  bool get isEmpty => objects.isEmpty;
  bool get complete => !truncated;

  NanoUiObject? objectById(String id) => _byId[id];

  List<NanoUiObject> objectsByRole(SemanticRole role) =>
      objects.where((o) => o.role == role).toList(growable: false);

  List<NanoUiObject> get editableObjects =>
      objects.where((o) => o.isEditableRole).toList(growable: false);

  List<NanoUiObject> get clickableObjects =>
      objects.where((o) => o.clickable && o.visible).toList(growable: false);

  List<ScreenRelation> relationsOf(String id) => _bySource[id] ?? const [];

  List<NanoUiObject> childrenOf(String id) => [
    for (final r in _bySource[id] ?? const <ScreenRelation>[])
      if (r.type == ScreenRelationType.contains && _byId[r.targetId] != null)
        _byId[r.targetId]!,
  ];

  NanoUiObject? parentOf(String id) {
    final parentId = _byId[id]?.parentId;
    if (parentId == null) return null;
    return _byId[parentId];
  }

  static Map<String, List<ScreenRelation>> _index(
    List<ScreenRelation> relations,
  ) {
    final index = <String, List<ScreenRelation>>{};
    for (final r in relations) {
      index.putIfAbsent(r.sourceId, () => <ScreenRelation>[]).add(r);
    }
    return index.map((k, v) => MapEntry(k, List.unmodifiable(v)));
  }
}
