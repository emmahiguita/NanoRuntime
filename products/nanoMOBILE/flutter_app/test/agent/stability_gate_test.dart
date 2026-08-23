import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/perception/nano_snapshot.dart';
import 'package:nanoai/features/automation/engine/execution/stability_gate.dart';

import 'fixtures.dart';

/// Tests del StabilityGate (C4): el árbol se asienta cuando N lecturas
/// consecutivas son equivalentes; un árbol en movimiento NUNCA declara
/// estable; plazo bounded.
void main() {
  group('StabilityGate', () {
    test('árbol estable (2 lecturas iguales) → settled', () async {
      final snap = NanoSnapshot.fromRaw(snapshotAjustes());
      var reads = 0;
      final gate = StabilityGate(
        snapshotFn: () async {
          reads++;
          return snap;
        },
        requiredStableReadings: 2,
        maxWait: const Duration(milliseconds: 2000),
        pollInterval: const Duration(milliseconds: 10),
      );
      final r = await gate.waitSettled();
      expect(r.settled, isTrue);
      // Lectura 1 = baseline; lecturas 2 y 3 = dos equivalentes consecutivas.
      expect(reads, 3);
    });

    test('árbol en movimiento continuo → no settled al vencer plazo', () async {
      // Cada lectura devuelve un snapshot distinto (el mundo no se asienta).
      var i = 0;
      final gate = StabilityGate(
        snapshotFn: () async {
          final raw = snapshotAjustes();
          ((raw['nodes'] as List)[0] as Map)['text'] = 'Movimiento ${i++}';
          return NanoSnapshot.fromRaw(raw);
        },
        requiredStableReadings: 2,
        maxWait: const Duration(milliseconds: 60),
        pollInterval: const Duration(milliseconds: 5),
      );
      final r = await gate.waitSettled();
      expect(r.settled, isFalse);
      expect(r.reason, contains('no se asentó'));
    });

    test('se asienta después de moverse (rebind transitorio)', () async {
      var i = 0;
      final gate = StabilityGate(
        snapshotFn: () async {
          final raw = snapshotAjustes();
          // Primera lectura: rebind vacío; después: árbol estable.
          if (i == 0) {
            i++;
            return NanoSnapshot.fromRaw({'package': '', 'nodes': <dynamic>[]});
          }
          return NanoSnapshot.fromRaw(raw);
        },
        requiredStableReadings: 2,
        maxWait: const Duration(milliseconds: 2000),
        pollInterval: const Duration(milliseconds: 5),
      );
      final r = await gate.waitSettled();
      expect(r.settled, isTrue);
    });

    test('canal muerto (null) → no settled, motivo tipado', () async {
      final gate = StabilityGate(
        snapshotFn: () async => null,
        maxWait: const Duration(milliseconds: 2000),
        pollInterval: const Duration(milliseconds: 5),
      );
      final r = await gate.waitSettled();
      expect(r.settled, isFalse);
      expect(r.reason, contains('Canal'));
    });

    test('equivalent: texto/bounds distintos → no equivalentes', () {
      final a = NanoSnapshot.fromRaw(snapshotAjustes());
      final moved = snapshotAjustes();
      ((moved['nodes'] as List)[0] as Map)['bounds'] = [0, 0, 10, 10];
      final b = NanoSnapshot.fromRaw(moved);
      expect(StabilityGate.equivalent(a, a), isTrue);
      expect(StabilityGate.equivalent(a, b), isFalse);
    });
  });
}
