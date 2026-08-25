/// OcrPerceptionSource (A9) — lectura visual de texto como fallback.
///
/// Captura (crop o full-screen) → OCR → matching → PerceptionResult. NO ejecuta
/// taps, NO produce ToolCall ni CandidateAction. El texto OCR es OBSERVACIÓN
/// NO CONFIABLE.
library;

import '../semantic/nano_ui_object.dart';
import '../semantic/semantic_role.dart';
import 'ocr_contracts.dart';
import 'perception_contracts.dart';
import 'perception_result.dart';
import 'perception_source.dart';

class OcrPerceptionSource implements PerceptionSource {
  OcrPerceptionSource(this._imageProvider, this._backend);

  final ScreenImageProvider _imageProvider;
  final OcrBackend _backend;

  int ocrCalls = 0;
  int targetedCalls = 0;
  int fullScreenCalls = 0;

  @override
  Future<PerceptionResult> perceive(
    PerceptionRequest request,
    PerceptionBudget budget,
  ) async {
    if (budget.maxOcrCalls <= 0) {
      return const PerceptionInsufficient(
        reason: 'Presupuesto OCR agotado.',
        recommendedSource: PerceptionEvidenceSource.vision,
      );
    }
    final region = request.region;
    final fullScreen = region == null;
    final img = await _imageProvider.capture(region: region);
    if (!img.captured || img.image == null) {
      return PerceptionUnavailable(
        img.error ?? 'Captura de pantalla no disponible.',
      );
    }
    ocrCalls++;
    if (fullScreen) {
      fullScreenCalls++;
    } else {
      targetedCalls++;
    }

    final ocr = await _backend.recognize(OcrRequest(image: img.image!));
    if (ocr.observations.isEmpty) {
      return const PerceptionInsufficient(
        reason: 'OCR sin texto reconocido.',
        recommendedSource: PerceptionEvidenceSource.vision,
      );
    }

    final concept = request.targetConcept.trim().toLowerCase();
    final matches = ocr.observations.where((o) {
      final t = o.text.trim().toLowerCase();
      return t.isNotEmpty && (t.contains(concept) || concept.contains(t));
    }).toList();
    matches.sort((a, b) => b.confidence.compareTo(a.confidence));
    if (matches.isEmpty) {
      return const PerceptionInsufficient(
        reason: 'OCR no coincide con el concepto.',
        recommendedSource: PerceptionEvidenceSource.vision,
      );
    }

    final best = matches.first;
    // Objeto virtual: bounds + texto OCR. Los bounds son aproximados (relativos
    // a la imagen capturada); el role NO se inventa (unknown salvo request).
    final virtual = NanoUiObject(
      id: 'ocr:${best.bounds.centerX}:${best.bounds.centerY}',
      role: request.expectedRole ?? SemanticRole.unknown,
      label: best.text,
      text: best.text,
      description: '',
      bounds: best.bounds,
      enabled: true,
      visible: true,
      clickable: false,
      editable: false,
      scrollable: false,
      checked: false,
      focusable: false,
      focused: false,
      nativeClass: '',
      resourceId: '',
      parentId: null,
      confidence: best.confidence,
      evidence: const [SemanticEvidenceSource.textHeuristic],
      sourceIndex: -1,
    );
    return PerceptionResolved(
      object: virtual,
      confidence: best.confidence,
      evidence: [
        PerceptionEvidence(
          source: PerceptionEvidenceSource.ocr,
          reference: best.text,
          confidence: best.confidence,
        ),
      ],
    );
  }
}
