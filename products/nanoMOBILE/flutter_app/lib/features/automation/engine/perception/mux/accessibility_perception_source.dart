/// AccessibilityPerceptionSource (A8) — percepción vía Accessibility →
/// ScreenGraph → matching semántico. Sin taps, sin selectores ejecutados, sin
/// LLM. No llama OCR/Vision (eso es A9/A10): devuelve escalado tipado.
library;

import '../semantic/screen_graph.dart';
import 'perception_contracts.dart';
import 'perception_result.dart';
import 'perception_source.dart';
import 'screen_graph_query.dart';

class AccessibilityPerceptionSource implements PerceptionSource {
  AccessibilityPerceptionSource(this._observer);

  final ScreenObserver _observer;

  /// Número de lecturas de snapshot realizadas (para observabilidad/tests).
  int readCount = 0;

  @override
  Future<PerceptionResult> perceive(
    PerceptionRequest request,
    PerceptionBudget budget,
  ) async {
    if (budget.maxAccessibilityReads <= 0) {
      return const PerceptionInsufficient(
        reason: 'Presupuesto de accesibilidad agotado.',
        recommendedSource: PerceptionEvidenceSource.ocr,
      );
    }
    final snapshot = await _observer.snapshot();
    readCount++;
    if (snapshot == null) {
      return const PerceptionUnavailable(
        'Accesibilidad no disponible (snapshot null).',
      );
    }
    if (snapshot.isEmpty) {
      return const PerceptionInsufficient(
        reason: 'Snapshot vacío (sin ventana activa).',
        recommendedSource: PerceptionEvidenceSource.ocr,
      );
    }

    final graph = ScreenGraph.fromSnapshot(snapshot);
    final matches = const ScreenGraphQuery().query(graph, request);
    if (matches.isEmpty) {
      return const PerceptionInsufficient(
        reason: 'Sin coincidencia semántica.',
        recommendedSource: PerceptionEvidenceSource.ocr,
      );
    }

    final best = matches.first;
    if (matches.length > 1 &&
        (best.confidence - matches[1].confidence) < 0.05) {
      return PerceptionAmbiguous(
        candidates: matches.map((m) => m.object).toList(growable: false),
        reason: 'Varios candidatos con confianza similar.',
        evidence: [
          PerceptionEvidence(
            source: PerceptionEvidenceSource.accessibility,
            reference: best.object.id,
            confidence: best.confidence,
          ),
        ],
      );
    }
    if (best.confidence < request.minimumConfidence) {
      return PerceptionInsufficient(
        reason:
            'Confianza insuficiente (${best.confidence} < '
            '${request.minimumConfidence}).',
        recommendedSource: PerceptionEvidenceSource.ocr,
      );
    }
    return PerceptionResolved(
      object: best.object,
      confidence: best.confidence,
      evidence: [
        PerceptionEvidence(
          source: PerceptionEvidenceSource.accessibility,
          reference: best.object.id,
          confidence: best.confidence,
        ),
      ],
    );
  }
}
