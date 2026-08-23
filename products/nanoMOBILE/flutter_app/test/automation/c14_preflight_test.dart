import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/benchmark/c14_context.dart';
import 'package:nanoai/features/automation/benchmark/c14_preflight.dart';

void main() {
  group('C14Preflight', () {
    test('todo OK → pass, sin failCode', () async {
      final r = await const C14Preflight().run(
        runtimeAlive: true,
        modelLoaded: true,
        accessibilityEnabled: true,
        coordinatorReady: true,
        policyConfigured: true,
        deviceUnlocked: true,
        screenInteractive: true,
      );
      expect(r.pass, isTrue);
      expect(r.failCode, isNull);
      expect(r.checks, hasLength(7));
    });

    test('falta modelo → aborta con MODEL_NOT_LOADED', () async {
      final r = await const C14Preflight().run(
        runtimeAlive: true,
        modelLoaded: false,
        accessibilityEnabled: true,
        coordinatorReady: true,
        policyConfigured: true,
        deviceUnlocked: true,
        screenInteractive: true,
      );
      expect(r.pass, isFalse);
      expect(r.failCode, PreflightCode.modelNotLoaded);
    });

    test('aborta en la PRIMERA dependencia que falta (accesibilidad)',
        () async {
      final r = await const C14Preflight().run(
        runtimeAlive: true,
        modelLoaded: true,
        accessibilityEnabled: false,
        coordinatorReady: true,
        policyConfigured: true,
        deviceUnlocked: false, // no importa, accesibilidad va primero
        screenInteractive: true,
      );
      expect(r.failCode, PreflightCode.accessibilityOff);
    });

    test('runtime muerto → RUNTIME_DEAD', () async {
      final r = await const C14Preflight().run(
        runtimeAlive: false,
        modelLoaded: false,
        accessibilityEnabled: false,
        coordinatorReady: false,
        policyConfigured: false,
        deviceUnlocked: false,
        screenInteractive: false,
      );
      expect(r.failCode, PreflightCode.runtimeDead);
    });
  });

  group('BenchmarkContext', () {
    test('captura gitCommit/appVersion/deviceModel de build-info', () {
      final ctx = BenchmarkContext.capture(model: 'qwen.gguf', temperature: 0.3);
      // AppBuildInfo usa dart-define con default 'unknown'/'0.0.0'.
      expect(ctx.gitCommit, isA<String>());
      expect(ctx.appVersion, isA<String>());
      expect(ctx.device, isA<String>());
      expect(ctx.model, 'qwen.gguf');
      expect(ctx.temperature, 0.3);
      final j = ctx.toJson();
      expect(j['model'], 'qwen.gguf');
      expect(j['timestamp'], isA<String>());
    });
  });
}
