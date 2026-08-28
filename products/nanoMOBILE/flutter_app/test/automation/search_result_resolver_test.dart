import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/perception/nano_snapshot.dart';
import 'package:nanoai/features/automation/engine/perception/semantic/screen_graph.dart';
import 'package:nanoai/features/automation/engine/perception/search_result_resolver.dart';

NanoNode n(
  int index, {
  int depth = 0,
  String type = '',
  String text = '',
  String desc = '',
  String id = '',
  bool editable = false,
  bool clickable = false,
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
  focused: false,
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
  const resolver = SearchResultResolver();

  // Campo de búsqueda arriba + 2 resultados clickeables debajo.
  ScreenGraph withResults() => graph([
    n(
      0,
      type: 'android.widget.EditText',
      editable: true,
      l: 0,
      t: 0,
      r: 200,
      b: 80,
    ),
    n(
      1,
      type: 'android.view.ViewGroup',
      clickable: true,
      text: 'Result A',
      l: 0,
      t: 100,
      r: 200,
      b: 160,
    ),
    n(
      2,
      type: 'android.view.ViewGroup',
      clickable: true,
      text: 'Result B',
      l: 0,
      t: 180,
      r: 200,
      b: 240,
    ),
  ]);

  group('SearchResultResolver.resolveResults', () {
    test('ordena top→bottom y asigna ordinal 1-based', () {
      final results = resolver.resolveResults(withResults());
      expect(results.map((r) => r.ordinal).toList(), [1, 2]);
      expect(results.map((r) => r.title).toList(), ['Result A', 'Result B']);
    });

    test('selector grounded = text del nodo observado', () {
      final results = resolver.resolveResults(withResults());
      expect(results.first.selector, 'text=Result A');
    });

    test('excluye el campo de búsqueda (editable) de los resultados', () {
      final results = resolver.resolveResults(withResults());
      expect(results.any((r) => r.title.contains('EditText')), isFalse);
    });

    test('sin resultados → lista vacía', () {
      final results = resolver.resolveResults(
        graph([n(0, type: 'android.widget.EditText', editable: true)]),
      );
      expect(results, isEmpty);
    });
  });

  test('snapshot truncado devuelve evidencia incompleta, no notFound', () {
    final resolution = resolver.resolve(
      truncatedGraph([n(0, type: 'android.widget.EditText', editable: true)]),
      const ResultOrdinal(1),
    );
    expect(resolution, isA<ResultIncompleteEvidence>());
  });

  group('SearchResultResolver.resolve', () {
    test('ordinal 2 → ResultResolved con título B', () {
      final r = resolver.resolve(withResults(), const ResultOrdinal(2));
      expect(r, isA<ResultResolved>());
      expect((r as ResultResolved).candidate.title, 'Result B');
    });

    test('ordinal inexistente → ResultNotFound', () {
      expect(
        resolver.resolve(withResults(), const ResultOrdinal(5)),
        isA<ResultNotFound>(),
      );
    });

    test('texto exacto → ResultResolved', () {
      final r = resolver.resolve(withResults(), const ResultText('Result A'));
      expect((r as ResultResolved).candidate.ordinal, 1);
    });

    test('texto ambiguo (2 coincidencias) → ResultAmbiguous', () {
      final r = resolver.resolve(withResults(), const ResultText('Result'));
      expect(r, isA<ResultAmbiguous>());
      expect((r as ResultAmbiguous).candidates.length, 2);
    });

    test('texto sin coincidencia → ResultNotFound', () {
      expect(
        resolver.resolve(withResults(), const ResultText('Nope')),
        isA<ResultNotFound>(),
      );
    });
  });
}
