import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/perception/nano_snapshot.dart';
import 'package:nanoai/features/automation/engine/perception/semantic/nano_ui_object.dart';
import 'package:nanoai/features/automation/engine/perception/semantic/semantic_normalizer.dart';
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
  bool checked = false,
  NanoBounds bounds = const NanoBounds(left: 0, top: 0, right: 0, bottom: 0),
}) => NanoNode(
  index: index,
  depth: depth,
  id: id,
  type: type,
  text: text,
  description: desc,
  clickable: clickable,
  editable: editable,
  scrollable: scrollable,
  checked: checked,
  focusable: false,
  focused: false,
  visible: true,
  enabled: true,
  bounds: bounds,
);

NanoUiObject single(NanoNode node) => const SemanticNormalizer()
    .normalize(NanoSnapshot(package: 'com.t', nodes: [node]))
    .single;

void main() {
  group('roles (hard signals)', () {
    test('EditText editable → textField (0.99)', () {
      final o = single(n(0, type: 'android.widget.EditText', editable: true));
      expect(o.role, SemanticRole.textField);
      expect(o.confidence, 0.99);
    });

    test('search resource evidence → searchField', () {
      final o = single(
        n(
          0,
          type: 'android.widget.EditText',
          editable: true,
          id: 'com.x:id/search_src_text',
        ),
      );
      expect(o.role, SemanticRole.searchField);
      expect(o.confidence, 0.90);
    });

    test('custom editable → textField (0.95)', () {
      final o = single(n(0, type: 'androidx.custom.Editable', editable: true));
      expect(o.role, SemanticRole.textField);
      expect(o.confidence, 0.95);
    });

    test('Switch → switchControl y checked true preservado', () {
      final o = single(n(0, type: 'android.widget.Switch', checked: true));
      expect(o.role, SemanticRole.switchControl);
      expect(o.checked, isTrue);
      expect(o.confidence, 0.99);
    });

    test('CheckBox → checkbox', () {
      final o = single(n(0, type: 'android.widget.CheckBox', checked: false));
      expect(o.role, SemanticRole.checkbox);
    });

    test('Button → button', () {
      final o = single(
        n(0, type: 'android.widget.Button', text: 'Aceptar', clickable: true),
      );
      expect(o.role, SemanticRole.button);
    });

    test('ImageButton → iconButton', () {
      final o = single(
        n(
          0,
          type: 'android.widget.ImageButton',
          desc: 'Cerrar',
          clickable: true,
        ),
      );
      expect(o.role, SemanticRole.iconButton);
    });

    test('plain TextView → text (NO button)', () {
      final o = single(n(0, type: 'android.widget.TextView', text: 'Ajustes'));
      expect(o.role, SemanticRole.text);
      expect(o.role, isNot(SemanticRole.button));
    });

    test('custom unknown view → unknown', () {
      final o = single(n(0, type: 'com.custom.SurfaceView'));
      expect(o.role, SemanticRole.unknown);
    });
  });

  group('card (estructural)', () {
    test('clickable container + children → card (confidence < 1)', () {
      final nodes = [
        n(0, type: 'android.widget.LinearLayout', clickable: true),
        n(1, depth: 1, type: 'android.widget.TextView', text: 'Título'),
      ];
      final objects = const SemanticNormalizer().normalize(
        NanoSnapshot(package: 'com.t', nodes: nodes),
      );
      expect(objects[0].role, SemanticRole.card);
      expect(objects[0].confidence, lessThan(1.0));
    });

    test('clickable leaf → button (NO card)', () {
      final o = single(
        n(0, type: 'android.widget.Button', text: 'OK', clickable: true),
      );
      expect(o.role, SemanticRole.button);
      expect(o.role, isNot(SemanticRole.card));
    });

    test('plain container (no clickable) → NO card', () {
      final nodes = [
        n(0, type: 'android.widget.LinearLayout'),
        n(1, depth: 1, type: 'android.widget.TextView', text: 'X'),
      ];
      final objects = const SemanticNormalizer().normalize(
        NanoSnapshot(package: 'com.t', nodes: nodes),
      );
      expect(objects[0].role, isNot(SemanticRole.card));
    });
  });

  group('list / listItem', () {
    test('RecyclerView scrollable → list, hijo clickable → listItem', () {
      final nodes = [
        n(0, type: 'android.widget.RecyclerView', scrollable: true),
        n(1, depth: 1, type: 'android.widget.LinearLayout', clickable: true),
      ];
      final objects = const SemanticNormalizer().normalize(
        NanoSnapshot(package: 'com.t', nodes: nodes),
      );
      expect(objects[0].role, SemanticRole.list);
      expect(objects[1].role, SemanticRole.listItem);
    });
  });
}
