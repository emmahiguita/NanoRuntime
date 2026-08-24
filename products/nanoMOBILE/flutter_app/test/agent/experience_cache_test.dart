import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/execution/agent_tool_dispatcher.dart';
import 'package:nanoai/features/automation/engine/memory/experience_cache.dart';

/// Tests del ExperienceCache (C7): memoria de ejecuciones VERIFICADAS —
/// hit con confianza, degradación por fallo, invalidez por debajo del umbral.
void main() {
  const bluetoothPlan = [
    ToolCall(tool: 'tap', selector: 'text=Bluetooth'),
    ToolCall(tool: 'back'),
  ];

  group('ExperienceCache', () {
    test('miss inicial → null (hay que planear)', () {
      final cache = ExperienceCache();
      expect(cache.planFor('abre bluetooth y vuelve'), isNull);
      expect(cache.size, 0);
    });

    test('tras éxito verificado → hit con el plan', () {
      final cache = ExperienceCache();
      cache.recordSuccess('abre bluetooth y vuelve', bluetoothPlan);
      final flow = cache.planFor('ABRE BLUETOOTH Y VUELVE'); // case-insensitive
      expect(flow, isNotNull);
      expect(flow!.steps, hasLength(2));
      expect(flow.successCount, 1);
      expect(flow.confidence, 1.0);
      expect(cache.size, 1);
    });

    test('fallos degradan la confianza; bajo umbral → invalidado (miss)', () {
      final cache = ExperienceCache(minConfidence: 0.5);
      cache.recordSuccess('abre bluetooth y vuelve', bluetoothPlan);
      cache.recordFailure('abre bluetooth y vuelve');
      cache.recordFailure('abre bluetooth y vuelve');
      // 1 éxito / 3 total = 0.33 < 0.5 → ya no es un hit de confianza.
      expect(cache.planFor('abre bluetooth y vuelve'), isNull);
      expect(cache.size, 1); // retenido para aprendizaje, pero no se usa
    });

    test('éxitos acumulan confianza (más ejecuciones verificadas)', () {
      final cache = ExperienceCache();
      for (var i = 0; i < 4; i++) {
        cache.recordSuccess('abre bluetooth y vuelve', bluetoothPlan);
      }
      final flow = cache.planFor('abre bluetooth y vuelve')!;
      expect(flow.successCount, 4);
      expect(flow.confidence, 1.0);
    });

    test('plan distinto en el mismo objetivo → actualiza pasos (el mundo '
        'cambió), acumula éxito', () {
      final cache = ExperienceCache();
      cache.recordSuccess('abre bluetooth y vuelve', bluetoothPlan);
      const nuevo = [ToolCall(tool: 'tap', selector: 'text=Bluetooth')];
      cache.recordSuccess('abre bluetooth y vuelve', nuevo);
      final flow = cache.planFor('abre bluetooth y vuelve')!;
      expect(flow.successCount, 2);
      expect(flow.steps, hasLength(1)); // pasos del último verificado
    });

    test('fallo sin flow previo → no rompe (nada que degradar)', () {
      final cache = ExperienceCache();
      cache.recordFailure('objetivo nunca visto');
      expect(cache.size, 0);
      expect(cache.planFor('objetivo nunca visto'), isNull);
    });

    test('límite LRU: evicta el objetivo menos reciente', () {
      final cache = ExperienceCache(maxGoals: 2);
      cache.recordSuccess('goal a', const [ToolCall(tool: 'screen')]);
      cache.recordSuccess('goal b', const [ToolCall(tool: 'screen')]);
      cache.recordSuccess('goal c', const [ToolCall(tool: 'screen')]);
      expect(cache.size, 2);
      expect(cache.planFor('goal a'), isNull); // evictado (LRU)
      expect(cache.planFor('goal c'), isNotNull);
    });
  });
}
