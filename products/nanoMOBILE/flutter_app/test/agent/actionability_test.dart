import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/perception/actionability_engine.dart';
import 'package:nanoai/features/automation/engine/perception/nano_snapshot.dart';

void main() {
  NanoNode node({
    bool visible = true,
    bool enabled = true,
    bool clickable = true,
    bool editable = false,
    bool focused = false,
    NanoBounds? bounds,
  }) {
    return NanoNode(
      index: 0,
      depth: 1,
      id: '',
      type: 'android.widget.Button',
      text: 'Aceptar',
      description: '',
      clickable: clickable,
      editable: editable,
      scrollable: false,
      checked: false,
      focusable: true,
      focused: focused,
      visible: visible,
      enabled: enabled,
      bounds: bounds ?? const NanoBounds(left: 0, top: 0, right: 100, bottom: 50),
    );
  }

  group('ActionabilityState.check', () {
    test('nodo sano y único → actionable', () {
      final s = ActionabilityState.check(
        kind: ActionKind.tap,
        node: node(),
        unique: true,
        snapshotPackage: 'com.ejemplo.app',
        expectedPackage: 'com.ejemplo.app',
      );
      expect(s.actionable, isTrue);
      expect(s.failureReason, isNull);
    });

    test('invisible → no actionable con motivo', () {
      final s = ActionabilityState.check(
        kind: ActionKind.tap,
        node: node(visible: false),
        unique: true,
        snapshotPackage: 'com.ejemplo.app',
      );
      expect(s.actionable, isFalse);
      expect(s.failureReason, contains('no visible'));
    });

    test('deshabilitado → no actionable', () {
      final s = ActionabilityState.check(
        kind: ActionKind.tap,
        node: node(enabled: false),
        unique: true,
        snapshotPackage: 'com.ejemplo.app',
      );
      expect(s.actionable, isFalse);
      expect(s.failureReason, contains('deshabilitado'));
    });

    test('tap sobre nodo no clickable → no actionable', () {
      final s = ActionabilityState.check(
        kind: ActionKind.tap,
        node: node(clickable: false),
        unique: true,
        snapshotPackage: 'com.ejemplo.app',
      );
      expect(s.actionable, isFalse);
      expect(s.failureReason, contains('no clickable'));
    });

    test('input sobre nodo no editable → no actionable', () {
      final s = ActionabilityState.check(
        kind: ActionKind.input,
        node: node(editable: false),
        unique: true,
        snapshotPackage: 'com.ejemplo.app',
      );
      expect(s.actionable, isFalse);
      expect(s.failureReason, contains('no editable'));
    });

    test('input sobre editable sin foco → no actionable (hace falta tap)', () {
      final s = ActionabilityState.check(
        kind: ActionKind.input,
        node: node(editable: true, focused: false, clickable: false),
        unique: true,
        snapshotPackage: 'com.ejemplo.app',
      );
      expect(s.actionable, isFalse);
      expect(s.failureReason, contains('foco'));
    });

    test('input sobre editable con foco → recibe acción', () {
      final s = ActionabilityState.check(
        kind: ActionKind.input,
        node: node(editable: true, focused: true, clickable: false),
        unique: true,
        snapshotPackage: 'com.ejemplo.app',
      );
      expect(s.receivesAction, isTrue);
    });

    test('package inesperado → no actionable', () {
      final s = ActionabilityState.check(
        kind: ActionKind.tap,
        node: node(),
        unique: true,
        snapshotPackage: 'com.otra.app',
        expectedPackage: 'com.ejemplo.app',
      );
      expect(s.actionable, isFalse);
      expect(s.failureReason, contains('Package inesperado'));
    });

    test('ambiguo → no actionable aunque el nodo esté sano', () {
      final s = ActionabilityState.check(
        kind: ActionKind.tap,
        node: node(),
        unique: false,
        snapshotPackage: 'com.ejemplo.app',
      );
      expect(s.actionable, isFalse);
      expect(s.failureReason, contains('ambiguo'));
    });

    test('sin bounds → no existe', () {
      final s = ActionabilityState.check(
        kind: ActionKind.tap,
        node: node(
          bounds: const NanoBounds(left: 0, top: 0, right: 0, bottom: 0),
        ),
        unique: true,
        snapshotPackage: 'com.ejemplo.app',
      );
      expect(s.actionable, isFalse);
      expect(s.failureReason, contains('bounds'));
    });
  });

  group('StabilityChecker', () {
    const checker = StabilityChecker();
    const original = NanoNode(
      index: 0,
      depth: 1,
      id: 'x',
      type: 'android.widget.Button',
      text: 'Aceptar',
      description: '',
      clickable: true,
      editable: false,
      scrollable: false,
      checked: false,
      focusable: false,
      focused: false,
      visible: true,
      enabled: true,
      bounds: NanoBounds(left: 100, top: 200, right: 300, bottom: 300),
    );

    NanoNode moved({int dx = 0, int dy = 0, int dw = 0, int dh = 0}) {
      return NanoNode(
        index: 0,
        depth: 1,
        id: 'x',
        type: original.type,
        text: original.text,
        description: original.description,
        clickable: original.clickable,
        editable: original.editable,
        scrollable: original.scrollable,
        checked: original.checked,
        focusable: original.focusable,
        focused: original.focused,
        visible: original.visible,
        enabled: original.enabled,
        bounds: NanoBounds(
          left: original.bounds.left + dx,
          top: original.bounds.top + dy,
          right: original.bounds.right + dx + dw,
          bottom: original.bounds.bottom + dy + dh,
        ),
      );
    }

    test('mismo bounds → estable', () {
      expect(checker.isStable(original: original, reResolved: moved()), isTrue);
    });

    test('centro movido 15px → estable (dentro de delta 24)', () {
      expect(
        checker.isStable(original: original, reResolved: moved(dx: 15)),
        isTrue,
      );
    });

    test('centro movido 30px → inestable', () {
      expect(
        checker.isStable(original: original, reResolved: moved(dy: 30)),
        isFalse,
      );
    });

    test('tamaño +15% → inestable', () {
      expect(
        checker.isStable(original: original, reResolved: moved(dw: 30)),
        isFalse, // 30/200 = 15% > 10%
      );
    });

    test('tamaño +5% → estable', () {
      expect(
        checker.isStable(original: original, reResolved: moved(dw: 10)),
        isTrue,
      );
    });

    test('re-resolve null → inestable', () {
      expect(checker.isStable(original: original, reResolved: null), isFalse);
    });
  });
}
