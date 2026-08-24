import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/benchmark/c14_metrics.dart';
import 'package:nanoai/features/automation/domain/automation_result.dart';

C14Execution _ex({
  bool valid = false,
  bool success = false,
  int gen = 0,
  int rej = 0,
}) => C14Execution(
  goal: 'g',
  planValid: valid,
  toolsGenerated: gen,
  toolsRejected: rej,
  steps: 1,
  path: 'llm',
  llmLatency: Duration.zero,
  toolLatency: Duration.zero,
  verification: success
      ? AutomationResultStatus.completed
      : AutomationResultStatus.noPlan,
  retries: 0,
  replans: 0,
  cacheHit: false,
  goalSuccess: success,
  totalLatency: Duration.zero,
);

C14GateResult _gate(C14BenchmarkReport r, String name) =>
    r.gates.firstWhere((g) => g.name == name);

void main() {
  group('C14Gates · umbrales del plan maestro', () {
    test('>=90% planes válidos', () {
      // 10 ejecuciones, 1 inválida → 90% (límite).
      final ex = [
        for (var i = 0; i < 10; i++)
          _ex(
            valid: i != 0,
            gen: i == 0 ? 0 : 1,
            rej: i == 0 ? 1 : 0,
            success: true,
          ),
      ];
      expect(
        _gate(C14Gates().evaluate(ex), 'planes válidos (>=90%)').pass,
        isTrue,
      );

      final exBad = [
        for (var i = 0; i < 10; i++)
          _ex(
            valid: i < 2,
            gen: i < 2 ? 0 : 1,
            rej: i < 2 ? 1 : 0,
            success: true,
          ),
      ];
      expect(
        _gate(C14Gates().evaluate(exBad), 'planes válidos (>=90%)').pass,
        isFalse,
      );
    });

    test('>=80% éxito en tareas simples', () {
      final ok = [
        for (var i = 0; i < 10; i++) _ex(valid: true, gen: 1, success: i < 8),
      ];
      expect(
        _gate(C14Gates().evaluate(ok), 'éxito tareas simples (>=80%)').pass,
        isTrue,
      );

      final bad = [
        for (var i = 0; i < 10; i++) _ex(valid: true, gen: 1, success: i < 5),
      ];
      expect(
        _gate(C14Gates().evaluate(bad), 'éxito tareas simples (>=80%)').pass,
        isFalse,
      );
    });

    test('0 tools desconocidas ejecutadas', () {
      final ex = [_ex(valid: true, success: true, gen: 3, rej: 3)];
      expect(
        _gate(C14Gates().evaluate(ex), '0 tools desconocidas ejecutadas').pass,
        isFalse,
      );

      final clean = [_ex(valid: true, success: true, gen: 2, rej: 0)];
      expect(
        _gate(
          C14Gates().evaluate(clean),
          '0 tools desconocidas ejecutadas',
        ).pass,
        isTrue,
      );
    });

    test('0 false success (éxito sin plan válido)', () {
      final ex = [_ex(valid: false, success: true)];
      expect(
        _gate(
          C14Gates().evaluate(ex),
          '0 false success (éxito sin plan válido)',
        ).pass,
        isFalse,
      );
    });

    test('suite vacía no rompe y gates fallan (sin datos)', () {
      final r = C14Gates().evaluate(const []);
      expect(r.total, 0);
      expect(r.successRate, closeTo(0.0, 1e-9));
      expect(r.gatedPass, isFalse);
    });
  });
}
