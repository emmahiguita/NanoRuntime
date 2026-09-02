/// CandidateFirstPlanner (A13.5) — planificador Candidate-First de producción.
///
/// Encapsula el pipeline probado: generator → selection (Koog si ambigüedad) →
/// governance (firewall/critic/broker) → adapter → ToolCall. A15.7: el
/// SystemGraph REAL (async, con accessibility/notification/Linux) se carga lazy
/// y alimenta tanto el SystemIntentCandidateProvider como el governance (broker/
/// critic validan capabilities factuales). Devuelve resultado tipado; NO
/// ejecuta, NO verifica, NO entrena memoria.
library;

import '../execution/agent_tool_dispatcher.dart' show ToolCall;
import '../execution/goal_verifier.dart' show GoalExpectation;
import '../governance/action_governance_pipeline.dart';
import '../governance/intent_spec_compiler.dart';
import '../privilege/shizuku_availability.dart';
import '../system/system_graph.dart';
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

/// Modo de selección (A13.6 observabilidad): determinista, Koog, o sin
/// selección (none). `legacyFallback` lo asigna el coordinator aguas arriba.
enum SelectionMode { deterministic, koog, none }

/// Resuelto + governance approved → ToolCall listo para ejecutar.
class CandidatePlanResolved extends CandidatePlanResult {
  final ToolCall call;
  final CandidateAction candidate;

  /// Expectativa de GOAL derivada de la postcondición de la acción (A11/A13.5).
  final GoalExpectation? expectation;

  final SelectionMode selectionMode;
  final bool koogInvoked;
  final int candidateCount;

  const CandidatePlanResolved({
    required this.call,
    required this.candidate,
    this.expectation,
    required this.selectionMode,
    required this.koogInvoked,
    required this.candidateCount,
  });
}

/// Sin candidatos grounded → el caller usa fallback legacy (planner LLM).
class CandidatePlanNoCandidate extends CandidatePlanResult {
  final int candidateCount;
  const CandidatePlanNoCandidate({this.candidateCount = 0});
}

/// Candidatos resueltos pero governance NO aprobó → decisión tipada.
class CandidatePlanGoverned extends CandidatePlanResult {
  final GovernanceOutcome outcome;

  const CandidatePlanGoverned(this.outcome);
}

class CandidateFirstPlanner {
  CandidateFirstPlanner({
    required CandidateActionGenerator Function(SystemGraph graph)
    generatorBuilder,
    required CandidateSelectionEngine selection,
    required ActionGovernancePipeline governance,
    required CandidateToolCallAdapter adapter,
    required Future<SystemGraph> Function() getGraph,
    Future<ShizukuAvailability> Function()? shizukuSource,
  }) : _generatorBuilder = generatorBuilder,
       _selection = selection,
       _governance = governance,
       _adapter = adapter,
       _getGraph = getGraph,
       _shizukuSource = shizukuSource;

  final CandidateActionGenerator Function(SystemGraph) _generatorBuilder;
  final CandidateSelectionEngine _selection;
  final ActionGovernancePipeline _governance;
  final CandidateToolCallAdapter _adapter;
  final Future<SystemGraph> Function() _getGraph;

  /// Fuente opcional de disponibilidad FACTUAL de Shizuku (A14.3). Inyectada
  /// solo en producción; ausente en tests → el broker la trata como no
  /// disponible (conservador, sin ejecución privilegiada).
  final Future<ShizukuAvailability> Function()? _shizukuSource;

  Future<CandidatePlanResult> plan(String goal) async {
    final intent = const IntentSpecCompiler().compile(goal);

    // A15.7: SystemGraph real (async) para availability + governance.
    final graph = await _getGraph();

    final generated = await _generatorBuilder(
      graph,
    ).generate(CandidateRequest(goal));
    final candidateCount = generated.candidates.length;
    if (generated.candidates.isEmpty) {
      return CandidatePlanNoCandidate(candidateCount: candidateCount);
    }

    final selected = await _selection.select(
      CandidateSelectionRequest(goal: goal, candidates: generated.candidates),
    );
    final koogInvoked = _selection.lastKoogInvoked;
    if (selected is! SelectedCandidate) {
      return CandidatePlanNoCandidate(candidateCount: candidateCount);
    }

    final outcome = _governance.govern(
      intent,
      selected.candidate,
      graph: graph,
      shizuku: _shizukuSource == null ? null : await _shizukuSource(),
    );
    if (outcome is! GovernanceApproved) {
      return CandidatePlanGoverned(outcome);
    }

    final call = _adapter.toToolCall(selected.candidate);
    return CandidatePlanResolved(
      call: call,
      candidate: selected.candidate,
      expectation: _goalExpectationFor(selected.candidate),
      selectionMode: koogInvoked
          ? SelectionMode.koog
          : SelectionMode.deterministic,
      koogInvoked: koogInvoked,
      candidateCount: candidateCount,
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
