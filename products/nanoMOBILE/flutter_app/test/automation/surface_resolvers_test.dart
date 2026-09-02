import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/perception/nano_snapshot.dart';
import 'package:nanoai/features/automation/engine/perception/semantic/screen_graph.dart';
import 'package:nanoai/features/automation/engine/perception/surface_resolvers.dart';

NanoNode n(
  int index, {
  int depth = 0,
  String type = '',
  String text = '',
  String desc = '',
  String id = '',
  bool editable = false,
  bool clickable = false,
  bool focused = false,
  int l = 0,
  int t = 0,
  int r = 100,
  int b = 100,
}) => NanoNode(
  index: index,
  depth: depth,
  id: id,
  type: type,
  text: text,
  description: desc,
  clickable: clickable,
  editable: editable,
  scrollable: false,
  checked: false,
  focusable: false,
  focused: focused,
  visible: true,
  enabled: true,
  bounds: NanoBounds(left: l, top: t, right: r, bottom: b),
);

ScreenGraph graph(List<NanoNode> nodes) =>
    ScreenGraph.fromSnapshot(NanoSnapshot(package: 'com.t', nodes: nodes));

ScreenGraph truncatedGraph(List<NanoNode> nodes) => ScreenGraph.fromSnapshot(
  NanoSnapshot(package: 'com.t', nodes: nodes, truncated: true),
);

void main() {
  group('InputSurfaceResolver', () {
    test('prefiere el editable con resourceId (selector grounded)', () {
      final s = const InputSurfaceResolver().resolve(
        graph([
          n(
            0,
            type: 'android.widget.EditText',
            id: 'com.t:id/composer',
            editable: true,
            text: 'Mensaje',
          ),
        ]),
      );
      expect(s, isNotNull);
      expect(s!.selector, 'id=com.t:id/composer');
      expect(s.reason, contains('textField'));
    });

    test('editable enfocado gana (focus real)', () {
      final s = const InputSurfaceResolver().resolve(
        graph([
          n(0, type: 'android.widget.EditText', editable: true),
          n(1, type: 'android.widget.EditText', editable: true, focused: true),
        ]),
      );
      expect(s!.reason, 'focused editable');
    });

    test('sin editable → null (honesto, no inventa selector)', () {
      final s = const InputSurfaceResolver().resolve(
        graph([
          n(0, type: 'android.widget.Button', text: 'OK', clickable: true),
        ]),
      );
      expect(s, isNull);
    });

    test('snapshot truncado → null aunque exista un editable', () {
      final surface = const InputSurfaceResolver().resolve(
        truncatedGraph([n(0, type: 'android.widget.EditText', editable: true)]),
      );
      expect(surface, isNull);
    });
  });

  group('ActionSurfaceResolver (send)', () {
    test('resuelve botón Enviar cerca del input', () {
      final s = const ActionSurfaceResolver().resolve(
        graph([
          n(
            0,
            type: 'android.widget.EditText',
            id: 'com.t:id/composer',
            editable: true,
            l: 0,
            t: 0,
            r: 200,
            b: 100,
          ),
          n(
            1,
            type: 'android.widget.ImageButton',
            id: 'com.t:id/send',
            desc: 'Enviar',
            clickable: true,
            l: 200,
            t: 0,
            r: 300,
            b: 100,
          ),
        ]),
      );
      expect(s, isNotNull);
      expect(s!.selector, 'id=com.t:id/send');
      expect(s.reason, contains('send'));
    });

    test('sin botón de envío → null', () {
      final s = const ActionSurfaceResolver().resolve(
        graph([
          n(
            0,
            type: 'android.widget.EditText',
            id: 'com.t:id/composer',
            editable: true,
          ),
        ]),
      );
      expect(s, isNull);
    });
  });

  group('ActionSurfaceResolver (search)', () {
    test('resuelve botón Buscar', () {
      final s = const ActionSurfaceResolver().resolve(
        graph([
          n(
            0,
            type: 'android.widget.EditText',
            editable: true,
            id: 'com.t:id/search_src',
          ),
          n(
            1,
            type: 'android.widget.ImageButton',
            desc: 'Buscar',
            clickable: true,
            id: 'com.t:id/search_go',
          ),
        ]),
        kind: 'search',
      );
      expect(s, isNotNull);
      expect(s!.selector, 'id=com.t:id/search_go');
    });
  });
}
