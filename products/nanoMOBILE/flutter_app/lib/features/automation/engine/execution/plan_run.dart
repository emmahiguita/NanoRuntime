part of 'plan_execution_coordinator.dart';

/// Plan: plan run; preserva firma, orden y evidencia durable.
mixin _PlanRun on _PlanExecutionState {
  Future<PlanOutcome> runPlanGuarded(
    List<ToolCall> plan, {
    bool humanInitiated = false,
    ActionConfirmation? confirmation,
    String? executionId,
    bool confirmed = false,
    ExecutionCancellationToken? cancellation,
    void Function(int stepIndex)? onStep,
    RuleExecutionAuthority? authority,
    void Function()? onPhysicalEffectDispatched,
  }) async {
    if (PlanExecutionCoordinator.requiresGoalDirectedExecution(plan)) {
      const denied = ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback:
            '[goalDirectedRequired] Plan UI multipaso bloqueado: requiere '
            'observar, clasificar y verificar la superficie entre acciones.',
        executionStatus: ToolExecutionStatus.notExecuted,
      );
      return const PlanOutcome(
        completed: false,
        steps: [denied],
        summary:
            '[goalDirectedRequired] Plan UI multipaso bloqueado: requiere '
            'TaskOrchestrator y nueva observación entre acciones.',
      );
    }
    final outcomes = <ToolOutcome>[];
    final feedbacks = <String>[];
    final paths = <ExecutionPath>[];
    final total = plan.length;
    final loopDetector = ToolLoopDetector();
    final budget = ToolExecutionBudget();
    final signature = PlanExecutionCoordinator.planSignature(plan);
    final runId =
        executionId ??
        confirmation?.executionId ??
        PlanExecutionCoordinator.newRunId();
    final journal = _executionJournal;
    final authorization = await _consumePlanConfirmation(
      confirmation,
      plan,
      runId,
      signature,
    );
    var authorizedEntry = authorization.entry;
    final validConfirmation = authorization.valid;
    if (confirmation != null && !validConfirmation) {
      const denied = ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback:
            '[confirmationInvalid] Confirmación válida, expirada, consumida o no pendiente en el journal.',
      );
      return const PlanOutcome(
        completed: false,
        steps: [denied],
        summary:
            '[confirmationInvalid] Confirmación válida, expirada, consumida o no pendiente en el journal.',
      );
    }
    final confirmedStepIndex = validConfirmation
        ? confirmation!.stepIndex
        : null;
    final startIndex = confirmedStepIndex ?? 0;
    for (var i = startIndex; i < total; i++) {
      cancellation?.throwIfCancelled();
      onStep?.call(i);
      final call = plan[i];
      paths.add(_router.route(call).path);

      final fp = await loopFingerprint(call);
      if (loopDetector.isLoop(fp)) {
        final loopOutcome = ToolOutcome(
          verdict: PolicyVerdict.denied,
          feedback:
              '[loopDetected] Ciclo en el plan '
              '("${call.tool} ${call.selectorArg ?? ''}${call.textArg != null ? ' ${call.textArg!}' : ''}"). '
              'El mundo no avanza: se aborta en lugar de repetir la acción.',
        );
        outcomes.add(loopOutcome);
        return PlanOutcome(
          completed: false,
          steps: outcomes,
          summary: [...feedbacks, loopOutcome.feedback].join('\n'),
          paths: paths,
        );
      }

      final stepConfirmed = i == confirmedStepIndex;
      final tool = _policy.registry.lookup(call.tool);
      ExecutionJournalEntry? executionIntent;
      if (stepConfirmed && authorizedEntry != null && tool != null) {
        if (tool.irreversible) {
          executionIntent = authorizedEntry;
        } else if (journal != null) {
          final executing = authorizedEntry.copyWith(
            status: ExecutionJournalStatus.executing,
            verificationState: 'acción autorizada; ejecución en curso',
            timestamp: DateTime.now().toUtc(),
          );
          await journal.save(executing);
          authorizedEntry = executing;
        }
      }
      final outcome = await _runToolGuarded(
        call,
        humanInitiated: humanInitiated,
        confirmed: stepConfirmed,
        executionId: runId,
        budget: budget,
        cancellation: cancellation,
        executionIntent: executionIntent,
        authority: authority,
        onPhysicalEffectDispatched: onPhysicalEffectDispatched,
      );
      outcomes.add(outcome);

      if (outcome.needsConfirmation) {
        return _pausePlan(
          outcome,
          call,
          runId,
          signature,
          i,
          outcomes,
          feedbacks,
          paths,
        );
      }
      if (stepConfirmed &&
          authorizedEntry != null &&
          tool != null &&
          journal != null) {
        if (!await _recordPlanStep(authorizedEntry, tool, outcome)) {
          return PlanOutcome(
            completed: false,
            steps: outcomes,
            summary: 'El journal no conserva la verificación de la acción.',
            paths: paths,
          );
        }
      }
      feedbacks.add('${i + 1}/$total ${outcome.feedback}');
      if (outcome.verdict != PolicyVerdict.allow || outcome.executionFailed) {
        return PlanOutcome(
          completed: false,
          steps: outcomes,
          summary: feedbacks.join('\n'),
          paths: paths,
        );
      }
    }

    return PlanOutcome(
      completed: true,
      steps: outcomes,
      summary: feedbacks.join('\n'),
      paths: paths,
    );
  }
}
