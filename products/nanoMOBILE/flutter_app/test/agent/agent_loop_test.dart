import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/agent/action_verifier.dart';
import 'package:nanoai/core/agent/agent_executor.dart';
import 'package:nanoai/core/agent/agent_loop.dart';
import 'package:nanoai/core/agent/agent_result.dart';
import 'package:nanoai/core/agent/nano_selector.dart';
import 'package:nanoai/core/agent/nano_snapshot.dart';

/// Ejecutor fake: devuelve resultados en secuencia (c├¡clico para reintentos).
class _FakeExecutor implements AgentExecutor {
  final List<AgentExecutionResult> tapResults;
  final List<AgentExecutionResult> setTextResults;
  int tapCalls = 0;
  int setTextCalls = 0;

  _FakeExecutor({this.tapResults = const [], this.setTextResults = const []});

  @override
  Future<NanoSnapshot?> snapshot() async => null;

  @override
  Future<AgentExecutionResult> tap(NanoSelector selector) async {
    return tapResults[tapCalls++ % tapResults.length];
  }

  @override
  Future<AgentExecutionResult> setText(NanoSelector selector, String text) async {
    return setTextResults[setTextCalls++ % setTextResults.length];
  }
}

/// Verificador fake: devuelve outcomes en secuencia.
class _FakeVerifier implements AgentVerifier {
  final List<VerificationOutcome> outcomes;
  int calls = 0;

  _FakeVerifier(this.outcomes);

  @override
  Future<VerificationOutcome> verify(
    ActionExpectation expectation, {
    NanoSnapshot? preSnapshot,
  }) async {
    return outcomes[calls++ % outcomes.length];
  }
}

AgentStep _tapStep(String id, {int maxAttempts = 3}) => AgentStep(
      id: id,
      selector: NanoSelector.parse('text=$id'),
      action: AgentAction.tap,
      expectation: const ActionExpectation(),
      maxAttempts: maxAttempts,
    );

void main() {
  test('un paso tap+verificado completa el plan', () async {
    final executor = _FakeExecutor(
      tapResults: const [AgentExecutionResult.ok()],
    );
    final verifier = _FakeVerifier([
      const VerificationOutcome(status: VerificationStatus.verified, reason: 'ok'),
    ]);
    final loop = AgentLoop(executor: executor, verifier: verifier);

    final result = await loop.run([_tapStep('Bluetooth')]);

    expect(result.completed, isTrue);
    expect(result.steps, hasLength(1));
    expect(result.steps.single.succeeded, isTrue);
    expect(result.steps.single.attempts, 1);
  });

  test('fallo estructural (notFound) aborta sin reintentar', () async {
    final executor = _FakeExecutor(
      tapResults: const [
        AgentExecutionResult.failure(
          errorCode: AgentErrorCode.notFound,
          reason: 'no existe',
        ),
      ],
    );
    final verifier = _FakeVerifier([]);
    final loop = AgentLoop(executor: executor, verifier: verifier);

    final result = await loop.run([_tapStep('X', maxAttempts: 3)]);

    expect(result.completed, isFalse);
    expect(result.failedStep, isNotNull);
    expect(result.failedStep!.attempts, 1, reason: 'notFound no se reintenta');
    expect(result.steps.single.execution.errorCode, AgentErrorCode.notFound);
  });

  test('fallo transitorio (gestureFailed) reintenta hasta ├®xito', () async {
    final executor = _FakeExecutor(
      tapResults: const [
        AgentExecutionResult.failure(
          errorCode: AgentErrorCode.gestureFailed,
          reason: 'rebind',
        ),
        AgentExecutionResult.ok(),
      ],
    );
    final verifier = _FakeVerifier([
      const VerificationOutcome(status: VerificationStatus.verified, reason: 'ok'),
    ]);
    final loop = AgentLoop(executor: executor, verifier: verifier);

    final result = await loop.run([_tapStep('Bluetooth')]);

    expect(result.completed, isTrue);
    expect(result.steps.single.attempts, 2, reason: 'reintent├│ 1 vez');
    expect(executor.tapCalls, 2);
  });

  test('postcondici├│n no cumplida reintenta y agota intentos', () async {
    final executor = _FakeExecutor(
      tapResults: const [
        AgentExecutionResult.ok(),
        AgentExecutionResult.ok(),
        AgentExecutionResult.ok(),
      ],
    );
    final verifier = _FakeVerifier([
      const VerificationOutcome(
        status: VerificationStatus.notVerified,
        reason: 'a├║n no aparece',
      ),
      const VerificationOutcome(
        status: VerificationStatus.notVerified,
        reason: 'a├║n no aparece',
      ),
      const VerificationOutcome(
        status: VerificationStatus.notVerified,
        reason: 'sigue sin aparecer',
      ),
    ]);
    final loop = AgentLoop(executor: executor, verifier: verifier);

    final result = await loop.run([_tapStep('Bluetooth', maxAttempts: 3)]);

    expect(result.completed, isFalse);
    expect(result.failedStep!.attempts, 3);
    expect(executor.tapCalls, 3);
    expect(result.failedStep!.verification, isNotNull);
  });

  test('multi-paso: el segundo falla y aborta el plan', () async {
    final executor = _FakeExecutor(
      tapResults: const [
        AgentExecutionResult.ok(),
        AgentExecutionResult.failure(
          errorCode: AgentErrorCode.serviceOff,
          reason: 'canal muerto',
        ),
      ],
    );
    final verifier = _FakeVerifier([
      const VerificationOutcome(status: VerificationStatus.verified, reason: 'ok'),
    ]);
    final loop = AgentLoop(executor: executor, verifier: verifier);

    final result = await loop.run([
      _tapStep('Ajustes'),
      _tapStep('Bluetooth'),
    ]);

    expect(result.completed, isFalse);
    expect(result.steps, hasLength(2));
    expect(result.failedStep!.step.id, 'Bluetooth');
    expect(result.steps.first.succeeded, isTrue);
  });
}
