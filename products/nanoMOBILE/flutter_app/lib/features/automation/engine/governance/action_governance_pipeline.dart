/// ActionGovernancePipeline (A11) — orquesta las decisiones de gobierno.
///
/// Solo coordina: firewall (scope) → critic (calidad/riesgo) → broker
/// (privilegio). NO planifica, NO ejecuta, NO verifica. Koog/NanoFlow/legacy
/// deben pasar por aquí antes de ejecutar; seleccionar un candidato NUNCA es
/// autorización.
library;

import '../planning/candidates/candidate_action.dart';
import '../privilege/shizuku_availability.dart';
import '../system/system_graph.dart';
import 'intent_firewall.dart';
import 'intent_spec.dart';
import 'pre_action_critic.dart';
import 'privilege_broker.dart';

sealed class GovernanceOutcome {
  const GovernanceOutcome();
}

class GovernanceApproved extends GovernanceOutcome {
  final PrivilegeTier tier;
  const GovernanceApproved(this.tier);
}

class GovernanceDenied extends GovernanceOutcome {
  final GovernanceReason reason;
  const GovernanceDenied(this.reason);
}

class GovernanceConfirmation extends GovernanceOutcome {
  final GovernanceReason reason;
  const GovernanceConfirmation(this.reason);
}

class GovernanceMoreEvidence extends GovernanceOutcome {
  final GovernanceReason reason;
  const GovernanceMoreEvidence(this.reason);
}

class GovernanceClarification extends GovernanceOutcome {
  final GovernanceReason reason;
  const GovernanceClarification(this.reason);
}

class ActionGovernancePipeline {
  const ActionGovernancePipeline({
    required this.firewall,
    required this.critic,
    required this.broker,
  });

  final IntentFirewall firewall;
  final PreActionCritic critic;
  final PrivilegeBroker broker;

  GovernanceOutcome govern(
    IntentSpec intent,
    CandidateAction candidate, {
    SystemGraph? graph,
    ShizukuAvailability? shizuku,
  }) {
    // 1. Firewall (scope de intención).
    final fw = firewall.check(intent, candidate);
    if (fw is FirewallDenied) return GovernanceDenied(fw.reason);
    if (fw is FirewallClarification) {
      return GovernanceClarification(fw.reason);
    }

    // 2. Critic (calidad/riesgo).
    final decision = critic.review(intent, candidate, graph: graph);
    if (decision is RejectedAction) return GovernanceDenied(decision.reason);
    if (decision is MoreEvidenceRequiredAction) {
      return GovernanceMoreEvidence(decision.reason);
    }
    if (decision is ConfirmationRequiredAction) {
      return GovernanceConfirmation(decision.reason);
    }

    // 3. Broker (privilegio técnico).
    final priv = broker.resolve(candidate, graph: graph, shizuku: shizuku);
    if (!priv.available) {
      return const GovernanceDenied(GovernanceReason.privilegeUnavailable);
    }

    return GovernanceApproved(priv.tier);
  }
}
