part of 'plan_execution_coordinator.dart';

/// Plan: plan confirmation; preserva firma, orden y evidencia durable.
extension _PlanConfirmation on _PlanExecutionState {
  Future<({bool valid, ExecutionJournalEntry? entry})> _consumePlanConfirmation(
    ActionConfirmation? confirmation,
    List<ToolCall> plan,
    String runId,
    String signature,
  ) async {
    final journal = _executionJournal;
    ExecutionJournalEntry? authorizedEntry;
    var validConfirmation = false;
    if (confirmation != null &&
        confirmation.stepIndex >= 0 &&
        confirmation.stepIndex < plan.length) {
      if (journal != null) {
        try {
          authorizedEntry = await journal.consumeConfirmation(confirmation);
          validConfirmation = authorizedEntry != null;
        } on Object {
          validConfirmation = false;
        }
      } else {
        validConfirmation = confirmation.consumeIfAuthorizes(
          executionId: runId,
          planSignature: signature,
          stepIndex: confirmation.stepIndex,
          stepId: 'tool:${confirmation.stepIndex}',
          actionSignature: plan[confirmation.stepIndex].confirmationSignature,
        );
      }
    }
    return (valid: validConfirmation, entry: authorizedEntry);
  }

  Future<PlanOutcome> _pausePlan(
    ToolOutcome outcome,
    ToolCall call,
    String runId,
    String signature,
    int i,
    List<ToolOutcome> outcomes,
    List<String> feedbacks,
    List<ExecutionPath> paths,
  ) async {
    final journal = _executionJournal;

    final request = ActionConfirmation(
      executionId: runId,
      planSignature: signature,
      stepIndex: i,
      stepId: 'tool:$i',
      actionSignature: call.confirmationSignature,
    );
    final pendingTool = _policy.registry.lookup(call.tool);
    if (journal != null && pendingTool != null) {
      try {
        final planned = ExecutionJournalEntry(
          runId: runId,
          planSignature: signature,
          goalFingerprint: canonicalFingerprint({'plan': signature}),
          currentStep: i,
          stepId: 'tool:$i',
          status: ExecutionJournalStatus.planned,
          irreversible: pendingTool.irreversible,
          actionSignature: call.confirmationSignature,
          verificationState: 'acción planificada; aún no autorizada',
          timestamp: DateTime.now().toUtc(),
        );
        await journal.save(planned);
        await journal.save(
          planned.copyWith(
            status: ExecutionJournalStatus.waitingConfirmation,
            verificationState: 'acción pendiente de confirmación explícita',
            timestamp: DateTime.now().toUtc(),
            pendingConfirmation: request,
          ),
        );
      } on Object catch (error) {
        final denied = ToolOutcome(
          verdict: PolicyVerdict.denied,
          feedback:
              '[journalUnavailable] No se pudo persistir la confirmación: $error.',
        );
        outcomes[outcomes.length - 1] = denied;
        return PlanOutcome(
          completed: false,
          steps: outcomes,
          summary: [...feedbacks, denied.feedback].join('\n'),
          paths: paths,
        );
      }
    }
    return PlanOutcome(
      completed: false,
      steps: outcomes,
      pauseIndex: i,
      pauseCall: call,
      confirmation: request,
      summary: [...feedbacks, outcome.feedback].join('\n'),
      paths: paths,
    );
  }
}
