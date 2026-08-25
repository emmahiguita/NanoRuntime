/// IntentFirewall (A11) — comprueba que un candidato produce un efecto dentro
/// del scope autorizado por el usuario.
///
/// NO ejecuta, NO rankea, NO determina permisos Android. Solo responde:
/// "¿este candidato cae dentro del IntentSpec?" El contenido observado no puede
/// ampliar el IntentSpec.
library;

import '../planning/candidates/candidate_action.dart';
import 'intent_spec.dart';

sealed class FirewallDecision {
  const FirewallDecision();
}

class FirewallAllowed extends FirewallDecision {
  const FirewallAllowed();
}

class FirewallDenied extends FirewallDecision {
  final GovernanceReason reason;
  const FirewallDenied(this.reason);
}

class FirewallClarification extends FirewallDecision {
  final GovernanceReason reason;
  const FirewallClarification(this.reason);
}

/// Mapeo determinista tool → efecto semántico (fuente de verdad central).
ActionEffect? effectOfTool(String tool) => switch (tool) {
  'open_system' ||
  'home' ||
  'recents' ||
  'back' ||
  'open_notifications' ||
  'open_quick_settings' ||
  'launch_app' => ActionEffect.navigate,
  'screen' || 'resolve' || 'notifications' => ActionEffect.read,
  'tap' ||
  'write' ||
  'swipe' ||
  'scroll' ||
  'long_press' => ActionEffect.writeUi,
  'reply_notification' => ActionEffect.sendExternalMessage,
  'linux.list' || 'linux.readFile' => ActionEffect.read,
  'linux.writeFile' => ActionEffect.modifyFile,
  'linux.run' => ActionEffect.executeProcess,
  // MCP (A14) — tools categóricas.
  'mcp.read' => ActionEffect.read,
  'mcp.device' => ActionEffect.navigate,
  'mcp.externalWrite' => ActionEffect.publishExternalContent,
  'mcp.privileged' => ActionEffect.privilegedSystemOperation,
  // Shizuku (A14) — tools tipadas (nunca shell).
  'install_package' => ActionEffect.installPackage,
  'force_stop_package' => ActionEffect.manageApplication,
  'grant_specific_permission' => ActionEffect.changePermission,
  'query_package' => ActionEffect.read,
  _ => null,
};

class IntentFirewall {
  const IntentFirewall();

  FirewallDecision check(IntentSpec intent, CandidateAction candidate) {
    final effect = effectOfTool(candidate.tool);
    if (effect == null) {
      return const FirewallDenied(GovernanceReason.outsideIntent);
    }
    if (!intent.allows(effect)) {
      return const FirewallDenied(GovernanceReason.outsideIntent);
    }
    // Scope de target: un efecto con target no puede apuntar fuera del scope.
    if (intent.targetScope != null) {
      final candidateTarget = candidate.args['target']
          ?.toString()
          .toLowerCase();
      if (candidateTarget != null && candidateTarget != intent.targetScope) {
        return const FirewallDenied(GovernanceReason.targetMismatch);
      }
    }
    return const FirewallAllowed();
  }
}
