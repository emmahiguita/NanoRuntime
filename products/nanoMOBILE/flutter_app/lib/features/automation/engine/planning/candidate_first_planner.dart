/// CandidateFirstPlanner (A13.5) — planificador Candidate-First de producción.
///
/// Encapsula el pipeline probado: generator → selection (Koog si ambigüedad) →
/// governance (firewall/critic/broker) → adapter → ToolCall. Devuelve un
/// resultado tipado; NO ejecuta, NO verifica, NO entrena memoria. Es el puerto
/// que el AutomationCoordinator consulta ANTES del fallback legacy.
library;

import '../execution/agent_tool_dispatcher.dart' show ToolCall;
import '../execution/goal_verifier.dart' show GoalExpectation;
import '../governance/action_governance_pipeline.dart';
import '../governance/intent_spec_compiler.dart';
import 'candidates/candidate_action.dart';
import 'candidates/candidate_generator.dart';
import 'candidates/candidate_provider.dart';
import 'candidates/candidate_selection.dart';
import 'candidates/candidate_selection_engine.dart';
import 'candidates/candidate_selector.dart';
import 'candidates/candidate_tool_call_adapter.dart';

sealed class CandidatePlanResult {
  const CandidatePlanResult();
}

/// Resuelto + governance approved → ToolCall listo para ejecutar.
class CandidatePlanResolved extends CandidatePlanResult {
  final ToolCall call;
  final CandidateAction candidate;

  /// Expectativa de GOAL derivada de la postcondición de la acción (A11/A13.5).
  final GoalExpectation? expectation;

  const CandidatePlanResolved({
    required this.call,
    required this.candidate,
    this.expectation,
  });
}

/// Sin candidatos grounded → el caller usa fallback legacy (planner LLM).
class CandidatePlanNoCandidate extends CandidatePlanResult {
  const CandidatePlanNoCandidate();
}

/// Candidatos resueltos pero governance NO aprobó → decisión tipada.
class CandidatePlanGoverned extends CandidatePlanResult {
  final GovernanceOutcome outcome;

  const CandidatePlanGoverned(this.outcome);
}

class CandidateFirstPlanner {
  CandidateFirstPlanner({
    required CandidateActionGenerator generator,
    required CandidateSelectionEngine selection,
    required ActionGovernancePipeline governance,
    required CandidateToolCallAdapter adapter,
  }) : _generator = generator,
       _selection = selection,
       _governance = governance,
       _adapter = adapter;

  final CandidateActionGenerator _generator;
  final CandidateSelectionEngine _selection;
  final ActionGovernancePipeline _governance;
  final CandidateToolCallAdapter _adapter;

  Future<CandidatePlanResult> plan(String goal) async {
    final intent = const IntentSpecCompiler().compile(goal);

    final generated = await _generator.generate(CandidateRequest(goal));
    if (generated.candidates.isEmpty) {
      return const CandidatePlanNoCandidate();
    }

    final selected = await _selection.select(
      CandidateSelectionRequest(goal: goal, candidates: generated.candidates),
    );
    if (selected is! SelectedCandidate) {
      return const CandidatePlanNoCandidate(); // ambiguo/no seleccionado → legacy
    }

    final outcome = _governance.govern(intent, selected.candidate);
    if (outcome is! GovernanceApproved) {
      return CandidatePlanGoverned(outcome);
    }

    final call = _adapter.toToolCall(selected.candidate);
    return CandidatePlanResolved(
      call: call,
      candidate: selected.candidate,
      expectation: _goalExpectationFor(selected.candidate),
    );
  }

  /// Deriva la expectativa de GOAL (GoalVerifier) de la postcondición de la
  /// acción (ActionExpectation). Sin postcondición → null (completedUnverified).
  GoalExpectation? _goalExpectationFor(CandidateAction candidate) {
    final e = candidate.expectation;
    if (e == null) return null;
    if (e.expectedPackage == null &&
        e.expectedText == null &&
        e.forbiddenText == null) {
      return null;
    }
    return GoalExpectation(
      expectedPackage: e.expectedPackage,
      visibleText: e.expectedText,
      absentText: e.forbiddenText,
    );
  }
}
