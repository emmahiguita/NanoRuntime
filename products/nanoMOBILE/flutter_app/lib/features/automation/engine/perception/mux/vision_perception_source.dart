/// VisionPerceptionSource (A10) — percepción visual como ÚLTIMO escalado.
///
/// Captura (crop o full-screen) → VisionBackend.analyze → transforma bounds a
/// screen-absolute → matching → PerceptionResult. NO ejecuta acciones, NO crea
/// ToolCall ni CandidateAction. El contenido visual es OBSERVACIÓN.
library;

import '../semantic/nano_ui_object.dart';
import '../semantic/semantic_role.dart';
import 'ocr_contracts.dart' show ScreenImageProvider;
import 'perception_contracts.dart';
import 'perception_result.dart';
import 'perception_source.dart';
import 'vision_contracts.dart';

class VisionPerceptionSource implements PerceptionSource {
  VisionPerceptionSource(this._imageProvider, this._backend);

  final ScreenImageProvider _imageProvider;
  final VisionBackend _backend;

  int visionCalls = 0;
  int fullScreenCalls = 0;

  @override
  Future<PerceptionResult> perceive(
    PerceptionRequest request,
    PerceptionBudget budget,
  ) async {
    if (budget.maxVisionCalls <= 0) {
      return const PerceptionInsufficient(
        reason: 'Presupuesto de visión agotado.',
        recommendedSource: PerceptionEvidenceSource.vision,
      );
    }
    final region = request.region;
    final fullScreen = region == null;
    if (fullScreen && budget.maxFullScreenVisionCalls <= 0) {
      return const PerceptionInsufficient(
        reason: 'Visión full-screen no permitida por presupuesto.',
        recommendedSource: PerceptionEvidenceSource.vision,
      );
    }
    final img = await _imageProvider.capture(region: region);
    if (!img.captured || img.image == null) {
      return PerceptionUnavailable(
        img.error ?? 'Captura de pantalla no disponible.',
      );
    }
    visionCalls++;
    if (fullScreen) fullScreenCalls++;

    final result = await _backend.analyze(
      VisionRequest(
        image: img.image!,
        requestedConcept: request.targetConcept,
        expectedRole: request.expectedRole,
        mode: VisionMode.locateTarget,
      ),
    );
    if (result.objects.isEmpty) {
      return const PerceptionInsufficient(
        reason: 'Visión sin objetos.',
        recommendedSource: PerceptionEvidenceSource.vision,
      );
    }

    // Convertir bounds a screen-absolute (sin ambigüedad de espacio).
    final origin = img.image!.bounds;
    final absolute = result.objects
        .map(
          (o) => VisionObject(
            role: o.role,
            label: o.label,
            bounds: toScreenAbsolute(o.bounds, origin),
            confidence: o.confidence,
            boundsSpace: CoordinateSpace.screenAbsolute,
          ),
        )
        .toList(growable: false);

    final concept = request.targetConcept.trim().toLowerCase();
    final matches = absolute.where((o) {
      final label = o.label.trim().toLowerCase();
      final roleOk =
          request.expectedRole == null || o.role == request.expectedRole;
      final labelOk =
          label.isNotEmpty &&
          (label.contains(concept) || concept.contains(label));
      return roleOk && labelOk;
    }).toList();
    matches.sort((a, b) => b.confidence.compareTo(a.confidence));
    if (matches.isEmpty) {
      return const PerceptionInsufficient(
        reason: 'Visión no coincide con el concepto/rol.',
        recommendedSource: PerceptionEvidenceSource.vision,
      );
    }

    final best = matches.first;
    final virtual = NanoUiObject(
      id: 'vision:${best.bounds.centerX}:${best.bounds.centerY}',
      role: best.role,
      label: best.label,
      text: best.label,
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
      evidence: const [SemanticEvidenceSource.structure],
      sourceIndex: -1,
    );
    return PerceptionResolved(
      object: virtual,
      confidence: best.confidence,
      evidence: [
        PerceptionEvidence(
          source: PerceptionEvidenceSource.vision,
          reference: best.label,
          confidence: best.confidence,
        ),
      ],
    );
  }
}
