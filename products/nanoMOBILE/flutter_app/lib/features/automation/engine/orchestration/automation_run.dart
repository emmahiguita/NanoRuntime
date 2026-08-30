/// Estado mutable perteneciente a una única ejecución de Automation.
library;

import '../governance/action_confirmation.dart';
import '../navigation/navigation_history.dart';
import '../voice/execution_cancellation.dart';
import 'task_plan.dart';

enum AutomationRunPhase {
  created,
  planning,
  executing,
  waitingConfirmation,
  verifying,
  terminal,
}

final class AutomationRunTerminal {
  final String status;
  final String reason;

  const AutomationRunTerminal({required this.status, required this.reason});
}

/// Aggregate de lifecycle por ejecución.
///
/// El coordinator crea una instancia por entrada y las capas inferiores reciben
/// esa misma identidad. Cancellation, evidencia, paso actual y confirmación no
/// se almacenan en singletons ni se comparten entre ejecuciones concurrentes.
final class AutomationRun {
  AutomationRun({
    required this.executionId,
    required this.goal,
    ActionConfirmation? confirmation,
    ExecutionCancellationToken? cancellation,
    NavigationHistory? navigationHistory,
    DateTime? startedAt,
  }) : _confirmation = confirmation,
       cancellation = cancellation ?? ExecutionCancellationToken(),
       navigationHistory = navigationHistory ?? NavigationHistory(),
       startedAt = startedAt ?? DateTime.now().toUtc();

  final String executionId;
  final String goal;
  final ExecutionCancellationToken cancellation;
  final NavigationHistory navigationHistory;
  final DateTime startedAt;

  final Map<String, RequiredEvidence> _evidenceByStep = {};
  ActionConfirmation? _confirmation;
  AutomationRunPhase _phase = AutomationRunPhase.created;
  int _currentStep = -1;
  AutomationRunTerminal? _terminalResult;

  AutomationRunPhase get phase => _phase;
  int get currentStep => _currentStep;
  ActionConfirmation? get confirmation => _confirmation;
  AutomationRunTerminal? get terminalResult => _terminalResult;
  Map<String, RequiredEvidence> get evidenceSnapshot =>
      Map.unmodifiable(_evidenceByStep);

  void beginPlanning() => _transition(AutomationRunPhase.planning);

  void enterStep(int step) {
    if (step < 0) throw ArgumentError.value(step, 'step');
    _currentStep = step;
    _transition(AutomationRunPhase.executing);
  }

  void beginVerification() => _transition(AutomationRunPhase.verifying);

  void waitForConfirmation(ActionConfirmation confirmation) {
    if (confirmation.executionId != executionId) {
      throw StateError('la confirmación no pertenece a este AutomationRun');
    }
    _confirmation = confirmation;
    _transition(AutomationRunPhase.waitingConfirmation);
  }

  void recordEvidence(String stepId, RequiredEvidence evidence) {
    _evidenceByStep[stepId] = evidence;
  }

  void restoreEvidence(Map<String, RequiredEvidence> evidence) {
    _evidenceByStep
      ..clear()
      ..addAll(evidence);
  }

  void finish({required String status, required String reason}) {
    _terminalResult = AutomationRunTerminal(status: status, reason: reason);
    _phase = AutomationRunPhase.terminal;
  }

  void _transition(AutomationRunPhase next) {
    if (_phase == AutomationRunPhase.terminal) {
      throw StateError('un AutomationRun terminal no puede reanudarse');
    }
    _phase = next;
  }
}
