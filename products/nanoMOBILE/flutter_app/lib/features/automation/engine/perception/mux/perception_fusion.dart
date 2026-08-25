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

class PerceptionFusionEngine {
  const PerceptionFusionEngine();

  /// Fusiona objeto accesible + observación OCR compatible (bounds overlap).
  PerceptionResolved fuse(NanoUiObject accObject, OcrObservation ocr) {
    return PerceptionResolved(
      object: accObject,
      confidence: (accObject.confidence + ocr.confidence) / 2,
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

  /// ¿El objeto y la observación OCR se refieren a la misma región?
  bool overlaps(NanoUiObject obj, OcrObservation ocr) =>
      obj.bounds.xOverlapRatio(ocr.bounds) > 0.5 &&
      obj.bounds.distanceTo(ocr.bounds) <
          (obj.bounds.height + ocr.bounds.height);
}
