import '../domain/executable_tool.dart';
import '../domain/tool_definition.dart';
import '../domain/tool_input.dart';
import '../domain/tool_result.dart';

typedef SkillExecuteCallback<A extends ToolArguments, O> =
    Future<ToolResult<O>> Function(ToolExecutionContext<A> context);

final class SkillToolAdapter<A extends ToolArguments, O>
    implements ExecutableTool<A, O> {
  const SkillToolAdapter({required this.definition, required this.onExecute});

  @override
  final ToolDefinition definition;
  final SkillExecuteCallback<A, O> onExecute;

  @override
  Future<ToolResult<O>> execute(ToolExecutionContext<A> context) =>
      onExecute(context);
}
