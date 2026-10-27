part of 'plan_execution_coordinator.dart';

/// Plan: plan irreversible; preserva firma, orden y evidencia durable.
mixin _PlanIrreversible on _PlanExecutionState {
  Future<ToolOutcome> runIrreversibleTool(
    ToolCall call,
    ToolDefinition tool,
    ToolExecutionBudget budget, {
    String? executionId,
    ExecutionJournalEntry? executionIntent,
    bool allowPreviouslyUncertain = false,
    ExecutionCancellationToken? cancellation,
    void Function()? onPhysicalEffectDispatched,
  }) async {
    if (cancellation?.isCancelled == true) return _cancelledBeforeDispatch;
    final journal = _executionJournal;
    if (journal == null) {
      return const ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback:
            '[journalUnavailable] Acción irreversible bloqueada: no hay journal durable.',
        executionStatus: ToolExecutionStatus.notExecuted,
      );
    }

    try {
      await (_journalRecovery ??= journal.recoverInterrupted());
    } on Object catch (error) {
      return ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback:
            '[journalUnavailable] Acción irreversible bloqueada: no se pudo recuperar el journal ($error).',
        executionStatus: ToolExecutionStatus.notExecuted,
      );
    }

    final actionSignature = call.confirmationSignature;
    final now = DateTime.now().toUtc();
    ExecutionJournalEntry authorizedEntry;
    if (executionIntent != null) {
      final ExecutionJournalEntry? persisted;
      try {
        persisted = await journal.load(executionIntent.runId);
      } on Object catch (error) {
        return ToolOutcome(
          verdict: PolicyVerdict.denied,
          feedback:
              '[journalUnavailable] No se pudo validar la intención autorizada: $error.',
          executionStatus: ToolExecutionStatus.notExecuted,
        );
      }
      if (persisted == null ||
          persisted.status != ExecutionJournalStatus.authorized ||
          !persisted.irreversible ||
          persisted.planSignature != executionIntent.planSignature ||
          persisted.currentStep != executionIntent.currentStep ||
          persisted.stepId != executionIntent.stepId ||
          persisted.actionSignature != executionIntent.actionSignature) {
        return const ToolOutcome(
          verdict: PolicyVerdict.denied,
          feedback:
              '[journalUnavailable] Intención autorizada inválida o no persistida.',
          executionStatus: ToolExecutionStatus.notExecuted,
        );
      }
      authorizedEntry = persisted;
    } else {
      final runId = executionId ?? PlanExecutionCoordinator.newRunId();
      authorizedEntry = ExecutionJournalEntry(
        runId: runId,
        planSignature: actionSignature,
        goalFingerprint: canonicalFingerprint({'action': actionSignature}),
        currentStep: 0,
        stepId: 'single:0',
        status: ExecutionJournalStatus.authorized,
        irreversible: true,
        actionSignature: actionSignature,
        verificationState: 'autorizada implícitamente por política/humano',
        timestamp: now,
      );
      try {
        await journal.save(authorizedEntry);
      } on Object catch (error) {
        return ToolOutcome(
          verdict: PolicyVerdict.denied,
          feedback:
              '[journalUnavailable] No se pudo persistir la autorización irreversible: $error.',
          executionStatus: ToolExecutionStatus.notExecuted,
        );
      }
    }

    final executingEntry = authorizedEntry.copyWith(
      status: ExecutionJournalStatus.executing,
      verificationState: 'acción reclamada; aún sin resultado',
      timestamp: DateTime.now().toUtc(),
    );

    if (cancellation?.isCancelled == true) return _cancelledBeforeDispatch;
    try {
      final claimed = await journal.tryBeginIrreversible(
        executingEntry,
        allowPreviouslyUncertain: allowPreviouslyUncertain,
      );
      if (!claimed) {
        return const ToolOutcome(
          verdict: PolicyVerdict.allow,
          feedback:
              '[outcomeUnknown] Existe una ejecución no reconciliada de esta acción; no se repite automáticamente.',
          executionStatus: ToolExecutionStatus.outcomeUnknown,
        );
      }
    } on Object catch (error) {
      return ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback:
            '[journalUnavailable] Acción irreversible bloqueada antes de ejecutar: $error.',
        executionStatus: ToolExecutionStatus.notExecuted,
      );
    }
    final report = await _ownedIrreversibleReport(
      this,
      call,
      tool,
      budget,
      journal: journal,
      executingEntry: executingEntry,
      cancellation: cancellation,
      onPhysicalEffectDispatched: onPhysicalEffectDispatched,
    );
    if (report.status == ToolExecutionStatus.notExecuted) {
      return ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback: report.feedback,
        executionStatus: ToolExecutionStatus.notExecuted,
      );
    }
    final feedback = report.feedback;
    final status = report.status;
    final executedEntry = executingEntry.copyWith(
      status: ExecutionJournalStatus.executed,
      verificationState: 'efecto ejecutado; verificación pendiente',
      timestamp: DateTime.now().toUtc(),
    );
    final verifyingEntry = executedEntry.copyWith(
      status: ExecutionJournalStatus.verifying,
      verificationState: 'verificación en curso',
      timestamp: DateTime.now().toUtc(),
    );
    try {
      await journal.save(executedEntry);
      await journal.save(verifyingEntry);
    } on Object catch (error) {
      return ToolOutcome(
        verdict: PolicyVerdict.allow,
        feedback:
            '[outcomeUnknown] La acción pudo ejecutarse, pero no se pudo persistir su verificación ($error). No debe repetirse.',
        executionStatus: ToolExecutionStatus.outcomeUnknown,
      );
    }
    if (executionIntent != null) {
      return ToolOutcome(
        verdict: PolicyVerdict.allow,
        feedback: feedback,
        data: report.data,
        executionStatus: status,
      );
    }
    final terminalStatus = PlanExecutionCoordinator.journalStatusFor(
      status,
      notExecutedAs: ExecutionJournalStatus.failed,
    );
    try {
      await journal.save(
        verifyingEntry.copyWith(
          status: terminalStatus,
          verificationState: feedback,
          timestamp: DateTime.now().toUtc(),
        ),
      );
    } on Object catch (error) {
      return ToolOutcome(
        verdict: PolicyVerdict.allow,
        feedback:
            '[outcomeUnknown] La acción pudo ejecutarse, pero no se pudo cerrar el journal ($error). No debe repetirse.',
        executionStatus: ToolExecutionStatus.outcomeUnknown,
      );
    }
    return ToolOutcome(
      verdict: PolicyVerdict.allow,
      feedback: feedback,
      data: report.data,
      executionStatus: status,
    );
  }
}
