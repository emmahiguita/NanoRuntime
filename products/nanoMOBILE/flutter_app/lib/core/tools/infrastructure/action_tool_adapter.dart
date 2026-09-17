import '../domain/executable_tool.dart';
import '../domain/tool_definition.dart';
import '../domain/tool_input.dart';
import '../domain/tool_result.dart';

typedef ActionExecuteCallback<A extends ToolArguments, O> =
    Future<ToolResult<O>> Function(ToolExecutionContext<A> context);
typedef ActionVerifyCallback<A extends ToolArguments, O> =
    Future<ToolVerificationResult> Function(
      ToolExecutionContext<A> context,
      ToolResult<O> result,
    );

final class ActionToolAdapter<A extends ToolArguments, O>
    implements ExecutableTool<A, O> {
  const ActionToolAdapter({required this.definition, required this.onExecute});

  @override
  final ToolDefinition definition;
  final ActionExecuteCallback<A, O> onExecute;

  @override
  Future<ToolResult<O>> execute(ToolExecutionContext<A> context) =>
      onExecute(context);
}

final class VerifiableActionToolAdapter<A extends ToolArguments, O>
    implements ExecutableTool<A, O>, VerifiableTool<A, O> {
  const VerifiableActionToolAdapter({
    required this.definition,
    required this.onExecute,
    required this.onVerify,
  });

  @override
  final ToolDefinition definition;
  final ActionExecuteCallback<A, O> onExecute;
  final ActionVerifyCallback<A, O> onVerify;

  @override
  Future<ToolResult<O>> execute(ToolExecutionContext<A> context) =>
      onExecute(context);

  @override
  Future<ToolVerificationResult> verify(
    ToolExecutionContext<A> context,
    ToolResult<O> result,
  ) => onVerify(context, result);
}
