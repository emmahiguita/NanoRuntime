/// CandidateRanker (A6) — ranking determinista y transparente.
///
/// Puro: sin IO, sin modelo, sin plataforma, sin mutación. Mismo input → mismo
/// output. Sin LLM, sin visión, sin OCR. La ambigüedad se preserva (nunca
/// auto-elegir entre candidatos materialmente distintos con margen insuficiente).
library;

import '../../execution/action_verifier.dart' show ActionExpectation;
import '../../execution/tool_registry.dart' show ToolRisk;
import 'candidate_action.dart';
import 'candidate_selection.dart';
import 'candidate_set.dart';

/// Score desglosado (no un `double` misterioso): total + factores.
class CandidateScore {
  final double total;
  final Map<String, double> factors;
  const CandidateScore(this.total, this.factors);
}

class CandidateRanker {
  CandidateRanker({this.ambiguityMargin = 0.10});

  /// Margen bajo el cual dos candidatos materialmente distintos se declaran
  /// ambiguos en lugar de auto-elegir el top.
  final double ambiguityMargin;

  CandidateSelection rank(CandidateSet set) {
    if (set.isEmpty) return const NoCandidate('Sin candidatos grounded.');
    final scored = <(CandidateAction, CandidateScore)>[
      for (final c in set.items) (c, _score(c)),
    ]..sort((a, b) => b.$2.total.compareTo(a.$2.total));

    final top = scored.first;
    if (scored.length == 1) return SelectedCandidate(top.$1);

    final second = scored[1];
    final margin = top.$2.total - second.$2.total;
    if (margin < ambiguityMargin && _materiallyDifferent(top.$1, second.$1)) {
      return AmbiguousCandidates(
        [top.$1, second.$1],
        'Margen de score insuficiente entre candidatos materialmente distintos.',
      );
    }
    return SelectedCandidate(top.$1);
  }

  /// Score determinista y transparente. Pesos documentados (futuro benchmark
  /// podrá calibrarlos):
  /// - groundingConfidence: 0.50 (la validez semántica/grounding va primero)
  /// - expectedSuccess: 0.15 (solo si se conoce; desconocido = excluido, 0.0)
  /// - channel preference: 0.15 (nanoFlow > deterministic > androidApi > …)
  /// - reversible bonus: 0.05
  /// - risk penalty: negativo (none 0, read -0.01, device -0.03, externalWrite -0.08)
  /// - latency penalty: negativo, -(ms/10000) clamped [0,1]
  /// - verification strength: 0.05 (postcondition fuerte > débil)
  CandidateScore _score(CandidateAction c) {
    final grounding = c.groundingConfidence * 0.50;
    final success = c.expectedSuccess == null ? 0.0 : c.expectedSuccess! * 0.15;
    final channel = _channelWeight(c.channel) * 0.15;
    final reversible = c.reversible ? 0.05 : 0.0;
    final risk = _riskPenalty(c.risk);
    final latency = c.expectedLatency == null
        ? 0.0
        : _latencyPenalty(c.expectedLatency!);
    final verification = _verificationStrength(c.expectation) * 0.05;
    final total =
        (grounding +
                success +
                channel +
                reversible +
                risk +
                latency +
                verification)
            .clamp(0.0, 1.0);
    return CandidateScore(total, {
      'grounding': grounding,
      'success': success,
      'channel': channel,
      'reversible': reversible,
      'risk': risk,
      'latency': latency,
      'verification': verification,
    });
  }

  /// Preferencia de canal (filosofía Nano: mínimo inteligencia necesaria).
  double _channelWeight(ActionChannel c) => switch (c) {
    ActionChannel.nanoFlow => 1.0,
    ActionChannel.deterministic => 0.9,
    ActionChannel.androidApi => 0.85,
    ActionChannel.androidIntent => 0.8,
    ActionChannel.notification => 0.7,
    ActionChannel.structuredTool => 0.65,
    ActionChannel.linux => 0.6,
    ActionChannel.accessibility => 0.5,
    ActionChannel.mcp => 0.4,
    ActionChannel.shizuku => 0.4,
    ActionChannel.deviceOwner => 0.4,
    ActionChannel.rootLab => 0.4,
    ActionChannel.ocr => 0.35,
    ActionChannel.vision => 0.25,
    ActionChannel.coordinates => 0.1,
  };

  double _riskPenalty(ToolRisk r) => switch (r) {
    ToolRisk.none => 0.0,
    ToolRisk.read => -0.01,
    ToolRisk.device => -0.03,
    ToolRisk.externalWrite => -0.08,
  };

  double _latencyPenalty(Duration d) =>
      -(d.inMilliseconds / 10000.0).clamp(0.0, 1.0);

  /// Fuerza de verificación de la postcondición (más fuerte → mejor).
  double _verificationStrength(ActionExpectation? e) {
    if (e == null) return 0.0;
    if (e.expectedPackage != null) return 1.0;
    if (e.expectedText != null || e.mustAppear != null) return 0.8;
    if (e.mustChangeSnapshot) return 0.5;
    return 0.3;
  }

  /// Distintos si apuntan a semántica/target distinto (para la ambigüedad).
  bool _materiallyDifferent(CandidateAction a, CandidateAction b) =>
      a.semanticAction != b.semanticAction ||
      candidatePayloadKey(a) != candidatePayloadKey(b);
}
