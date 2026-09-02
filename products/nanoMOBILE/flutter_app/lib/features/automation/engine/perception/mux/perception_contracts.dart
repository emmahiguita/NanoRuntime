/// Contratos de percepción (A8) — request, policy, budget, evidence, result.
library;

import '../nano_snapshot.dart' show NanoBounds;
import '../semantic/semantic_role.dart';

/// Solicitud mínima de percepción (sin contextos gigantes, sin prompt LLM).
class PerceptionRequest {
  final String targetConcept;
  final SemanticRole? expectedRole;
  final String? packageName;
  final double minimumConfidence;

  /// Región objetivo (targeted OCR). null = sin región (fuente decide).
  final NanoBounds? region;

  const PerceptionRequest({
    required this.targetConcept,
    this.expectedRole,
    this.packageName,
    this.minimumConfidence = 0.5,
    this.region,
  });

  PerceptionRequest withRegion(NanoBounds? bounds) => PerceptionRequest(
    targetConcept: targetConcept,
    expectedRole: expectedRole,
    packageName: packageName,
    minimumConfidence: minimumConfidence,
    region: bounds,
  );

  PerceptionRequest withMinimumConfidence(double confidence) =>
      PerceptionRequest(
        targetConcept: targetConcept,
        expectedRole: expectedRole,
        packageName: packageName,
        minimumConfidence: confidence,
        region: region,
      );
}

/// Política de observación: qué fuentes reales están permitidas para esta
/// request. Autorizar una fuente no fuerza su uso: el mux exige insuficiencia
/// de las fuentes anteriores y respeta el presupuesto.
class ObservationPolicy {
  final bool allowMemory;
  final bool allowAccessibility;
  final bool allowOcr;
  final bool allowVision;
  final bool allowFullScreenVision;
  final double minimumConfidence;

  const ObservationPolicy({
    this.allowMemory = true,
    this.allowAccessibility = true,
    this.allowOcr = true,
    this.allowVision = false,
    this.allowFullScreenVision = false,
    this.minimumConfidence = 0.5,
  });
}

/// Presupuesto de percepción (filosofía Nano: coste acotado).
class PerceptionBudget {
  final int maxAccessibilityReads;
  final int maxOcrCalls;
  final int maxVisionCalls;
  final int maxFullScreenVisionCalls;

  const PerceptionBudget({
    this.maxAccessibilityReads = 2,
    this.maxOcrCalls = 1,
    this.maxVisionCalls = 1,
    this.maxFullScreenVisionCalls = 0,
  });
}

/// Proveniencia de una evidencia de percepción. NUNCA `llm`.
enum PerceptionEvidenceSource { objectMemory, accessibility, ocr, vision }

/// Evidencia tipada de una observación (no un Map genérico).
class PerceptionEvidence {
  final PerceptionEvidenceSource source;
  final double confidence;
  final String reference;
  final String? objectId;

  const PerceptionEvidence({
    required this.source,
    required this.confidence,
    required this.reference,
    this.objectId,
  });
}
