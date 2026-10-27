part of 'plan_execution_coordinator.dart';

/// Estado y dependencias compartidas, sin ejecutar durante la construcción.
abstract class _PlanExecutionState {
  _PlanExecutionState({
    required PolicyEngine policy,
    required ActionPathRouter router,
    required AgentExecutor executor,
    required Future<ToolOutcome> Function(
      ToolCall call, {
      bool humanInitiated,
      bool confirmed,
      String? executionId,
      ToolExecutionBudget? budget,
      ExecutionCancellationToken? cancellation,
      ExecutionJournalEntry? executionIntent,
      RuleExecutionAuthority? authority,
      void Function()? onPhysicalEffectDispatched,
    })
    runToolGuarded,
    required Future<String> Function(
      ToolCall call,
      ToolDefinition tool,
      ToolExecutionBudget budget,
    )
    executeWithTimeout,
    Future<ToolExecutionReport> Function(
      ToolCall,
      ToolDefinition,
      ToolExecutionBudget,
    )?
    executeReportWithTimeout,
    OwnedToolReport? executeOwnedReportWithTimeout,
    ExecutionJournal? executionJournal,
  }) : _policy = policy,
       _router = router,
       _executor = executor,
       _runToolGuarded = runToolGuarded,
       _executeWithTimeout = executeWithTimeout,
       _executeReportWithTimeout = executeReportWithTimeout,
       _executeOwnedReportWithTimeout = executeOwnedReportWithTimeout,
       _executionJournal = executionJournal;

  final PolicyEngine _policy;
  final ActionPathRouter _router;
  final AgentExecutor _executor;
  final Future<ToolOutcome> Function(
    ToolCall call, {
    bool humanInitiated,
    bool confirmed,
    String? executionId,
    ToolExecutionBudget? budget,
    ExecutionCancellationToken? cancellation,
    ExecutionJournalEntry? executionIntent,
    RuleExecutionAuthority? authority,
    void Function()? onPhysicalEffectDispatched,
  })
  _runToolGuarded;
  final Future<String> Function(
    ToolCall call,
    ToolDefinition tool,
    ToolExecutionBudget budget,
  )
  _executeWithTimeout;
  final Future<ToolExecutionReport> Function(
    ToolCall,
    ToolDefinition,
    ToolExecutionBudget,
  )?
  _executeReportWithTimeout;
  final OwnedToolReport? _executeOwnedReportWithTimeout;
  final ExecutionJournal? _executionJournal;
  Future<void>? _journalRecovery;

  Future<String> loopFingerprint(ToolCall call);
}
