/// KoogShadowObserver (WA-KOOG-10) — comparación en paralelo SIN autoridad.
///
/// Corre la decisión del [KoogSupervisor] junto al resultado autoritativo
/// (determinista) del pipeline y reporta desacuerdos vía callback. NUNCA
/// altera la ejecución: el shadow observa y compara, no decide.
///
/// ROLLOUT (plan WA-KOOG-10):
///  1. `enabled: false` (default, costo cero: no llama al LLM) mientras el
///     pipeline determinista sigue siendo la única autoridad.
///  2. Activación explícita en producción para medir desacuerdos.
///  3. Autoridad de selección SOLO después de que los desacuerdos demuestren
///     integridad de la frontera de candidatos (WA-PHYS-11).
library;

import 'candidates/candidate_action.dart' show CandidateId;
import 'koog_supervisor.dart';

/// Resultado autoritativo del ciclo (lo que el pipeline ya decidió).
enum AuthoritativeOutcome { selectedCandidate, noCandidate, ambiguous }

/// Desacuerdo observado entre Koog y el camino autoritativo. Informativo:
/// no bloquea, no reintenta, no cambia el resultado del ciclo.
final class KoogShadowDisagreement {
  const KoogShadowDisagreement({
    required this.contextGoal,
    required this.authoritative,
    required this.authoritativeCandidateId,
    required this.koogDecision,
  });

  final String contextGoal;
  final AuthoritativeOutcome authoritative;
  final String? authoritativeCandidateId;
  final KoogSupervisionDecision koogDecision;
}

/// Observador shadow: compara y reporta. SRP: no ejecuta, no decide.
final class KoogShadowObserver {
  KoogShadowObserver({
    required KoogSupervisor supervisor,
    void Function(KoogShadowDisagreement)? onDisagreement,
    bool enabled = false,
  }) : _supervisor = supervisor,
       _onDisagreement = onDisagreement,
       _enabled = enabled;

  final KoogSupervisor _supervisor;
  final void Function(KoogShadowDisagreement)? _onDisagreement;
  final bool _enabled;

  bool get enabled => _enabled;

  /// Compara la decisión Koog con el resultado autoritativo. Deshabilitado →
  /// retorna sin llamar al supervisor (costo cero). Un fallo del LLM es
  /// silencioso para el shadow (nunca interrumpe el ciclo autoritativo).
  Future<void> observe({
    required KoogSupervisionContext context,
    required AuthoritativeOutcome authoritative,
    String? authoritativeCandidateId,
  }) async {
    if (!_enabled) return;
    final KoogSupervisionDecision decision;
    try {
      decision = await _supervisor.decide(context);
    } on Object {
      return;
    }
    if (_agrees(decision, authoritative, authoritativeCandidateId)) return;
    _onDisagreement?.call(
      KoogShadowDisagreement(
        contextGoal: context.goal,
        authoritative: authoritative,
        authoritativeCandidateId: authoritativeCandidateId,
        koogDecision: decision,
      ),
    );
  }

  /// Acuerdo = Koog actúa sobre el MISMO candidato seleccionado, o Koog se
  /// abstiene/pide evidencia/confirmación cuando no hubo selección concreta.
  /// Completed/Failed nunca coinciden con el pipeline determinista (que no
  /// emite esas señales): se reportan como desacuerdo.
  bool _agrees(
    KoogSupervisionDecision decision,
    AuthoritativeOutcome authoritative,
    String? authoritativeCandidateId,
  ) {
    if (decision is KoogAct) {
      return authoritative == AuthoritativeOutcome.selectedCandidate &&
          decision.candidateId.value == authoritativeCandidateId;
    }
    if (decision is KoogAbstain ||
        decision is KoogNeedObservation ||
        decision is KoogNeedConfirmation) {
      return authoritative != AuthoritativeOutcome.selectedCandidate;
    }
    return false;
  }
}
