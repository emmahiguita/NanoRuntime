part of 'automation_coordinator.dart';

/// Extension interna para ejecución de flujos, tareas cross-app y herramientas en AutomationCoordinator (SRP).
extension AutomationCoordinatorExecution on AutomationCoordinator {
  // ── Camino determinista (C7→C8) ───────────────────────────────────────────

  /// Intenta resolver [goal] con un flujo VERIFICADO en cache (sin LLM).
  Future<({FlowExecutionResult result, List<ToolCall> steps})?>
  tryDeterministicInternal(
    String goal, {
    GoalExpectation? expectation,
    AutomationRun? run,
    ActionConfirmation? confirmation,
  }) async {
    final startedAt = DateTime.now();
    final cache = _cache;
    final flow = _flowExecutor;
    if (cache == null || flow == null) return null;
    final verified = cache.planFor(goal);
    if (verified == null) return null;
    // La memoria nunca puede degradar el invariante de navegación. Un flujo
    // legacy multi-UI se invalida y se vuelve a planificar semánticamente.
    if (_dispatcher.requiresGoalDirectedExecution(verified.steps)) {
      cache.recordFailure(goal);
      return null;
    }
    if (run != null && confirmation != null) {
      throw StateError(
        'AutomationRun no puede combinarse con confirmación legacy',
      );
    }
    final flowRun =
        run ??
        AutomationRun(
          executionId: confirmation?.executionId ?? _newId(),
          goal: goal,
          confirmation: confirmation,
        );
    flowRun.beginPlanning();
    final result = await flow.execute(
      NanoFlow(goal: goal, steps: verified.steps, goalExpectation: expectation),
      confirmation: flowRun.confirmation,
      executionId: flowRun.executionId,
      cancellation: flowRun.cancellation,
      onStep: flowRun.enterStep,
      onPhysicalEffectDispatched: flowRun.markPhysicalEffectDispatched,
    );
    if (result.plan.confirmation != null) {
      flowRun.waitForConfirmation(result.plan.confirmation!);
    } else {
      flowRun.beginVerification();
    }
    // Degradar confianza SOLO en fallo REAL (no completado y SIN pausa).
    // Una pausa (pauseIndex != null) es un estado normal (pedir confirmación),
    // no un fallo — no debe degradar el flujo en cache.
    if (!result.completed && result.plan.pauseIndex == null) {
      cache.recordFailure(goal);
    }
    recordTrace(
      executionId: flowRun.executionId,
      goal: goal,
      status: statusFromFlow(result),
      summary: result.plan.summary,
      pauseIndex: result.plan.pauseIndex,
      pauseTool: result.plan.pauseCall?.tool,
      startedAt: startedAt,
    );
    if (run == null) {
      flowRun.finish(
        status: statusFromFlow(result).name,
        reason: result.plan.summary,
      );
    }
    return (result: result, steps: verified.steps);
  }

  /// Ejecuta exclusivamente un flujo conocido del catálogo, sin planner.
  Future<({AutomationResult result, List<ToolCall> steps})?>
  tryKnownFlowInternal(String goal) async {
    final known = _catalog?.forGoal(goal);
    if (known == null || known.steps.isEmpty) return null;
    final result = await execute(
      AutomationGoal(text: goal, expectation: known.expectation),
    );
    return (result: result, steps: known.steps);
  }

  // ── Ejecución de plan / herramienta ───────────────────────────────────────

  Future<List<TaskStepResult>?> runCrossAppTaskInternal(
    String goal, {
    AutomationRun? run,
    ActionConfirmation? confirmation,
    String? executionId,
    bool deterministicOnly = false,
  }) async {
    final orchestrator = _taskOrchestrator;
    if (orchestrator == null) return null;

    if (run != null &&
        (confirmation != null || executionId != null || run.goal != goal)) {
      return const [
        TaskStepResult(
          status: TaskStepStatus.failed,
          reason: 'ownership ambiguo o AutomationRun de otro objetivo',
        ),
      ];
    }
    final taskRun =
        run ??
        AutomationRun(
          executionId: executionId ?? confirmation?.executionId ?? _newId(),
          goal: goal,
          confirmation: confirmation,
        );
    final TaskPlan? plan;
    final decomposer = deterministicOnly ? null : _taskDecomposer;
    if (decomposer != null) {
      plan = await decomposer.decompose(goal);
    } else {
      plan = _taskPlanner?.plan(goal);
    }
    if (plan == null) return null;
    return orchestrator.run(plan, run: taskRun);
  }

  Future<({AutomationResult result, List<TaskStepResult> steps})?>
  tryCrossAppInternal(
    String goal, {
    AutomationRun? run,
    ActionConfirmation? confirmation,
    String? executionId,
    bool deterministicOnly = true,
  }) async {
    if (run != null && (confirmation != null || executionId != null)) {
      throw StateError('AutomationRun no puede combinarse con estado legacy');
    }
    final taskRun =
        run ??
        AutomationRun(
          executionId: executionId ?? confirmation?.executionId ?? _newId(),
          goal: goal,
          confirmation: confirmation,
        );
    final steps = await runCrossAppTaskInternal(
      goal,
      run: taskRun,
      deterministicOnly: deterministicOnly,
    );
    if (steps == null) return null;
    final result = await _finalizeExecutionForCrossApp(
      goal: goal,
      taskRun: taskRun,
      steps: steps,
    );
    return (result: result, steps: steps);
  }

  Future<AutomationResult> _finalizeExecutionForCrossApp({
    required String goal,
    required AutomationRun taskRun,
    required List<TaskStepResult> steps,
  }) async {
    final allCompleted =
        steps.isNotEmpty &&
        steps.every((s) => s.status == TaskStepStatus.completed);
    final anyFailed = steps.any((s) => s.status == TaskStepStatus.failed);
    final pendingStep = steps.where((s) => s.status == TaskStepStatus.needsConfirmation).firstOrNull;
    final anyPaused = pendingStep != null;
    final status = anyPaused
        ? AutomationResultStatus.paused
        : anyFailed
        ? AutomationResultStatus.failed
        : allCompleted
        ? AutomationResultStatus.completed
        : AutomationResultStatus.completedUnverified;
    final summary = steps.asMap().entries.map((e) => 'step[${e.key}]:${e.value.status.name}').join(', ');
    recordTrace(
      executionId: taskRun.executionId,
      goal: goal,
      status: status,
      summary: summary,
      startedAt: DateTime.now(),
    );
    return AutomationResult(
      executionId: taskRun.executionId,
      status: status,
      reason: summary,
      confirmation: pendingStep?.confirmation,
    );
  }

  Future<PlanOutcome> runPlanInternal(
    List<ToolCall> plan, {
    AutomationRun? run,
    ActionConfirmation? confirmation,
    String? executionId,
    bool confirmed = false,
    String? recordGoal,
    GoalExpectation? expectation,
    RuleExecutionAuthority? authority,
  }) async {
    if (run != null && (confirmation != null || executionId != null)) {
      throw StateError('AutomationRun no puede combinarse con estado legacy');
    }
    final planRun =
        run ??
        AutomationRun(
          executionId: executionId ?? confirmation?.executionId ?? _newId(),
          goal: recordGoal ?? (plan.isEmpty ? '' : plan.first.tool),
          confirmation: confirmation,
        );
    final ownsRegistration = run == null;
    if (ownsRegistration && _activeRuns.containsKey(planRun.executionId)) {
      return const PlanOutcome(
        completed: false,
        steps: [
          ToolOutcome(
            verdict: PolicyVerdict.denied,
            feedback: '[runConflict] executionId ya está activo.',
          ),
        ],
        summary: '[runConflict] executionId ya está activo.',
      );
    }
    if (ownsRegistration) _activeRuns[planRun.executionId] = planRun;
    final startedAt = DateTime.now();
    try {
      planRun.beginPlanning();
      final outcome = await _dispatcher.runPlanGuarded(
        plan,
        confirmation: planRun.confirmation,
        executionId: planRun.executionId,
        confirmed: confirmed,
        cancellation: planRun.cancellation,
        onStep: planRun.enterStep,
        authority: authority,
        onPhysicalEffectDispatched: planRun.markPhysicalEffectDispatched,
      );
      if (outcome.confirmation != null) {
        planRun.waitForConfirmation(outcome.confirmation!);
      } else {
        planRun.beginVerification();
      }
      recordTrace(
        executionId: planRun.executionId,
        goal: recordGoal ?? (plan.isNotEmpty ? plan.first.tool : ''),
        status: statusFromPlan(outcome),
        summary: outcome.summary,
        pauseIndex: outcome.pauseIndex,
        pauseTool: outcome.pauseCall?.tool,
        startedAt: startedAt,
      );
      if (ownsRegistration) {
        planRun.finish(
          status: statusFromPlan(outcome).name,
          reason: outcome.summary,
        );
      }
      return outcome;
    } on ExecutionCancelled {
      if (!ownsRegistration) rethrow;
      final feedback = planRun.hasDispatchedPhysicalEffect
          ? '[timeoutOutcomeUnknown] Ejecución cancelada tras iniciar efectos físicos; resultado incierto.'
          : '[cancelled] Ejecución cancelada por el usuario.';
      final outcome = PlanOutcome(
        completed: false,
        steps: [
          ToolOutcome(
            verdict: PolicyVerdict.denied,
            feedback: feedback,
            executionStatus: planRun.hasDispatchedPhysicalEffect
                ? ToolExecutionStatus.outcomeUnknown
                : ToolExecutionStatus.notExecuted,
          ),
        ],
        summary: feedback,
      );
      recordTrace(
        executionId: planRun.executionId,
        goal: recordGoal ?? (plan.isNotEmpty ? plan.first.tool : ''),
        status: planRun.hasDispatchedPhysicalEffect
            ? AutomationResultStatus.outcomeUnknown
            : AutomationResultStatus.cancelled,
        summary: feedback,
        startedAt: startedAt,
      );
      if (ownsRegistration) {
        planRun.finish(
          status: planRun.hasDispatchedPhysicalEffect
              ? 'outcomeUnknown'
              : 'cancelled',
          reason: feedback,
        );
      }
      return outcome;
    } on Object catch (e, st) {
      if (!ownsRegistration) rethrow;
      debugPrint('[coordinator.runPlan] excepción no manejada: $e\n$st');
      final feedback = '[exception] Error inesperado en runPlan: $e';
      final outcome = PlanOutcome(
        completed: false,
        steps: [ToolOutcome(verdict: PolicyVerdict.denied, feedback: feedback)],
        summary: feedback,
      );
      recordTrace(
        executionId: planRun.executionId,
        goal: recordGoal ?? (plan.isNotEmpty ? plan.first.tool : ''),
        status: AutomationResultStatus.failed,
        summary: feedback,
        startedAt: startedAt,
      );
      planRun.finish(status: 'failed', reason: feedback);
      return outcome;
    } finally {
      if (ownsRegistration &&
          identical(_activeRuns[planRun.executionId], planRun)) {
        _activeRuns.remove(planRun.executionId);
      }
    }
  }

  Future<void> learn(
    String goal,
    List<ToolCall> plan,
    AutomationResult result,
    GoalExpectation? expectation,
  ) async {
    final cache = _cache;
    if (cache == null) return;
    if (expectation == null) return;
    if (result.status == AutomationResultStatus.completed) {
      cache.recordSuccess(goal, plan);
    } else {
      cache.recordFailure(goal);
    }
  }

  Future<ToolOutcome> runToolInternal(
    ToolCall call, {
    bool confirmed = false,
    String? executionId,
  }) async {
    final run = AutomationRun(
      executionId: executionId ?? _newId(),
      goal: call.tool,
    );
    if (_activeRuns.containsKey(run.executionId)) {
      return const ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback: '[runConflict] executionId ya está activo.',
      );
    }
    _activeRuns[run.executionId] = run;
    final startedAt = DateTime.now();
    try {
      run.beginPlanning();
      run.enterStep(0);
      final outcome = confirmed
          ? const ToolOutcome(
              verdict: PolicyVerdict.denied,
              feedback:
                  '[confirmationTokenRequired] La confirmación booleana no '
                  'autoriza una acción. Reanuda mediante ActionConfirmation.',
              executionStatus: ToolExecutionStatus.notExecuted,
            )
          : await _dispatcher.runToolGuarded(
              call,
              executionId: run.executionId,
              cancellation: run.cancellation,
              onPhysicalEffectDispatched: run.markPhysicalEffectDispatched,
            );
      if (!outcome.needsConfirmation) run.beginVerification();
      recordTrace(
        executionId: run.executionId,
        goal: call.tool,
        status: statusFromTool(outcome),
        summary: outcome.feedback,
        startedAt: startedAt,
      );
      run.finish(
        status: statusFromTool(outcome).name,
        reason: outcome.feedback,
      );
      return outcome;
    } on ExecutionCancelled {
      final feedback = run.hasDispatchedPhysicalEffect
          ? '[timeoutOutcomeUnknown] Ejecución cancelada tras iniciar efectos físicos; resultado incierto.'
          : '[cancelled] Ejecución cancelada por el usuario.';
      final outcome = ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback: feedback,
        executionStatus: run.hasDispatchedPhysicalEffect
            ? ToolExecutionStatus.outcomeUnknown
            : ToolExecutionStatus.notExecuted,
      );
      recordTrace(
        executionId: run.executionId,
        goal: call.tool,
        status: run.hasDispatchedPhysicalEffect
            ? AutomationResultStatus.outcomeUnknown
            : AutomationResultStatus.cancelled,
        summary: outcome.feedback,
        startedAt: startedAt,
      );
      run.finish(
        status: run.hasDispatchedPhysicalEffect ? 'outcomeUnknown' : 'cancelled',
        reason: outcome.feedback,
      );
      return outcome;
    } on Object catch (e, st) {
      debugPrint('[coordinator.runTool] excepción no manejada: $e\n$st');
      final outcome = ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback: '[exception] Error inesperado en runTool: $e',
      );
      recordTrace(
        executionId: run.executionId,
        goal: call.tool,
        status: AutomationResultStatus.failed,
        summary: outcome.feedback,
        startedAt: startedAt,
      );
      run.finish(status: 'failed', reason: outcome.feedback);
      return outcome;
    } finally {
      if (identical(_activeRuns[run.executionId], run)) {
        _activeRuns.remove(run.executionId);
      }
    }
  }

  Future<String> runCommandInternal(String command) async {
    final run = AutomationRun(executionId: _newId(), goal: command);
    _activeRuns[run.executionId] = run;
    try {
      run.beginPlanning();
      run.enterStep(0);
      final feedback = await _dispatcher.runCommand(
        command,
        executionId: run.executionId,
        cancellation: run.cancellation,
      );
      if (run.cancellation.isCancelled) {
        final cancelled = run.hasDispatchedPhysicalEffect
            ? '[timeoutOutcomeUnknown] Ejecución cancelada tras iniciar efectos físicos; resultado incierto.'
            : '[cancelled] Ejecución cancelada por el usuario.';
        run.finish(
          status: run.hasDispatchedPhysicalEffect ? 'outcomeUnknown' : 'cancelled',
          reason: cancelled,
        );
        return cancelled;
      }
      run.beginVerification();
      run.finish(status: 'returned', reason: feedback);
      return feedback;
    } on ExecutionCancelled {
      final cancelled = run.hasDispatchedPhysicalEffect
          ? '[timeoutOutcomeUnknown] Ejecución cancelada tras iniciar efectos físicos; resultado incierto.'
          : '[cancelled] Ejecución cancelada por el usuario.';
      run.finish(
        status: run.hasDispatchedPhysicalEffect ? 'outcomeUnknown' : 'cancelled',
        reason: cancelled,
      );
      return cancelled;
    } finally {
      if (identical(_activeRuns[run.executionId], run)) {
        _activeRuns.remove(run.executionId);
      }
    }
  }

  Future<List<ToolCall>> resolveSelectors(
    List<ToolCall> plan,
    String goal,
  ) async {
    final mux = _perceptionMux;
    final resolved = <ToolCall>[];
    for (final c in plan) {
      final sel = c.selector ?? '';
      final concept = conceptFromSelector(sel);
      final semantic =
          sel.startsWith('text=') ||
          sel.startsWith('text~=') ||
          sel.startsWith('desc=') ||
          sel.startsWith('desc~=');
      if (semantic && concept.isNotEmpty) {
        var used = sel;
        if (mux != null) {
          final perceived = await mux.resolve(concept);
          if (perceived != null) used = perceived;
        }
        resolved.add(ToolCall(tool: c.tool, selector: used, text: c.text));
      } else {
        resolved.add(c);
      }
    }
    return resolved;
  }
}
