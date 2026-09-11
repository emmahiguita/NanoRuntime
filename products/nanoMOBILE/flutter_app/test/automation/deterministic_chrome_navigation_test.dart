import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/planning/deterministic_catalog.dart';

void main() {
  const catalog = defaultDeterministicCatalog;

  group('DeterministicFlowCatalog — Navegación y Pestañas de Chrome', () {
    test('resuelve "nueva pestaña" a open_url en Chrome', () {
      final flow = catalog.forGoal('nueva pestaña');
      expect(flow, isNotNull);
      expect(flow!.steps.first.tool, 'open_url');
      expect(flow.steps.first.args?['packageName'], 'com.android.chrome');
      expect(flow.expectation?.expectedPackage, 'com.android.chrome');
    });

    test('resuelve "abrir pestaña" a open_url en Chrome', () {
      final flow = catalog.forGoal('abrir pestaña');
      expect(flow, isNotNull);
      expect(flow!.steps.first.tool, 'open_url');
    });

    test('resuelve "cerrar pestaña" a tap en close_button', () {
      final flow = catalog.forGoal('cerrar pestaña');
      expect(flow, isNotNull);
      expect(flow!.steps.first.tool, 'tap');
      expect(flow.steps.first.selector, 'com.android.chrome:id/close_button');
    });

    test('resuelve "cierra la pestaña" a tap en close_button', () {
      final flow = catalog.forGoal('cierra la pestaña');
      expect(flow, isNotNull);
      expect(flow!.steps.first.tool, 'tap');
    });

    test('resuelve "recargar página" a swipe pull-to-refresh', () {
      final flow = catalog.forGoal('recargar página');
      expect(flow, isNotNull);
      expect(flow!.steps.first.tool, 'swipe');
    });

    test('resuelve "recarga la página" a swipe pull-to-refresh', () {
      final flow = catalog.forGoal('recarga la página');
      expect(flow, isNotNull);
      expect(flow!.steps.first.tool, 'swipe');
    });

    test('resuelve "actualizar página" a swipe pull-to-refresh', () {
      final flow = catalog.forGoal('actualizar página');
      expect(flow, isNotNull);
      expect(flow!.steps.first.tool, 'swipe');
    });

    test('resuelve "lee la página" a read_screen', () {
      final flow = catalog.forGoal('lee la página');
      expect(flow, isNotNull);
      expect(flow!.steps.first.tool, 'read_screen');
    });

    test('resuelve "resume la web" a read_screen', () {
      final flow = catalog.forGoal('resume la web');
      expect(flow, isNotNull);
      expect(flow!.steps.first.tool, 'read_screen');
    });

    test('resuelve "lee el artículo" a read_screen', () {
      final flow = catalog.forGoal('lee el artículo');
      expect(flow, isNotNull);
      expect(flow!.steps.first.tool, 'read_screen');
    });
  });
}
