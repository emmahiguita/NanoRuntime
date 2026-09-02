import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/perception/nano_snapshot.dart';
import 'package:nanoai/features/automation/engine/perception/semantic/screen_graph.dart';
import 'package:nanoai/features/automation/engine/perception/semantic/screen_relation.dart';
import 'package:nanoai/features/automation/engine/perception/semantic/semantic_role.dart';

NanoNode n(
  int index, {
  int depth = 0,
  String type = '',
  String text = '',
  String desc = '',
  String id = '',
  bool clickable = false,
  bool editable = false,
  bool scrollable = false,
  int windowId = 0,
  int? parentIndex,
  bool hasExplicitParent = false,
  NanoBounds bounds = const NanoBounds(left: 0, top: 0, right: 0, bottom: 0),
}) => NanoNode(
  index: index,
  depth: depth,
  windowId: windowId,
  parentIndex: parentIndex,
  hasExplicitParent: hasExplicitParent,
  id: id,
  type: type,
  text: text,
  description: desc,
  clickable: clickable,
  editable: editable,
  scrollable: scrollable,
  checked: false,
  focusable: false,
  focused: false,
  visible: true,
  enabled: true,
  bounds: bounds,
);

void main() {
  group('ScreenGraph.fromSnapshot', () {
    test('preserva package y construye objetos', () {
      final snap = NanoSnapshot(
        package: 'com.android.settings',
        nodes: [n(0, type: 'android.widget.TextView', text: 'Bluetooth')],
      );
      final g = ScreenGraph.fromSnapshot(snap);
      expect(g.package, 'com.android.settings');
      expect(g.objects, hasLength(1));
      expect(g.objects.single.role, SemanticRole.text);
    });

    test('snapshot vacío → graph vacío válido', () {
      final g = ScreenGraph.fromSnapshot(
        NanoSnapshot(package: '', nodes: const []),
      );
      expect(g.isEmpty, isTrue);
      expect(g.editableObjects, isEmpty);
    });

    test('preserva flags de truncación y metadatos de ventanas', () {
      final window = NanoWindow(
        windowId: 9,
        windowType: 2,
        displayId: 0,
        packageName: 'com.overlay',
        rootIdentity: 'root-9',
        active: false,
        focused: true,
      );
      final graph = ScreenGraph.fromSnapshot(
        NanoSnapshot(
          package: 'com.main',
          nodes: [n(0, type: 'android.widget.TextView', text: 'A')],
          windows: [window],
          truncated: true,
          nodeLimitReached: true,
        ),
      );

      expect(graph.complete, isFalse);
      expect(graph.nodeLimitReached, isTrue);
      expect(graph.windows.single.windowId, 9);
    });

    test('objectsByRole / editableObjects / clickableObjects', () {
      final snap = NanoSnapshot(
        package: 'com.t',
        nodes: [
          n(0, type: 'android.widget.EditText', editable: true),
          n(1, type: 'android.widget.Button', text: 'OK', clickable: true),
          n(2, type: 'android.widget.TextView', text: 'Título'),
        ],
      );
      final g = ScreenGraph.fromSnapshot(snap);
      expect(g.objectsByRole(SemanticRole.textField), hasLength(1));
      expect(g.editableObjects, hasLength(1));
      expect(g.clickableObjects, hasLength(1));
    });

    test('objectById funciona y IDs son únicos', () {
      final snap = NanoSnapshot(
        package: 'com.t',
        nodes: [
          n(0, type: 'android.widget.TextView', text: 'A'),
          n(1, type: 'android.widget.TextView', text: 'B'),
        ],
      );
      final g = ScreenGraph.fromSnapshot(snap);
      expect(g.objectById('ui:0'), isNotNull);
      expect(g.objectById('ui:1'), isNotNull);
      final ids = g.objects.map((o) => o.id).toSet();
      expect(ids.length, g.objects.length); // únicos
    });
  });

  group('relaciones', () {
    test('parent-child → contains/insideOf', () {
      final g = ScreenGraph.fromSnapshot(
        NanoSnapshot(
          package: 'com.t',
          nodes: [
            n(0, type: 'android.widget.LinearLayout'),
            n(1, depth: 1, type: 'android.widget.TextView', text: 'X'),
          ],
        ),
      );
      final rels = g.relationsOf('ui:0');
      expect(
        rels.any(
          (r) => r.type == ScreenRelationType.contains && r.targetId == 'ui:1',
        ),
        isTrue,
      );
      expect(
        g.relationsOf('ui:1').any((r) => r.type == ScreenRelationType.insideOf),
        isTrue,
      );
    });

    test('parentIndex explícito define jerarquía sin inferir por depth', () {
      final graph = ScreenGraph.fromSnapshot(
        NanoSnapshot(
          package: 'com.t',
          nodes: [
            n(0, depth: 0, type: 'android.widget.LinearLayout', windowId: 3),
            n(
              1,
              depth: 0,
              type: 'android.widget.TextView',
              text: 'Hijo',
              windowId: 3,
              parentIndex: 0,
              hasExplicitParent: true,
            ),
          ],
        ),
      );

      expect(graph.parentOf('ui:1')?.id, 'ui:0');
      expect(graph.childrenOf('ui:0').map((item) => item.id), ['ui:1']);
    });

    test('no crea relaciones espaciales entre ventanas diferentes', () {
      final graph = ScreenGraph.fromSnapshot(
        NanoSnapshot(
          package: 'com.t',
          nodes: [
            n(
              0,
              type: 'android.widget.TextView',
              text: 'Etiqueta',
              windowId: 1,
              bounds: const NanoBounds(left: 0, top: 0, right: 200, bottom: 50),
            ),
            n(
              1,
              type: 'android.widget.EditText',
              editable: true,
              windowId: 2,
              bounds: const NanoBounds(
                left: 0,
                top: 60,
                right: 200,
                bottom: 120,
              ),
            ),
          ],
        ),
      );

      expect(graph.relations, isEmpty);
    });

    test('label arriba del campo → above/below + labelFor', () {
      final g = ScreenGraph.fromSnapshot(
        NanoSnapshot(
          package: 'com.t',
          nodes: [
            n(
              0,
              type: 'android.widget.TextView',
              text: 'Correo',
              bounds: const NanoBounds(
                left: 40,
                top: 800,
                right: 1040,
                bottom: 860,
              ),
            ),
            n(
              1,
              type: 'android.widget.EditText',
              editable: true,
              bounds: const NanoBounds(
                left: 40,
                top: 880,
                right: 1040,
                bottom: 960,
              ),
            ),
          ],
        ),
      );
      final relsOfLabel = g.relationsOf('ui:0');
      expect(
        relsOfLabel.any(
          (r) => r.type == ScreenRelationType.above && r.targetId == 'ui:1',
        ),
        isTrue,
      );
      expect(
        relsOfLabel.any(
          (r) => r.type == ScreenRelationType.labelFor && r.targetId == 'ui:1',
        ),
        isTrue,
      );
      expect(
        g.relationsOf('ui:1').any((r) => r.type == ScreenRelationType.below),
        isTrue,
      );
    });

    test('texto lejano → sin labelFor', () {
      final g = ScreenGraph.fromSnapshot(
        NanoSnapshot(
          package: 'com.t',
          nodes: [
            n(
              0,
              type: 'android.widget.TextView',
              text: 'Título lejano',
              bounds: const NanoBounds(
                left: 40,
                top: 100,
                right: 400,
                bottom: 140,
              ),
            ),
            n(
              1,
              type: 'android.widget.EditText',
              editable: true,
              bounds: const NanoBounds(
                left: 40,
                top: 880,
                right: 1040,
                bottom: 960,
              ),
            ),
          ],
        ),
      );
      expect(
        g.relationsOf('ui:0').any((r) => r.type == ScreenRelationType.labelFor),
        isFalse,
      );
    });

    test('listItem → belongsToList', () {
      final g = ScreenGraph.fromSnapshot(
        NanoSnapshot(
          package: 'com.t',
          nodes: [
            n(0, type: 'android.widget.RecyclerView', scrollable: true),
            n(
              1,
              depth: 1,
              type: 'android.widget.LinearLayout',
              clickable: true,
            ),
          ],
        ),
      );
      expect(
        g
            .relationsOf('ui:1')
            .any(
              (r) =>
                  r.type == ScreenRelationType.belongsToList &&
                  r.targetId == 'ui:0',
            ),
        isTrue,
      );
    });

    test('sin auto-relaciones', () {
      final g = ScreenGraph.fromSnapshot(
        NanoSnapshot(
          package: 'com.t',
          nodes: [
            n(0, type: 'android.widget.TextView', text: 'A'),
            n(1, type: 'android.widget.TextView', text: 'B'),
          ],
        ),
      );
      for (final r in g.relations) {
        expect(r.sourceId, isNot(r.targetId));
      }
    });
  });
}
