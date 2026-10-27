import 'dart:async';

import '../governance/action_confirmation.dart';
import '../governance/rule_execution_authority.dart';
import '../orchestration/execution_journal.dart';
import '../voice/execution_cancellation.dart';
import 'action_path_router.dart';
import 'agent_executor.dart';
import 'tool_call.dart';
import 'tool_loop_detector.dart';
import 'tool_outcome.dart';
import 'tool_execution_report.dart';
import 'tool_registry.dart';

/// Coordinador de ejecución de planes multi-paso y acciones irreversibles bajo Journaling.
/// Cumple SRP: orquesta la secuencia de pasos, consumo de tokens de confirmación,
/// detección de bucles de estado, persistencia de transiciones de journal y timeout.

part 'plan_execution_state.dart';
part 'plan_run.dart';
part 'plan_confirmation.dart';
part 'plan_record.dart';
part 'plan_irreversible.dart';
part 'plan_owned_execution.dart';
part 'plan_fingerprint.dart';

/// API de planes: usa informes tipados y conserva la frontera de confirmación.
class PlanExecutionCoordinator extends _PlanExecutionState
    with _PlanRun, _PlanIrreversible, _PlanFingerprint {
  PlanExecutionCoordinator({
    required super.policy,
    required super.router,
    required super.executor,
    required super.runToolGuarded,
    required super.executeWithTimeout,
    super.executeReportWithTimeout,
    super.executeOwnedReportWithTimeout,
    super.executionJournal,
  });
  static const uiStateSensitiveTools = {
    'tap',
    'back',
    'launch_app',
    'write',
    'home',
    'recents',
    'open_notifications',
    'open_quick_settings',
    'swipe',
    'scroll',
    'long_press',
  };

  static bool requiresGoalDirectedExecution(List<ToolCall> plan) =>
      plan.where((call) => uiStateSensitiveTools.contains(call.tool)).length >
      1;

  static String planSignature(List<ToolCall> plan) => canonicalFingerprint(
    plan.map((call) => call.confirmationSignature).toList(growable: false),
  );

  static int _runSequence = 0;
  static String newRunId() =>
      'tool-${DateTime.now().microsecondsSinceEpoch}-${++_runSequence}';

  static bool isFailedFeedback(String feedback) {
    return RegExp(r'^\[[a-zA-Z]+(:|\])').hasMatch(feedback);
  }

  static ToolExecutionStatus executionStatusFor(String feedback) {
    if (feedback.startsWith('[completed]')) {
      return ToolExecutionStatus.completed;
    }
    if (feedback.startsWith('[completedUnverified]')) {
      return ToolExecutionStatus.completedUnverified;
    }
    if (feedback.startsWith('[timeoutOutcomeUnknown]')) {
      return ToolExecutionStatus.outcomeUnknown;
    }
    if (isFailedFeedback(feedback)) return ToolExecutionStatus.failed;
    return ToolExecutionStatus.completed;
  }

  static ExecutionJournalStatus journalStatusFor(
    ToolExecutionStatus s, {
    required ExecutionJournalStatus notExecutedAs,
  }) => switch (s) {
    ToolExecutionStatus.completed => ExecutionJournalStatus.verified,
    ToolExecutionStatus.completedUnverified =>
      ExecutionJournalStatus.completedUnverified,
    ToolExecutionStatus.outcomeUnknown => ExecutionJournalStatus.outcomeUnknown,
    ToolExecutionStatus.failed => ExecutionJournalStatus.failed,
    ToolExecutionStatus.notExecuted => notExecutedAs,
  };
}
