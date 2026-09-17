part of 'automation_coordinator.dart';

/// Extension interna para mapeo de resultados, ledger y evidencia de AutomationCoordinator (SRP).
extension AutomationCoordinatorResults on AutomationCoordinator {
  String conceptFromSelector(String selector) {
    final s = selector.trim();
    if (s.startsWith('text~=')) return s.substring(6).trim().toLowerCase();
    if (s.startsWith('desc~=')) return s.substring(6).trim().toLowerCase();
    if (s.startsWith('text=')) return s.substring(5).trim().toLowerCase();
    if (s.startsWith('desc=')) return s.substring(5).trim().toLowerCase();
    if (s.startsWith('id=')) return s.substring(3).trim().toLowerCase();
    return s.toLowerCase();
  }

  UiSelectorEvidence? evidenceFromSelector(String selector) {
    final s = selector.trim();
    if (s.startsWith('id=')) {
      return UiSelectorEvidence(resourceId: s.substring(3).trim());
    }
    if (s.startsWith('text~=')) {
      return UiSelectorEvidence(text: s.substring(6).trim());
    }
    if (s.startsWith('text=')) {
      return UiSelectorEvidence(text: s.substring(5).trim());
    }
    if (s.startsWith('desc~=')) {
      return UiSelectorEvidence(desc: s.substring(6).trim());
    }
    if (s.startsWith('desc=')) {
      return UiSelectorEvidence(desc: s.substring(5).trim());
    }
    return null;
  }

  /// Memoriza la verificación del objetivo para anclar selectores futuros.
  /// RESOLUTION adapta; la VERIFICACIÓN ya fue estricta aguas arriba.
  void recordMemory(
    String goal,
    List<ToolCall> plan,
    AutomationResultStatus status,
  ) {
    final mem = _objectMemory;
    if (mem == null || plan.isEmpty) return;

    // completedUnverified NO es evidencia positiva ni negativa.
    final verifiedSuccess = status == AutomationResultStatus.completed;
    final verifiedFailure = status == AutomationResultStatus.failed;
    if (!verifiedSuccess && !verifiedFailure) return;

    var next = mem;
    for (final c in plan) {
      final sel = c.selector ?? '';
      final concept = conceptFromSelector(sel);
      if (concept.isEmpty) continue;
      final key = UiObjectKey(concept: concept);
      if (verifiedSuccess) {
        final evidence = evidenceFromSelector(sel);
        if (evidence == null || evidence.fingerprint.isEmpty) continue;
        next = next.recordSuccess(key, evidence);
      } else {
        next = next.recordFailure(key);
      }
    }
    _objectMemory = next;
    _onMemoryUpdate?.call(next);
  }

  /// Normaliza ACTION/PLAN success a TASK success. Ningún camino de
  /// [execute] puede devolver `completed` si el objetivo final no fue probado.
  Future<AutomationResult> finalizeExecution({
    required String executionId,
    required String goal,
    required AutomationResult base,
    GoalExpectation? expectation,
    bool outputProvesGoal = false,
  }) async {
    if (base.status != AutomationResultStatus.completed) return base;

    final verify = _verifyGoal;
    if (expectation == null && outputProvesGoal) {
      return AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.completed,
        reason: '${base.reason} Resultado nativo devuelto al usuario.',
        pauseIndex: base.pauseIndex,
        pauseTool: base.pauseTool,
      );
    }
    if (verify == null || expectation == null) {
      return AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.completedUnverified,
        reason: '${base.reason} Objetivo final sin verificación declarada.',
        pauseIndex: base.pauseIndex,
        pauseTool: base.pauseTool,
      );
    }

    final v = await verify(goal, planCompleted: true, expectation: expectation);
    return switch (v.status) {
      GoalStatus.satisfied => AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.completed,
        reason: '${base.reason} ${v.reason}',
        pauseIndex: base.pauseIndex,
        pauseTool: base.pauseTool,
      ),
      GoalStatus.unverified => AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.completedUnverified,
        reason: '${base.reason} ${v.reason}',
        pauseIndex: base.pauseIndex,
        pauseTool: base.pauseTool,
      ),
      GoalStatus.notSatisfied => AutomationResult(
        executionId: executionId,
        status: AutomationResultStatus.failed,
        reason: '${base.reason} ${v.reason}',
        pauseIndex: base.pauseIndex,
        pauseTool: base.pauseTool,
      ),
    };
  }

  // ── Resultado (mapeo a dominio) ───────────────────────────────────────────

  AutomationResult resultFromFlow(String id, FlowExecutionResult r) =>
      AutomationResult(
        executionId: id,
        status: statusFromFlow(r),
        reason: r.plan.summary,
        pauseIndex: r.plan.pauseIndex,
        pauseTool: r.plan.pauseCall?.tool,
        confirmation: r.plan.confirmation,
      );

  AutomationResult resultFromPlan(String id, PlanOutcome o) => AutomationResult(
    executionId: id,
    status: statusFromPlan(o),
    reason: o.summary,
    pauseIndex: o.pauseIndex,
    pauseTool: o.pauseCall?.tool,
    confirmation: o.confirmation,
  );

  // ── Trazas (ledger) ───────────────────────────────────────────────────────

  AutomationResultStatus statusFromFlow(FlowExecutionResult r) {
    if (r.plan.pauseIndex != null) return AutomationResultStatus.paused;
    if (r.plan.steps.any(
      (step) => step.executionStatus == ToolExecutionStatus.outcomeUnknown,
    )) {
      return AutomationResultStatus.outcomeUnknown;
    }
    if (!r.completed) return AutomationResultStatus.failed;
    return r.goal.status == GoalStatus.satisfied
        ? AutomationResultStatus.completed
        : AutomationResultStatus.completedUnverified;
  }

  AutomationResultStatus statusFromPlan(PlanOutcome o) {
    if (o.pauseIndex != null) return AutomationResultStatus.paused;
    if (o.steps.any(
      (step) => step.executionStatus == ToolExecutionStatus.outcomeUnknown,
    )) {
      return AutomationResultStatus.outcomeUnknown;
    }
    if (!o.completed) return AutomationResultStatus.failed;
    return o.hasUnverifiedSteps
        ? AutomationResultStatus.completedUnverified
        : AutomationResultStatus.completed;
  }

  AutomationResultStatus statusFromTool(ToolOutcome o) => switch (o.verdict) {
    PolicyVerdict.needsConfirmation => AutomationResultStatus.paused,
    PolicyVerdict.denied => AutomationResultStatus.denied,
    PolicyVerdict.allow => switch (o.executionStatus) {
      ToolExecutionStatus.completed => AutomationResultStatus.completed,
      ToolExecutionStatus.completedUnverified =>
        AutomationResultStatus.completedUnverified,
      ToolExecutionStatus.outcomeUnknown =>
        AutomationResultStatus.outcomeUnknown,
      ToolExecutionStatus.failed ||
      ToolExecutionStatus.notExecuted => AutomationResultStatus.failed,
    },
  };

  void recordTrace({
    required String executionId,
    required String goal,
    required AutomationResultStatus status,
    required String summary,
    int? pauseIndex,
    String? pauseTool,
    required DateTime startedAt,
  }) {
    _ledger?.record(
      AutomationTrace(
        executionId: executionId,
        goal: goal,
        status: status,
        summary: summary,
        pauseIndex: pauseIndex,
        pauseTool: pauseTool,
        startedAt: startedAt,
        endedAt: DateTime.now(),
      ),
    );
  }
}
