part of 'plan_execution_coordinator.dart';

/// Plan: plan record; preserva firma, orden y evidencia durable.
extension _PlanRecord on _PlanExecutionState {
  Future<bool> _recordPlanStep(
    ExecutionJournalEntry entry,
    ToolDefinition tool,
    ToolOutcome outcome,
  ) async {
    final journal = _executionJournal!;
    final ExecutionJournalEntry verifying;
    if (tool.irreversible) {
      final persisted = await journal.load(entry.runId);
      if (persisted == null ||
          persisted.status != ExecutionJournalStatus.verifying) {
        return false;
      }
      verifying = persisted;
    } else {
      final executed = entry.copyWith(
        status: ExecutionJournalStatus.executed,
        verificationState: 'efecto ejecutado; verificación pendiente',
        timestamp: DateTime.now().toUtc(),
      );
      verifying = executed.copyWith(
        status: ExecutionJournalStatus.verifying,
        verificationState: 'verificación en curso',
        timestamp: DateTime.now().toUtc(),
      );
      await journal.save(executed);
      await journal.save(verifying);
    }
    await journal.save(
      verifying.copyWith(
        status: PlanExecutionCoordinator.journalStatusFor(
          outcome.executionStatus,
          notExecutedAs: ExecutionJournalStatus.cancelled,
        ),
        verificationState: outcome.feedback,
        timestamp: DateTime.now().toUtc(),
      ),
    );
    return true;
  }
}
