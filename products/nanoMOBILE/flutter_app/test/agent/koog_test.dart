import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/action_verifier.dart';
import 'package:nanoai/features/automation/engine/agent_executor.dart';
import 'package:nanoai/features/automation/engine/agent_loop.dart';
import 'package:nanoai/features/automation/engine/agent_result.dart';
import 'package:nanoai/features/automation/engine/koog.dart';
import 'package:nanoai/features/automation/engine/nano_selector.dart';
import 'package:nanoai/features/automation/engine/nano_snapshot.dart';
import 'package:nanoai/features/automation/engine/tool_registry.dart';

class _FakeGenerator implements PlanGenerator {
  final List<KoogStep> steps;
  _FakeGenerator(this.steps);

  @override
  Future<List<KoogStep>> plan(String goal) async => steps;
}

class _FakeExecutor implements AgentExecutor {
  @override
  Future<NanoSnapshot?> snapshot() async => null;

  @override
  Future<ResolveOutcome> resolve(NanoSelector selector) async {
    throw UnimplementedError('Fake de Koog no resuelve selectores.');
  }

  @override
  Future<AgentExecutionResult> tap(NanoSelector selector) async =>
      const AgentExecutionResult.ok();

  @override
  Future<AgentExecutionResult> setText(NanoSelector selector, String text) async =>
      const AgentExecutionResult.ok();
}

class _FakeVerifier implements AgentVerifier {
  @override
  Future<VerificationOutcome> verify(
    ActionExpectation expectation, {
    NanoSnapshot? preSnapshot,
  }) async =>
      const VerificationOutcome(status: VerificationStatus.verified, reason: 'ok');
}

AgentLoop _loop() => AgentLoop(executor: _FakeExecutor(), verifier: _FakeVerifier());

/// Pol├¡tica permisiva para el camino feliz: tap/write como lectura (sin
/// confirmaci├│n). El PolicyEngine por defecto pide confirmaci├│n para
/// acciones de device/externalWrite ÔÇö la gobernanza se prueba aparte.
PolicyEngine _permissivePolicy() => PolicyEngine(
      registry: ToolRegistry({
        'tap': const ToolDefinition(name: 'tap', risk: ToolRisk.read),
        'write': const ToolDefinition(name: 'write', risk: ToolRisk.read),
      }),
    );

void main() {
  test('goal simple (tap) se planifica y ejecuta completo', () async {
    final koog = Koog(
      generator: _FakeGenerator([
        const KoogStep(tool: 'tap', selector: 'text=Bluetooth'),
      ]),
      loop: _loop(),
      policy: _permissivePolicy(),
    );

    final result = await koog.run('Activa Bluetooth');

    expect(result.completed, isTrue);
    expect(result.loopResult, isNotNull);
    expect(result.loopResult!.steps, hasLength(1));
  });

  test('multi-paso tap se ejecuta completo', () async {
    final koog = Koog(
      generator: _FakeGenerator([
        const KoogStep(tool: 'tap', selector: 'text=A'),
        const KoogStep(tool: 'tap', selector: 'text=B'),
      ]),
      loop: _loop(),
      policy: _permissivePolicy(),
    );

    final result = await koog.run('Abre A y luego B');

    expect(result.completed, isTrue);
    expect(result.loopResult!.steps, hasLength(2));
  });

  test('write aut├│nomo (pol├¡tica por defecto) ÔåÆ requiere confirmaci├│n y '
      'aborta', () async {
    final koog = Koog(
      generator: _FakeGenerator([
        const KoogStep(tool: 'write', selector: 'id=field', text: 'hola'),
      ]),
      loop: _loop(),
    );

    final result = await koog.run('Escribe hola en el campo');

    expect(result.completed, isFalse);
    expect(result.deniedTool, 'write');
    expect(result.loopResult, isNull, reason: 'no se ejecuta nada sin confirmar');
  });

  test('tool desconocido ÔåÆ la pol├¡tica deniega', () async {
    final koog = Koog(
      generator: _FakeGenerator([
        const KoogStep(tool: 'volar', selector: 'text=X'),
      ]),
      loop: _loop(),
    );

    final result = await koog.run('Vuela');

    expect(result.completed, isFalse);
    expect(result.deniedTool, 'volar');
  });

  test('plan vac├¡o ejecuta sin pasos y completa (no-op)', () async {
    final koog = Koog(
      generator: _FakeGenerator(const []),
      loop: _loop(),
      policy: _permissivePolicy(),
    );

    final result = await koog.run('nada que hacer');

    expect(result.completed, isTrue);
    expect(result.loopResult!.steps, isEmpty);
  });
}
