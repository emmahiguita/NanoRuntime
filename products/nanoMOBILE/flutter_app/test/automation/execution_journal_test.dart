import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/automation/engine/governance/action_confirmation.dart';
import 'package:nanoai/features/automation/engine/orchestration/execution_journal.dart';
import 'package:shared_preferences/shared_preferences.dart';

ExecutionJournalEntry _entry({
  required String runId,
  required ExecutionJournalStatus status,
  required bool irreversible,
  ActionConfirmation? confirmation,
}) => ExecutionJournalEntry(
  runId: runId,
  planSignature: 'plan',
  goalFingerprint: 'goal',
  currentStep: 2,
  stepId: 'send',
  status: status,
  irreversible: irreversible,
  actionSignature: 'action',
  verificationState: 'state',
  timestamp: DateTime.utc(2026, 1, 1),
  pendingConfirmation: confirmation,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'persiste y restaura confirmación pendiente en otra instancia',
    () async {
      final confirmation = ActionConfirmation(
        executionId: 'run-1',
        confirmationId: 'nonce',
        planSignature: 'plan',
        stepIndex: 2,
        stepId: 'send',
        actionSignature: 'action',
        createdAt: DateTime.utc(2026, 1, 1),
        expiresAt: DateTime.utc(2026, 1, 1, 0, 5),
      );
      final firstProcess = SharedPreferencesExecutionJournal();
      await firstProcess.save(
        _entry(
          runId: 'run-1',
          status: ExecutionJournalStatus.waitingConfirmation,
          irreversible: true,
          confirmation: confirmation,
        ),
      );

      final secondProcess = SharedPreferencesExecutionJournal();
      final restored = await secondProcess.load('run-1');

      expect(restored?.status, ExecutionJournalStatus.waitingConfirmation);
      expect(restored?.pendingConfirmation?.confirmationId, 'nonce');
      expect(restored?.actionSignature, 'action');
    },
  );

  test('recuperación degrada commit interrumpido a outcomeUnknown', () async {
    final beforeDeath = SharedPreferencesExecutionJournal();
    await beforeDeath.save(
      _entry(
        runId: 'run-dead',
        status: ExecutionJournalStatus.executing,
        irreversible: true,
      ),
    );

    final afterRelaunch = SharedPreferencesExecutionJournal();
    await afterRelaunch.recoverInterrupted();
    final restored = await afterRelaunch.load('run-dead');

    expect(restored?.status, ExecutionJournalStatus.outcomeUnknown);
    expect(restored?.verificationState, contains('requiere reconciliación'));
  });

  test(
    'una operación reversible interrumpida no se marca como commit incierto',
    () async {
      final journal = SharedPreferencesExecutionJournal();
      await journal.save(
        _entry(
          runId: 'read-run',
          status: ExecutionJournalStatus.executing,
          irreversible: false,
        ),
      );

      await journal.recoverInterrupted();

      expect(
        (await journal.load('read-run'))?.status,
        ExecutionJournalStatus.executing,
      );
    },
  );
}
