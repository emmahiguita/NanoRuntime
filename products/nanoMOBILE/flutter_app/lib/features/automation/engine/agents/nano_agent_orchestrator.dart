/// NanoAgentOrchestrator (A13) — orquesta roles LÓGICOS sobre el pipeline
/// Candidate-First, SIN reemplazar el AutomationCoordinator.
///
/// Un solo modelo/runtime; separación de responsabilidades (planner/perception/
/// executor/critic/verifier/memory), no 6 modelos en RAM. El output es un
/// [AgentResult]; la ejecución real y la verificación siguen aguas abajo
/// (adapter → dispatcher → verifier). No cableado al coordinator en A13.
library;

import '../governance/action_governance_pipeline.dart';
import '../governance/intent_spec_compiler.dart';
import '../planning/candidates/candidate_generator.dart';
import '../planning/candidates/candidate_provider.dart';
import '../planning/candidates/candidate_selection.dart';
import '../planning/candidates/candidate_selection_engine.dart';
import '../planning/candidates/candidate_selector.dart';
import 'agent_role.dart';
import 'agent_types.dart';

class NanoAgentOrchestrator {
  NanoAgentOrchestrator({
    required CandidateActionGenerator generator,
    required CandidateSelectionEngine selection,
    required ActionGovernancePipeline governance,
  }) : _generator = generator,
       _selection = selection,
       _governance = governance;

  final CandidateActionGenerator _generator;
  final CandidateSelectionEngine _selection;
  final ActionGovernancePipeline _governance;

  Future<AgentResult> run(AgentContext context) async {
    // Planner + Perception: generar candidatos grounded (0 LLM si determinista).
    final generated = await _generator.generate(CandidateRequest(context.goal));
    if (generated.candidates.isEmpty) {
      return const AgentResult(role: AgentRole.planner, value: null);
    }

    // Executor: seleccionar (ranker determinista; Koog solo si ambigüedad).
    final selected = await _selection.select(
      CandidateSelectionRequest(
        goal: context.goal,
        candidates: generated.candidates,
      ),
    );
    if (selected is! SelectedCandidate) {
      return AgentResult(role: AgentRole.executor, value: selected);
    }

    // Critic: governance (firewall + critic + broker) sobre la intención.
    final intent =
        context.intent ?? const IntentSpecCompiler().compile(context.goal);
    final outcome = _governance.govern(intent, selected.candidate);
    if (outcome is GovernanceApproved) {
      return AgentResult(role: AgentRole.executor, value: selected.candidate);
    }
    return AgentResult(role: AgentRole.critic, value: outcome);
  }
}
