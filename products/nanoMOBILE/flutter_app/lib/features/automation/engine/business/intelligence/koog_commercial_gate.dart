// koog_commercial_gate.dart
//
// QUÉ HACE:
// Conecta el supervisor KOOG con la inteligencia comercial estructurada y el
// reporte de cobertura histórica para gobernar si un mensaje comercial se
// responde automáticamente, pide más observación o escala a un humano.
//
// CÓMO FUNCIONA:
// 1. Reglas deterministas de seguridad (coste $0, latencia < 1ms):
//    - Si el cliente pide un humano (`humanHandoffRequested`) -> [KoogNeedConfirmation].
//    - Si es un lead `hot` con objeciones activas -> [KoogNeedConfirmation].
//    - Si solo hay 1 candidato y cobertura continua -> [KoogAct] inmediato.
// 2. Desambiguación asistida por [KoogSupervisor] cuando existen múltiples
//    candidatos o huecos históricos parciales, aplicando [KoogShadowObserver] opcional.
//
// POR QUÉ:
// Cierra la brecha de KOOG en el inbox comercial: ningún bot responde a ciegas
// ante objeciones críticas de venta ni ignora solicitudes de asesor humano.

library;

import '../../messaging/conversation_coverage_analyzer.dart';
import '../../planning/candidates/candidate_action.dart';
import '../../planning/koog_shadow.dart';
import '../../planning/koog_supervisor.dart';
import 'conversation_intelligence_profile.dart';

final class KoogCommercialGate {
  final KoogSupervisor? supervisor;
  final KoogShadowObserver? shadowObserver;

  const KoogCommercialGate({
    this.supervisor,
    this.shadowObserver,
  });

  /// Evalúa la decisión de supervisión comercial combinando reglas y KOOG.
  Future<KoogSupervisionDecision> evaluate({
    required String goal,
    required ConversationIntelligenceProfile intelligence,
    required ConversationCoverageReport coverage,
    required List<CandidateAction> candidates,
    String? memorySummary,
  }) async {
    if (intelligence.humanHandoffRequested) {
      return const KoogNeedConfirmation(
        'El cliente solicitó ser atendido por un asesor humano',
      );
    }

    if (intelligence.leadQuality == LeadQuality.hot &&
        intelligence.objections.isNotEmpty) {
      return KoogNeedConfirmation(
        'Lead caliente con objeciones (${intelligence.objections.join(', ')}); '
        'requiere validación humana antes de enviar',
      );
    }

    if (candidates.isEmpty) {
      return coverage.hasKnownGaps
          ? const KoogNeedObservation(
              'Sin candidatos y con huecos históricos en la conversación',
            )
          : const KoogAbstain('No hay candidatos disponibles para este turno');
    }

    final views = candidates
        .map(KoogCandidateView.fromCandidate)
        .toList(growable: false);

    final context = KoogSupervisionContext(
      goal: goal,
      situationSummary:
          'lead=${intelligence.leadQuality.name}, '
          'urgente=${intelligence.urgent}, '
          '${coverage.toPromptSummary()}',
      candidates: views,
      memorySummary: memorySummary,
    );

    if (candidates.length == 1 && !coverage.hasKnownGaps) {
      final singleId = candidates.first.id;
      final shadow = shadowObserver;
      if (shadow != null && shadow.enabled) {
        await shadow.observe(
          context: context,
          authoritative: AuthoritativeOutcome.selectedCandidate,
          authoritativeCandidateId: singleId.value,
        );
      }
      return KoogAct(singleId);
    }

    final activeSupervisor = supervisor;
    if (activeSupervisor == null) {
      return coverage.hasKnownGaps
          ? const KoogNeedObservation(
              'Ambigüedad con cobertura histórica parcial y sin supervisor activo',
            )
          : const KoogAbstain('Múltiples candidatos sin supervisor KOOG activo');
    }

    return activeSupervisor.decide(context);
  }
}
