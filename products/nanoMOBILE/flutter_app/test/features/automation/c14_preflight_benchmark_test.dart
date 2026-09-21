import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/benchmark/c14_benchmark.dart';
import 'package:nanoai/features/automation/benchmark/c14_preflight.dart';

void main() {
  group('C14 Benchmark & Preflight Unit Tests', () {
    test('whatsAppSuite declara tareas reales y no requiere LLM generativo', () {
      expect(whatsAppSuite.requiresLlm, isFalse);
      expect(whatsAppSuite.tasks.length, equals(9));
      expect(whatsAppSuite.tasks.any((t) => t.goal.contains('Emm')), isTrue);
      expect(whatsAppSuite.tasks.any((t) => t.goal.contains('3203527283')), isTrue);
      expect(whatsAppSuite.tasks.any((t) => t.goal.contains('foto_nanoai.png')), isTrue);
      expect(whatsAppSuite.tasks.any((t) => t.goal.contains('Informe_Ejecutivo')), isTrue);
    });

    test('C14Preflight pasa para whatsAppSuite sin runtime LLM cargado', () async {
      const preflight = C14Preflight();
      final result = await preflight.run(
        runtimeAlive: false,
        modelLoaded: false,
        accessibilityEnabled: true,
        coordinatorReady: true,
        policyConfigured: true,
        deviceUnlocked: true,
        screenInteractive: true,
        requiresLlm: false,
      );

      expect(result.pass, isTrue);
      expect(result.failCode, isNull);
      expect(result.checks.firstWhere((c) => c.name == 'Runtime vivo').ok, isTrue);
      expect(result.checks.firstWhere((c) => c.name == 'Modelo cargado').ok, isTrue);
    });

    test('C14Preflight falla con runtimeDead para defaultSuite si runtime está muerto', () async {
      const preflight = C14Preflight();
      final result = await preflight.run(
        runtimeAlive: false,
        modelLoaded: false,
        accessibilityEnabled: true,
        coordinatorReady: true,
        policyConfigured: true,
        deviceUnlocked: true,
        screenInteractive: true,
        requiresLlm: true,
      );

      expect(result.pass, isFalse);
      expect(result.failCode, equals(PreflightCode.runtimeDead));
    });
  });
}
