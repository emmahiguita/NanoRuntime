/// Contratos de percepción (A8) — request, policy, budget, evidence, result.
library;

import '../semantic/semantic_role.dart';

/// Solicitud mínima de percepción (sin contextos gigantes, sin prompt LLM).
class PerceptionRequest {
  final String targetConcept;
  final SemanticRole? expectedRole;
  final String? packageName;
  final double minimumConfidence;

  const PerceptionRequest({
    required this.targetConcept,
    this.expectedRole,
    this.packageName,
    this.minimumConfidence = 0.5,
  });
}

/// Política de observación: qué fuentes están permitidas para esta request.
/// OCR/Vision existen como flags pero NO tienen fuente real en A8.
class ObservationPolicy {
  final bool allowMemory;
  final bool allowAccessibility;
  final bool allowOcr;
  final bool allowVision;
  final double minimumConfidence;

  const ObservationPolicy({
    this.allowMemory = true,
    this.allowAccessibility = true,
    this.allowOcr = false,
    this.allowVision = false,
    this.minimumConfidence = 0.5,
  });
}

/// Presupuesto de percepción (filosofía Nano: coste acotado).
/// A8 solo consume accesibilidad; OCR/Vision se consumirán en A9/A10.
class PerceptionBudget {
  final int maxAccessibilityReads;
  final int maxOcrCalls;
  final int maxVisionCalls;

  const PerceptionBudget({
    this.maxAccessibilityReads = 2,
    this.maxOcrCalls = 0,
    this.maxVisionCalls = 0,
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
