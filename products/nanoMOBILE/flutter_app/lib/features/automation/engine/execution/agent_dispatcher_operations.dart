part of 'agent_tool_dispatcher.dart';

/// Contratos internos para coordinar estado y operaciones sin dependencias circulares.
abstract interface class _AgentDispatcherOperations {
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
  });
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
  });
  Future<String> _executeWithTimeout(
    ToolCall call,
    ToolDefinition tool,
    ToolExecutionBudget budget, {
    ExecutionCancellationToken? cancellation,
  });
  Future<ToolExecutionReport> _executeReportWithTimeout(
    ToolCall call,
    ToolDefinition tool,
    ToolExecutionBudget budget, {
    ExecutionCancellationToken? cancellation,
  });
  void resetTurn();
}
