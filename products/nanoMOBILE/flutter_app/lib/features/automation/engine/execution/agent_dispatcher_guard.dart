part of 'agent_tool_dispatcher.dart';

/// Dispatcher: guard; conserva autorización y cancelación por ejecución.
mixin _AgentDispatcherGuard on _AgentDispatcherBase {
  @override
  Future<ToolOutcome> _runToolGuarded(
    ToolCall call, {
    bool humanInitiated = false,
    bool confirmed = false,
    String? semanticAction,
    String? executionId,
    ExecutionJournalEntry? executionIntent,
    ToolExecutionBudget? budget,
    ExecutionCancellationToken? cancellation,
    RuleExecutionAuthority? authority,
    void Function()? onPhysicalEffectDispatched,
  }) async {
    cancellation?.throwIfCancelled();
    final runBudget = budget ?? ToolExecutionBudget();
    final decision = _policy.decide(
      call.tool,
      stepsUsed: runBudget.stepsUsed,
      humanInitiated: humanInitiated,
      confirmed: confirmed,
      semanticAction: semanticAction,
    );
    if (decision.denied) {
      // Herramienta fuera del registro: el modelo ve la lista completa y
      // puede autocorregirse en la siguiente ronda.
      var feedback = '[policy] ${decision.reason}.';
      if (decision.tool == null) {
        final names = _policy.registry.all.map((t) => t.name).join(', ');
        feedback += ' Disponibles: $names.';
      }
      return ToolOutcome(verdict: PolicyVerdict.denied, feedback: feedback);
    }
    final tool = decision.tool!;
    final missingInputs = tool.requiredInputs.where(
      (input) => !call.hasInput(input),
    );
    if (missingInputs.isNotEmpty) {
      return ToolOutcome(
        verdict: PolicyVerdict.denied,
        feedback:
            '[policy] "${tool.name}" requiere ${missingInputs.join(', ')}.',
      );
    }
    if (decision.needsConfirmation) {
      // WA-AUTH-04: la autoridad standing de una regla salta la confirmación
      // SOLO para la acción exacta autorizada (tool + texto fijo). Cualquier
      // otra llamada del plan conserva su confirmación.
      final standingGranted =
          authority != null &&
          authority.satisfiesCall(call.tool, call.textArg ?? '');
      if (!standingGranted) {
        return ToolOutcome(
          verdict: PolicyVerdict.needsConfirmation,
          pendingCall: call,
          feedback:
              '[policy] "${tool.name}" (${tool.description.toLowerCase()}) — requiere tu confirmación.',
        );
      }
    }
    final contextLockFailure = await _notificationHandler.validateContextLock(
      call,
      tool,
      authority: authority,
    );
    if (contextLockFailure != null) return contextLockFailure;
    final semanticRisk = semanticAction == null
        ? null
        : automationSemanticPolicy(semanticAction)?.risk;
    final isAppLauncher =
        call.tool == 'launch_app' ||
        call.tool == 'open_app' ||
        call.tool == 'abrir' ||
        call.tool == 'launch';
    final navigates =
        !isAppLauncher &&
        (tool.semanticPolicy.risk == SemanticActionRisk.navigation ||
            semanticRisk == SemanticActionRisk.navigation);
    if (navigates) {
      final source = _currentSituationSource;
      if (source == null) {
        return const ToolOutcome(
          verdict: PolicyVerdict.denied,
          feedback:
              '[currentSituationUnavailable] Navegación bloqueada: no hay fuente de situación actual.',
        );
      }
      final CurrentSituation? situation;
      try {
        situation = await source();
      } on Object catch (error) {
        return ToolOutcome(
          verdict: PolicyVerdict.denied,
          feedback:
              '[currentSituationUnavailable] Navegación bloqueada: no se pudo observar la situación actual ($error).',
        );
      }
      if (situation == null || !situation.hasStructuralEvidence) {
        return const ToolOutcome(
          verdict: PolicyVerdict.denied,
          feedback:
              '[currentSituationUnavailable] Navegación bloqueada: no existe evidencia estructural de la superficie actual.',
        );
      }
    }
    if (tool.irreversible) {
      return _planCoordinator.runIrreversibleTool(
        call,
        tool,
        runBudget,
        executionId: executionId,
        executionIntent: executionIntent,
        allowPreviouslyUncertain: confirmed && executionIntent != null,
        cancellation: cancellation,
        onPhysicalEffectDispatched: onPhysicalEffectDispatched,
      );
    }
    if (tool.risk != ToolRisk.none && tool.risk != ToolRisk.read) {
      onPhysicalEffectDispatched?.call();
    }
    final report = await _executeReportWithTimeout(
      call,
      tool,
      runBudget,
      cancellation: cancellation,
    );
    return ToolOutcome(
      verdict: PolicyVerdict.allow,
      feedback: report.feedback,
      executionStatus: report.status,
      data: report.data,
    );
  }

  /// Resultado de ejecutar un plan multi-paso ([runPlanGuarded]).
}
