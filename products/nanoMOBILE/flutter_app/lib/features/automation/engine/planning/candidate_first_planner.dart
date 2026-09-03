/// CandidateFirstPlanner (A13.5) — planificador Candidate-First de producción.
///
/// Encapsula el pipeline probado: generator → selection (Koog si ambigüedad) →
/// governance (firewall/critic/broker) → adapter → ToolCall. A15.7: el
/// SystemGraph REAL (async, con accessibility/notification/Linux) se carga lazy
/// y alimenta tanto el SystemIntentCandidateProvider como el governance (broker/
/// critic validan capabilities factuales). Devuelve resultado tipado; NO
/// ejecuta, NO verifica, NO entrena memoria.
library;

import 'dart:async' show unawaited;

import '../execution/agent_tool_dispatcher.dart' show ToolCall;
import '../execution/goal_verifier.dart' show GoalExpectation;
import '../governance/action_governance_pipeline.dart';
import '../governance/rule_execution_authority.dart'
    show RuleExecutionAuthority;
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
import 'koog_shadow.dart' show AuthoritativeOutcome, KoogShadowObserver;
import 'koog_supervisor.dart' show KoogCandidateView, KoogSupervisionContext;

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
    KoogShadowObserver? koogShadow,
  }) : _generatorBuilder = generatorBuilder,
       _selection = selection,
       _governance = governance,
       _adapter = adapter,
       _getGraph = getGraph,
       _shizukuSource = shizukuSource,
       _koogShadow = koogShadow;

  final CandidateActionGenerator Function(SystemGraph) _generatorBuilder;
  final CandidateSelectionEngine _selection;
  final ActionGovernancePipeline _governance;
  final CandidateToolCallAdapter _adapter;
  final Future<SystemGraph> Function() _getGraph;

  /// Fuente opcional de disponibilidad FACTUAL de Shizuku (A14.3). Inyectada
  /// solo en producción; ausente en tests → el broker la trata como no
  /// disponible (conservador, sin ejecución privilegiada).
  final Future<ShizukuAvailability> Function()? _shizukuSource;

  /// Observador shadow de Koog (WA-KOOG-10). Opcional y deshabilitado por
  /// defecto: observa y compara la decisión Koog contra el resultado
  /// autoritativo SIN alterarlo nunca. Null en tests del pipeline previo.
  final KoogShadowObserver? _koogShadow;

  Future<CandidatePlanResult> plan(
    String goal, {
    RuleExecutionAuthority? authority,
  }) async {
    final intent = const IntentSpecCompiler().compile(goal);

    // A15.7: SystemGraph real (async) para availability + governance.
    final graph = await _getGraph();

    final generated = await _generatorBuilder(
      graph,
    ).generate(CandidateRequest(goal));
    final candidateCount = generated.candidates.length;
    if (generated.candidates.isEmpty) {
      unawaited(
        _shadowObserve(
          goal: goal,
          graph: graph,
          candidates: const [],
          authoritative: AuthoritativeOutcome.noCandidate,
        ),
      );
      return CandidatePlanNoCandidate(candidateCount: candidateCount);
    }

    final selected = await _selection.select(
      CandidateSelectionRequest(goal: goal, candidates: generated.candidates),
    );
    final koogInvoked = _selection.lastKoogInvoked;
    if (selected is! SelectedCandidate) {
      unawaited(
        _shadowObserve(
          goal: goal,
          graph: graph,
          candidates: generated.candidates.items,
          authoritative: AuthoritativeOutcome.noCandidate,
        ),
      );
      return CandidatePlanNoCandidate(candidateCount: candidateCount);
    }

    // WA-AUTH-04 (verificado en físico): la autoridad standing de una regla se
    // evalúa ANTES del govern. Sin esto, todo reply irreversible volvía
    // GovernanceConfirmation('irreversible') y la autoridad — que solo vivía
    // en runToolGuarded — jamás se consultaba (reglas nunca respondían solas).
    // La autoridad solo cubre la acción EXACTA (tool + texto fijo de la regla);
    // cualquier otro candidato conserva la gobernanza completa.
    final standingGranted =
        authority != null &&
        authority.satisfiesCall(
          selected.candidate.tool,
          '${selected.candidate.args['text'] ?? ''}',
        );
    if (!standingGranted) {
      final outcome = _governance.govern(
        intent,
        selected.candidate,
        graph: graph,
        shizuku: _shizukuSource == null ? null : await _shizukuSource(),
      );
      if (outcome is! GovernanceApproved) {
        return CandidatePlanGoverned(outcome);
      }
    }

    final call = _adapter.toToolCall(selected.candidate);
    unawaited(
      _shadowObserve(
        goal: goal,
        graph: graph,
        candidates: generated.candidates.items,
        authoritative: AuthoritativeOutcome.selectedCandidate,
        selectedCandidateId: selected.candidate.id.value,
      ),
    );
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

  /// WA-KOOG-10: observación shadow post-plan. Nunca altera el resultado
  /// autoritativo (el observer solo compara y reporta); el planner NO espera
  /// la inferencia shadow (fire-and-forget, costo cero con observer off).
  Future<void> _shadowObserve({
    required String goal,
    required SystemGraph graph,
    required List<CandidateAction> candidates,
    required AuthoritativeOutcome authoritative,
    String? selectedCandidateId,
  }) async {
    final shadow = _koogShadow;
    if (shadow == null) return;
    await shadow.observe(
      context: KoogSupervisionContext(
        goal: goal,
        situationSummary: _systemGraphSummary(graph),
        candidates: candidates
            .map(KoogCandidateView.fromCandidate)
            .toList(growable: false),
      ),
      authoritative: authoritative,
      authoritativeCandidateId: selectedCandidateId,
    );
  }

  /// Resumen factual mínimo del dispositivo para el contexto de supervisión.
  /// Solo hechos del SystemGraph (apps + capabilities); sin interpretación.
  String _systemGraphSummary(SystemGraph graph) {
    final caps = graph.capabilities.entries
        .where((e) => e.value.isAvailable)
        .map((e) => e.key.name)
        .join(', ');
    return 'apps instaladas: ${graph.apps.length}; '
        'capabilities disponibles: $caps';
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
