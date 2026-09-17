import 'dart:async';

import '../domain/executable_tool.dart';
import '../domain/tool_input.dart';
import '../domain/tool_result.dart';
import '../domain/tool_risk.dart';

final class ToolExecutor {
  const ToolExecutor();

  Future<ToolResult<Object?>> execute({
    required RegisteredTool tool,
    required ToolExecutionContext<ToolArguments> context,
  }) async {
    final startedAt = DateTime.now();
    try {
      final result = await tool
          .execute(context)
          .timeout(tool.definition.timeout);
      return result.copyWith(
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        executionId: context.executionId,
      );
    } on TimeoutException {
      final mayHaveEscaped = switch (tool.definition.sideEffect) {
        ToolSideEffect.externalWrite ||
        ToolSideEffect.communication ||
        ToolSideEffect.destructive => true,
        _ => false,
      };
      return ToolResult<Object?>(
        executionStatus: ToolExecutionStatus.timedOut,
        verificationStatus: mayHaveEscaped
            ? ToolVerificationStatus.unknown
            : ToolVerificationStatus.notRequired,
        failure: ToolFailure(
          code: mayHaveEscaped ? 'timeout_outcome_unknown' : 'timeout',
          message:
              '${tool.definition.versionedId} excedió ${tool.definition.timeout.inMilliseconds} ms.',
          retryable: !mayHaveEscaped,
        ),
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        executionId: context.executionId,
      );
    } on Object catch (error) {
      return ToolResult<Object?>.failed(
        failure: ToolFailure(
          code: 'execution_exception',
          message:
              'Excepción ejecutando ${tool.definition.versionedId}: $error',
        ),
        startedAt: startedAt,
        finishedAt: DateTime.now(),
        executionId: context.executionId,
      );
    }
  }
}
