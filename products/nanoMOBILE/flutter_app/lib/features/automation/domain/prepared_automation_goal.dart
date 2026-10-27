import 'automation_goal.dart';
import '../engine/execution/tool_call.dart';

/// Objetivo y plan opcional ya sustentado en datos reales. La política del
/// coordinador valida cada ToolCall; este valor no autoriza su ejecución.
final class PreparedAutomationGoal {
  PreparedAutomationGoal(this.goal, {List<ToolCall>? plan})
    : plan = plan == null ? null : List.unmodifiable(plan);
  final AutomationGoal goal;
  final List<ToolCall>? plan;
}
