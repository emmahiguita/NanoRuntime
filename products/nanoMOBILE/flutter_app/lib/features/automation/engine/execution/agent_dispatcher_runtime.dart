part of 'agent_tool_dispatcher.dart';

/// Dispatcher: runtime; conserva autorización y cancelación por ejecución.
mixin _AgentDispatcherRuntime on _AgentDispatcherBase {
  /// Compatibilidad de consumidores antiguos; producción conserva el informe tipado.
  @override
  Future<String> _executeWithTimeout(
    ToolCall call,
    ToolDefinition tool,
    ToolExecutionBudget budget, {
    ExecutionCancellationToken? cancellation,
  }) async => (await _executeReportWithTimeout(
    call,
    tool,
    budget,
    cancellation: cancellation,
  )).feedback;

  /// Una espera vencida no certifica cancelación física ni permite repetir un efecto.
  @override
  Future<ToolExecutionReport> _executeReportWithTimeout(
    ToolCall call,
    ToolDefinition tool,
    ToolExecutionBudget budget, {
    ExecutionCancellationToken? cancellation,
  }) async {
    budget.recordExecution();
    final token = cancellation ?? ExecutionCancellationToken();
    final requested = int.tryParse('${call.args?['timeout']}');
    final timeout =
        call.tool == 'linux.run' && requested != null && requested > 0
        ? Duration(seconds: requested.clamp(1, 600))
        : tool.timeout;
    try {
      token.throwIfCancelled();
      final Future<ToolExecutionReport> operation;
      if (call.tool.startsWith('mcp.')) {
        operation = _mcpHandler.executeReport(call, cancellation: token);
      } else {
        operation = (this as AgentToolDispatcher)
            ._executeTool(call, cancellation: token)
            .then(ToolExecutionReport.legacy);
      }
      return await operation.timeout(
        timeout,
        onTimeout: () {
          token.cancel();
          final read = tool.risk == ToolRisk.read || tool.risk == ToolRisk.none;
          return ToolExecutionReport(
            '${tool.name}: tiempo de espera agotado. ${read ? "Lectura no completada." : "La operación puede seguir activa; resultado incierto."}',
            read
                ? ToolExecutionStatus.failed
                : ToolExecutionStatus.outcomeUnknown,
          );
        },
      );
    } on Object {
      return ToolExecutionReport(
        '${tool.name}: la operación no pudo completarse.',
        tool.risk == ToolRisk.read
            ? ToolExecutionStatus.failed
            : ToolExecutionStatus.outcomeUnknown,
      );
    }
  }
}
