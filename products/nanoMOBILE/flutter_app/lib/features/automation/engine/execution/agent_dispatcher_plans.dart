part of 'agent_tool_dispatcher.dart';

/// Dispatcher: plans; conserva autorización y cancelación por ejecución.
mixin _AgentDispatcherPlans on _AgentDispatcherBase {
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
  }) => _planCoordinator.runPlanGuarded(
    plan,
    humanInitiated: humanInitiated,
    confirmation: confirmation,
    executionId: executionId,
    confirmed: confirmed,
    cancellation: cancellation,
    onStep: onStep,
    authority: authority,
    onPhysicalEffectDispatched: onPhysicalEffectDispatched,
  );

  /// Compatibilidad: ejecuta bajo política y degrada el estado de
  /// confirmación a texto (llamadores que no manejan el diálogo).
  Future<String> runTool(ToolCall call) async {
    resetTurn();
    final outcome = await runToolGuarded(call);
    return outcome.feedback;
  }
}
