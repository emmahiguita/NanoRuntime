import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/memory/object_memory.dart';

void main() {
  group('UiObjectKey V2 (contexto)', () {
    test('screenSignature + semanticTarget en equality/roundtrip', () {
      const key = UiObjectKey(
        concept: 'bluetooth',
        package: 'com.android.settings',
        screenSignature: 'sig-1',
        semanticTarget: 'switchControl',
      );
      final restored = UiObjectKey.fromJson(key.toJson());
      expect(restored, key);
      expect(restored.screenSignature, 'sig-1');
      expect(restored.semanticTarget, 'switchControl');
      expect(key.hashCode, restored.hashCode);
    });

    test('mismo concepto con distinta firma de pantalla → keys distintos', () {
      const a = UiObjectKey(concept: 'enviar', screenSignature: 'sig-a');
      const b = UiObjectKey(concept: 'enviar', screenSignature: 'sig-b');
      expect(a, isNot(b));
    });
  });

  group('NanoObjectMemory V2', () {
    test('fallos consecutivos invalidan el entry', () {
      var mem = const NanoObjectMemory();
      const key = UiObjectKey(concept: 'bluetooth');
      mem = mem.recordSuccess(
        key,
        const UiSelectorEvidence(resourceId: 'id_bt'),
      );
      expect(mem.resolve(key), isNotNull);

      mem = mem.recordFailure(key);
      expect(mem.resolve(key), isNotNull); // 1 fallo: aún válido

      mem = mem.recordFailure(key);
      expect(mem.resolve(key), isNull); // 2 fallos consecutivos: invalidado
    });

    test('éxito resetea fallos consecutivos', () {
      var mem = const NanoObjectMemory();
      const key = UiObjectKey(concept: 'bluetooth');
      mem = mem.recordSuccess(
        key,
        const UiSelectorEvidence(resourceId: 'id_bt'),
      );
      mem = mem.recordFailure(key);
      mem = mem.recordFailure(key);
      expect(mem.resolve(key), isNull);
      mem = mem.recordSuccess(
        key,
        const UiSelectorEvidence(resourceId: 'id_bt'),
      );
      expect(mem.resolve(key), isNotNull);
    });

    test('confidence decay por tiempo', () {
      final now = DateTime(2026, 1, 1);
      var mem = const NanoObjectMemory();
      const key = UiObjectKey(concept: 'bluetooth');
      mem = mem.recordSuccess(
        key,
        const UiSelectorEvidence(resourceId: 'id_bt'),
        now: now,
      );
      expect(mem.confidence(key, now: now), 1.0);
      expect(mem.confidence(key, now: now.add(const Duration(days: 10))), 0.8);
      expect(mem.confidence(key, now: now.add(const Duration(days: 40))), 0.5);
    });

    test('roundtrip conserva contadores y contexto exactos', () {
      final now = DateTime(2026, 1, 1);
      var mem = const NanoObjectMemory();
      const key = UiObjectKey(
        concept: 'bluetooth',
        package: 'com.android.settings',
        screenSignature: 'sig-1',
        semanticTarget: 'switchControl',
      );
      mem = mem.recordSuccess(
        key,
        const UiSelectorEvidence(resourceId: 'id_bt', screenSignature: 'sig-1'),
        now: now,
      );
      mem = mem.recordFailure(key, now: now);

      final restored = NanoObjectMemory.fromJson(mem.toJson());
      expect(restored.resolve(key), isNotNull);
      expect(restored.confidence(key, now: now), mem.confidence(key, now: now));
    });

    test('JSON legacy (sin contexto) sigue parseando', () {
      final legacy = [
        {
          'concept': 'bluetooth',
          'package': 'com.android.settings',
          'appVersion': '1.0',
          'resourceId': 'id_bt',
          'successes': 2,
          'failures': 0,
          'lastVerified': '2026-01-01T00:00:00.000',
        },
      ];
      final mem = NanoObjectMemory.fromJson(legacy);
      const key = UiObjectKey(
        concept: 'bluetooth',
        package: 'com.android.settings',
        appVersion: '1.0',
      );
      expect(mem.resolve(key), isNotNull);
      expect(mem.resolve(key)!.resourceId, 'id_bt');
    });
  });
}
