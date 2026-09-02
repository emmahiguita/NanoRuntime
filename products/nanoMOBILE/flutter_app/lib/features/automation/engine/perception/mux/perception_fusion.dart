/// PerceptionFusionEngine (A9) — fusiona evidencia Accessibility + OCR.
///
/// Caso clave: Accessibility conoce un objeto (bounds X) pero sin label; OCR
/// reconoce "Enviar" en bounds≈X → evidencia combinada [accessibility, ocr].
/// NO inventa role (el objeto accesible conserva su role factual).
library;

import '../semantic/nano_ui_object.dart';
import 'ocr_contracts.dart';
import 'perception_contracts.dart';
import 'perception_result.dart';
import 'vision_contracts.dart';

class PerceptionFusionEngine {
  const PerceptionFusionEngine();

  /// Combina confianzas independientes: 1-(1-a)(1-b). Crece con cada fuente y
  /// NUNCA degrada la evidencia estructurada fuerte con una débil (invariante
  /// AUT-VIS-05: STRONG STRUCTURED EVIDENCE OUTRANKS WEAK PROBABILISTIC).
  static double combine(double a, double b) => 1 - (1 - a) * (1 - b);

  /// Fusiona objeto accesible + observación OCR compatible (bounds overlap).
  PerceptionResolved fuse(NanoUiObject accObject, OcrObservation ocr) {
    return PerceptionResolved(
      object: accObject,
      confidence: combine(accObject.confidence, ocr.confidence),
      evidence: [
        PerceptionEvidence(
          source: PerceptionEvidenceSource.accessibility,
          reference: accObject.id,
          confidence: accObject.confidence,
        ),
        PerceptionEvidence(
          source: PerceptionEvidenceSource.ocr,
          reference: ocr.text,
          confidence: ocr.confidence,
        ),
      ],
    );
  }

  /// Fusiona accessibility + OCR + Vision (evidencia triple). El role lo aporta
  /// Accessibility (factual); Vision solo añade concepto visual. No inventa.
  PerceptionResolved fuseWithVision(
    NanoUiObject accObject,
    OcrObservation ocr,
    VisionObject vision,
  ) {
    return PerceptionResolved(
      object: accObject,
      confidence: combine(
        combine(accObject.confidence, ocr.confidence),
        vision.confidence,
      ),
      evidence: [
        PerceptionEvidence(
          source: PerceptionEvidenceSource.accessibility,
          reference: accObject.id,
          confidence: accObject.confidence,
        ),
        PerceptionEvidence(
          source: PerceptionEvidenceSource.ocr,
          reference: ocr.text,
          confidence: ocr.confidence,
        ),
        PerceptionEvidence(
          source: PerceptionEvidenceSource.vision,
          reference: vision.label,
          confidence: vision.confidence,
        ),
      ],
    );
  }

  /// ¿El objeto y la observación OCR se refieren a la misma región?
  bool overlaps(NanoUiObject obj, OcrObservation ocr) =>
      obj.bounds.xOverlapRatio(ocr.bounds) > 0.5 &&
      obj.bounds.distanceTo(ocr.bounds) <
          (obj.bounds.height + ocr.bounds.height);
}
