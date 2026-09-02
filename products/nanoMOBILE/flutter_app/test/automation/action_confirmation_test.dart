import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/governance/action_confirmation.dart';

void main() {
  test('fingerprint canónica no depende del orden de las claves', () {
    expect(
      canonicalFingerprint({'b': 2, 'a': 1}),
      canonicalFingerprint({'a': 1, 'b': 2}),
    );
    expect(
      canonicalFingerprint({'a': 1}),
      isNot(canonicalFingerprint({'a': 2})),
    );
  });

  test('solo autoriza la ejecución, plan, paso y acción exactos', () {
    final token = ActionConfirmation(
      executionId: 'run-1',
      planSignature: 'plan-1',
      stepIndex: 2,
      stepId: 'send',
      actionSignature: 'tap-send',
    );

    expect(
      token.consumeIfAuthorizes(
        executionId: 'run-2',
        planSignature: 'plan-1',
        stepIndex: 2,
        stepId: 'send',
        actionSignature: 'tap-send',
      ),
      isFalse,
    );
    expect(
      token.consumeIfAuthorizes(
        executionId: 'run-1',
        planSignature: 'plan-changed',
        stepIndex: 2,
        stepId: 'send',
        actionSignature: 'tap-send',
      ),
      isFalse,
    );
    expect(
      token.consumeIfAuthorizes(
        executionId: 'run-1',
        planSignature: 'plan-1',
        stepIndex: 3,
        stepId: 'send',
        actionSignature: 'tap-send',
      ),
      isFalse,
    );
    expect(
      token.consumeIfAuthorizes(
        executionId: 'run-1',
        planSignature: 'plan-1',
        stepIndex: 2,
        stepId: 'send',
        actionSignature: 'tap-other',
      ),
      isFalse,
    );
    expect(token.consumed, isFalse);

    expect(
      token.consumeIfAuthorizes(
        executionId: 'run-1',
        planSignature: 'plan-1',
        stepIndex: 2,
        stepId: 'send',
        actionSignature: 'tap-send',
      ),
      isTrue,
    );
    expect(token.consumed, isTrue);
  });

  test('token consumido no puede reproducirse', () {
    final token = ActionConfirmation(
      executionId: 'run',
      planSignature: 'plan',
      stepIndex: 0,
      stepId: 'reply',
      actionSignature: 'reply-action',
    );

    bool consume() => token.consumeIfAuthorizes(
      executionId: 'run',
      planSignature: 'plan',
      stepIndex: 0,
      stepId: 'reply',
      actionSignature: 'reply-action',
    );

    expect(consume(), isTrue);
    expect(consume(), isFalse);
  });

  test('token expirado no autoriza y conserva estado no consumido', () {
    final created = DateTime.utc(2026, 1, 1, 12);
    final token = ActionConfirmation(
      executionId: 'run',
      planSignature: 'plan',
      stepIndex: 0,
      stepId: 'reply',
      actionSignature: 'reply-action',
      createdAt: created,
      expiresAt: created.add(const Duration(seconds: 30)),
    );

    final accepted = token.consumeIfAuthorizes(
      executionId: 'run',
      planSignature: 'plan',
      stepIndex: 0,
      stepId: 'reply',
      actionSignature: 'reply-action',
      now: created.add(const Duration(seconds: 31)),
    );

    expect(accepted, isFalse);
    expect(token.consumed, isFalse);
  });

  test('journal round-trip preserva identidad, caducidad y consumo', () {
    final token = ActionConfirmation(
      executionId: 'run',
      confirmationId: 'nonce',
      planSignature: 'plan',
      stepIndex: 1,
      stepId: 'send',
      actionSignature: 'action',
      createdAt: DateTime.utc(2026, 1, 1),
      expiresAt: DateTime.utc(2026, 1, 1, 0, 5),
      consumed: true,
    );

    final restored = ActionConfirmation.fromJson(token.toJson());

    expect(restored.confirmationId, 'nonce');
    expect(restored.executionId, 'run');
    expect(restored.expiresAt, DateTime.utc(2026, 1, 1, 0, 5));
    expect(restored.consumed, isTrue);
  });
}
