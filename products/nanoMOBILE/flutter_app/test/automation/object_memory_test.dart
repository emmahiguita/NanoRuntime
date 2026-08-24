import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/memory/object_memory.dart';

/// C10 — NanoObjectMemory: memoria + identidad verificable de objetos UI.
/// La resolución NUNCA inventa: solo devuelve evidencia con confianza
/// suficiente; sin ella → null (el llamador falla honesto, no "parecido=éxito").
void main() {
  const key = UiObjectKey(
    concept: 'bluetooth',
    package: 'com.android.settings',
  );

  test('resolve → null si no hay evidencia fiable (no inventa)', () {
    const mem = NanoObjectMemory();
    expect(mem.resolve(key), isNull);
  });

  test('recordSuccess sube confianza y resolve devuelve el selector', () {
    const mem = NanoObjectMemory();
    final next = mem.recordSuccess(
      key,
      const UiSelectorEvidence(resourceId: 'id_bt', text: 'Bluetooth'),
    );
    expect(next.confidence(key), 1.0);
    final r = next.resolve(key);
    expect(r, isNotNull);
    expect(r!.resourceId, 'id_bt'); // resourceId es el más robusto
  });

  test('resolve prefiere resourceId sobre text', () {
    var mem = const NanoObjectMemory()
        .recordSuccess(key, const UiSelectorEvidence(text: 'Bluetooth'))
        .recordSuccess(key, const UiSelectorEvidence(resourceId: 'id_bt'));
    mem = mem.recordSuccess(key, const UiSelectorEvidence(text: 'Bluetooth'));
    expect(mem.resolve(key)!.resourceId, 'id_bt');
  });

  test('recordFailure baja confianza; bajo el umbral → resolve null', () {
    var mem = const NanoObjectMemory().recordSuccess(
      key,
      const UiSelectorEvidence(resourceId: 'id_bt'),
    );
    // 80% aciertos / 20% fallos → confianza 0.8 (sigue válido).
    mem = mem
        .recordFailure(key)
        .recordFailure(key)
        .recordFailure(key)
        .recordFailure(key); // 1 ok / 4 fallos = 0.2 < 0.3 → inválido
    expect(mem.resolve(key), isNull);
  });

  test('invalidate olvida los selectores', () {
    final mem = const NanoObjectMemory().recordSuccess(
      key,
      const UiSelectorEvidence(resourceId: 'id_bt'),
    );
    expect(mem.resolve(key), isNotNull);
    expect(mem.invalidate(key).resolve(key), isNull);
  });
}
