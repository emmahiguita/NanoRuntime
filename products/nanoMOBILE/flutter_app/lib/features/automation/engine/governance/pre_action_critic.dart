/// PreActionCritic (A11) — chequeo determinista de calidad/riesgo ANTES de
/// ejecutar. Rules-first: sin LLM normalmente. Un DENY determinista no puede
/// ser convertido en ALLOW por el modelo.
library;

import '../planning/candidates/candidate_action.dart';
import '../system/capability_availability.dart';
import '../system/system_graph.dart';
import 'intent_firewall.dart' show effectOfTool;
import 'intent_spec.dart';

sealed class PreActionDecision {
  const PreActionDecision();
}

class ApprovedAction extends PreActionDecision {
  const ApprovedAction();
}

class RejectedAction extends PreActionDecision {
  final GovernanceReason reason;
  const RejectedAction(this.reason);
}

class ConfirmationRequiredAction extends PreActionDecision {
  final GovernanceReason reason;
  const ConfirmationRequiredAction(this.reason);
}

class MoreEvidenceRequiredAction extends PreActionDecision {
  final GovernanceReason reason;
  const MoreEvidenceRequiredAction(this.reason);
}

class PreActionCritic {
  const PreActionCritic();

  PreActionDecision review(
    IntentSpec intent,
    CandidateAction candidate, {
    SystemGraph? graph,
  }) {
    // 1. Capability factualmente disponible.
    for (final cap in candidate.requiredCapabilities) {
      final avail = graph?.availabilityOf(cap);
      if (avail != null && !avail.isAvailable) {
        return RejectedAction(
          avail.state == CapabilityAvailabilityKind.requiresAccessibility ||
                  avail.state ==
                      CapabilityAvailabilityKind.requiresNotificationAccess ||
                  avail.state ==
                      CapabilityAvailabilityKind.requiresUserEnablement
              ? GovernanceReason.requiresEnablement
              : GovernanceReason.capabilityUnavailable,
        );
      }
    }

    // 2. Grounding insuficiente → más evidencia.
    if (candidate.groundingConfidence < 0.6) {
      return const MoreEvidenceRequiredAction(
        GovernanceReason.insufficientEvidence,
      );
    }

    // 3. Efecto externo irreversible → confirmación.
    final external = _isExternalEffect(effectOfTool(candidate.tool));
    if (external && !candidate.reversible) {
      return const ConfirmationRequiredAction(GovernanceReason.irreversible);
    }
    // 4. Efecto externo (en general) → confirmación.
    if (external) {
      return const ConfirmationRequiredAction(GovernanceReason.highRisk);
    }

    return const ApprovedAction();
  }

  bool _isExternalEffect(ActionEffect? effect) => switch (effect) {
    ActionEffect.sendExternalMessage ||
    ActionEffect.publishExternalContent ||
    ActionEffect.deleteFile ||
    ActionEffect.installPackage ||
    ActionEffect.manageApplication ||
    ActionEffect.changePermission ||
    ActionEffect.privilegedSystemOperation ||
    ActionEffect.changeSystemState => true,
    _ => false,
  };
}
