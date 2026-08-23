import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/services/runtime_engine.dart';

import '../engine/planning/automation_planner.dart';

/// Provider del planner LLM REAL (motor autónomo).
///
/// Lee el cliente del runtime local (LLMEngineClient) y lo inyecta en el
/// [LlmAutomationPlanner]. Se consume al construir el [AutomationCoordinator]
/// (via `planner:`), de modo que `execute(goal)` sin plan generado planee con
/// el modelo local. El planner es DIP: en tests se sustituye por fakes.
final llmAutomationPlannerProvider = Provider<AutomationPlanner>((ref) {
  return LlmAutomationPlanner(
    client: ref.read(runtimeEngineProvider.notifier).client,
  );
});
