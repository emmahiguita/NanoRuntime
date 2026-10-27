part of 'agent_tool_dispatcher.dart';

/// Dispatcher: guard api; conserva autorización y cancelación por ejecución.
mixin _AgentDispatcherGuardApi on _AgentDispatcherBase {
  @override
  Future<ToolOutcome> runToolGuarded(
    ToolCall call, {
    bool humanInitiated = false,
    bool confirmed = false,
    String? executionId,
    ExecutionJournalEntry? executionIntent,
    ToolExecutionBudget? budget,
    ExecutionCancellationToken? cancellation,
    RuleExecutionAuthority? authority,
    void Function()? onPhysicalEffectDispatched,
  }) => _runToolGuarded(
    call,
    humanInitiated: humanInitiated,
    confirmed: confirmed,
    executionId: executionId,
    executionIntent: executionIntent,
    budget: budget,
    cancellation: cancellation,
    authority: authority,
    onPhysicalEffectDispatched: onPhysicalEffectDispatched,
  );

  /// Variante para TaskPlan: añade la identidad semántica sin cambiar el
  /// contrato legacy de [runToolGuarded]. Ambas políticas se combinan de forma
  /// conservadora antes de llegar al mismo ejecutor.
  Future<ToolOutcome> runSemanticToolGuarded(
    ToolCall call, {
    required String semanticAction,
    bool confirmed = false,
    String? executionId,
    ExecutionJournalEntry? executionIntent,
    ToolExecutionBudget? budget,
    ExecutionCancellationToken? cancellation,
    void Function()? onPhysicalEffectDispatched,
  }) => _runToolGuarded(
    call,
    confirmed: confirmed,
    semanticAction: semanticAction,
    executionId: executionId,
    executionIntent: executionIntent,
    budget: budget,
    cancellation: cancellation,
    onPhysicalEffectDispatched: onPhysicalEffectDispatched,
  );
}
