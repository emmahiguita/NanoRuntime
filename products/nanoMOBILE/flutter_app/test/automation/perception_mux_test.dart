import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/perception/perception_mux.dart';

/// C12 — PerceptionMux: fusiona perceptores de pantalla (conectables: accesib,
/// OCR/visión futuras). Resuelve un concepto a un selector real observado.
/// NUNCA inventa: sin candidato sobre el umbral → null.
void main() {
  test('resolve devuelve el mejor candidato de las fuentes', () async {
    final mux = PerceptionMux([
      _FakeSource(const [
        SelectorCandidate(selector: 'text=Bluetooth', score: 0.4),
        SelectorCandidate(selector: 'id=id_bt', score: 0.9),
      ]),
    ]);
    // Umbral 0.5: descarta el 0.4, usa el 0.9.
    final r = await mux.resolve('Bluetooth');
    expect(r, 'id=id_bt');
  });

  test('sin candidato sobre el umbral → null (no inventa)', () async {
    final mux = PerceptionMux([
      _FakeSource(const [SelectorCandidate(selector: 'text=X', score: 0.2)]),
    ]);
    expect(await mux.resolve('X'), isNull);
  });

  test('fuentes vacías (sin percepción) → null', () async {
    const mux = PerceptionMux([]);
    expect(await mux.resolve('Bluetooth'), isNull);
    expect(mux.isEnabled, isFalse);
  });

  test('fusiona múltiples fuentes, el de mayor score gana', () async {
    final mux = PerceptionMux([
      _FakeSource(const [SelectorCandidate(selector: 'text=Bluetooth', score: 0.6)]),
      _FakeSource(const [SelectorCandidate(selector: 'id=id_bt', score: 0.95)]),
    ]);
    expect(await mux.resolve('Bluetooth'), 'id=id_bt');
  });
}

class _FakeSource implements PerceptionSource {
  final List<SelectorCandidate> candidates;
  const _FakeSource(this.candidates);

  @override
  Future<List<SelectorCandidate>> perceive(
    String concept, {
    String? role,
    String? package,
  }) async =>
      candidates;
}
