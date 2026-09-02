/// C12 — PerceptionMux V2 (A8): orquestación de percepción por confianza.
///
/// Orden: memoria conocida → Accessibility/ScreenGraph semántico → OCR
/// dirigido → Vision dirigida. Cada fuente más costosa se consulta únicamente
/// cuando la anterior no produjo evidencia suficiente. La percepción SOLO
/// aporta evidencia para resolver el target; NUNCA autoriza acciones.
///
/// Orquestación, no ejecución: no ejecuta acciones, no rankea CandidateActions,
/// no cambia goals, no planifica.
library;

import '../memory/object_memory.dart' show UiSelectorEvidence;
import 'nano_snapshot.dart' show NanoBounds;
import 'semantic/nano_ui_object.dart' show NanoUiObject;
import 'mux/accessibility_perception_source.dart';
import 'mux/object_memory_perception_source.dart';
import 'mux/ocr_perception_source.dart';
import 'mux/perception_contracts.dart';
import 'mux/perception_fusion.dart';
import 'mux/perception_result.dart';
import 'mux/vision_perception_source.dart';
import 'mux/visual_resource_policy.dart';

class PerceptionMux {
  const PerceptionMux({
    this.memorySource,
    this.accessibilitySource,
    this.ocrSource,
    this.visionSource,
    this.resourcePolicy,
  });

  final ObjectMemoryPerceptionSource? memorySource;
  final AccessibilityPerceptionSource? accessibilitySource;
  final OcrPerceptionSource? ocrSource;
  final VisionPerceptionSource? visionSource;

  /// AUT-VIS-03 — política de recursos del modelo visual. null → carga bajo
  /// demanda sin gate (comportamiento anterior).
  final VisualResourcePolicy? resourcePolicy;

  bool get isEnabled =>
      memorySource != null ||
      accessibilitySource != null ||
      ocrSource != null ||
      visionSource != null;

  /// Percepción orquestada y tipada.
  Future<PerceptionResult> perceive(
    PerceptionRequest request, {
    PerceptionBudget budget = const PerceptionBudget(),
    ObservationPolicy policy = const ObservationPolicy(),
  }) async {
    final requiredConfidence =
        (request.minimumConfidence > policy.minimumConfidence
                ? request.minimumConfidence
                : policy.minimumConfidence)
            .clamp(0.0, 1.0)
            .toDouble();
    final effectiveRequest = request.withMinimumConfidence(requiredConfidence);

    // 1. La memoria aporta únicamente un indicio histórico.
    final memory = memorySource;
    if (policy.allowMemory && memory != null) {
      final mem = await memory.perceive(effectiveRequest, budget);
      if (mem is PerceptionMemoryHint) {
        // 2. Validar la memoria contra Accessibility cuando es posible.
        final acc = accessibilitySource;
        if (policy.allowAccessibility &&
            acc != null &&
            budget.maxAccessibilityReads > 0) {
          final rawAccessibility = await acc.perceive(effectiveRequest, budget);
          final accResult = _enforceMinimum(
            rawAccessibility,
            effectiveRequest,
            PerceptionEvidenceSource.ocr,
          );
          if (accResult is PerceptionResolved &&
              _matches(mem.selector, accResult.object)) {
            // Memoria validada por Accessibility → evidencia combinada (fuerte).
            return PerceptionResolved(
              object: accResult.object,
              memoryEvidence: mem.selector,
              // La memoria corrobora, pero nunca reduce ni sustituye la
              // confianza de la observación estructurada actual.
              confidence: accResult.confidence,
              evidence: [...mem.evidence, ...accResult.evidence],
            );
          }
          if (accResult is PerceptionResolved) {
            // Memoria stale: Accessibility actual manda y corta el escalado.
            return accResult;
          }
          // La validación actual no alcanzó evidencia suficiente. Antes se
          // retornaba aquí y OCR/Vision quedaban omitidos por un memory hit.
          return _escalateToOcr(effectiveRequest, budget, policy, accResult);
        }
        // Sin observación actual la memoria no puede convertirse en resolved.
        const memoryResult = PerceptionInsufficient(
          reason: 'La memoria histórica requiere validación en pantalla.',
          recommendedSource: PerceptionEvidenceSource.accessibility,
        );
        return _escalateToOcr(effectiveRequest, budget, policy, memoryResult);
      }
    }

    // 3. Accessibility (si está permitida). Resuelto → 0 OCR.
    final acc = accessibilitySource;
    if (policy.allowAccessibility && acc != null) {
      final accResult = _enforceMinimum(
        await acc.perceive(effectiveRequest, budget),
        effectiveRequest,
        PerceptionEvidenceSource.ocr,
      );
      if (accResult is PerceptionResolved) return accResult;
      // Insufficient/Ambiguous/Unavailable → escalar a OCR si está permitido.
      return _escalateToOcr(effectiveRequest, budget, policy, accResult);
    }

    // 4. Sin accesibilidad → OCR directo.
    return _escalateToOcr(
      effectiveRequest,
      budget,
      policy,
      const PerceptionInsufficient(
        reason: 'Sin accesibilidad.',
        recommendedSource: PerceptionEvidenceSource.ocr,
      ),
    );
  }

  Future<PerceptionResult> _escalateToOcr(
    PerceptionRequest request,
    PerceptionBudget budget,
    ObservationPolicy policy,
    PerceptionResult fallback,
  ) async {
    final targetedRequest = _targetedRequest(request, fallback);
    final ocr = ocrSource;
    if (policy.allowOcr && ocr != null && budget.maxOcrCalls > 0) {
      final ocrResult = _enforceMinimum(
        await ocr.perceive(targetedRequest, budget),
        targetedRequest,
        PerceptionEvidenceSource.vision,
      );
      if (ocrResult is PerceptionResolved) {
        // Fusión (AUT-VIS-05): si la accesibilidad tenía candidatos en la
        // misma región, el resultado fusionado ancla el objeto ACCESIBLE
        // real (ejecutable) con la evidencia OCR como refuerzo — nunca al
        // revés. El role y el target salen de la observación estructurada.
        final fused = _fuseWithStructuredCandidates(fallback, ocrResult);
        if (fused != null) return fused;
        return ocrResult;
      }
      return _escalateToVision(
        targetedRequest,
        budget,
        policy,
        _preferStructured(fallback, ocrResult),
      );
    }
    return _escalateToVision(targetedRequest, budget, policy, fallback);
  }

  Future<PerceptionResult> _escalateToVision(
    PerceptionRequest request,
    PerceptionBudget budget,
    ObservationPolicy policy,
    PerceptionResult fallback,
  ) async {
    // AUT-VIS-03: la política de recursos puede negar la carga del modelo
    // visual (RAM/térmica). La degradación conserva la evidencia anterior
    // SIN tocar el backend — la visión nunca es requisito.
    final resourcePolicy = this.resourcePolicy;
    if (resourcePolicy != null) {
      await resourcePolicy.refresh();
      if (!resourcePolicy.mayLoad()) {
        return fallback;
      }
    }
    final vision = visionSource;
    if (policy.allowVision &&
        vision != null &&
        budget.maxVisionCalls > 0 &&
        (request.region != null || policy.allowFullScreenVision)) {
      final visionResult = _enforceMinimum(
        await vision.perceive(request, budget),
        request,
        PerceptionEvidenceSource.vision,
      );
      if (visionResult is PerceptionResolved) return visionResult;
      return _preferStructured(fallback, visionResult);
    }
    return fallback;
  }

  /// Compat legacy (selector string) para el AutomationCoordinator actual.
  Future<String?> resolve(
    String concept, {
    String? role,
    String? package,
    double minScore = 0.5,
    PerceptionBudget budget = const PerceptionBudget(),
    ObservationPolicy policy = const ObservationPolicy(allowVision: true),
  }) async {
    final result = await perceive(
      PerceptionRequest(
        targetConcept: concept,
        packageName: package,
        minimumConfidence: minScore,
      ),
      budget: budget,
      policy: policy,
    );
    if (result is! PerceptionResolved) return null;
    // OCR/Vision producen objetos virtuales para observación. No son targets
    // ejecutables por sí mismos: solo el navegador puede re-ligarlos a un
    // control accesible actual y único antes de generar una acción.
    if (result.object.sourceIndex < 0) return null;
    return _toSelector(result);
  }

  String? _toSelector(PerceptionResolved r) {
    final obj = r.object;
    if (obj.description.isNotEmpty) return 'desc=${obj.description}';
    if (obj.text.isNotEmpty) return 'text=${obj.text}';
    if (obj.resourceId.isNotEmpty) return 'id=${obj.resourceId}';
    return null;
  }

  bool _matches(UiSelectorEvidence ev, NanoUiObject obj) {
    if (ev.resourceId != null && ev.resourceId!.isNotEmpty) {
      return obj.resourceId == ev.resourceId;
    }
    if (ev.text != null && ev.text!.isNotEmpty) {
      return obj.text == ev.text || obj.label == ev.text;
    }
    if (ev.desc != null && ev.desc!.isNotEmpty) {
      return obj.description == ev.desc || obj.label == ev.desc;
    }
    return false;
  }

  PerceptionResult _enforceMinimum(
    PerceptionResult result,
    PerceptionRequest request,
    PerceptionEvidenceSource recommendedSource,
  ) {
    if (result is! PerceptionResolved ||
        result.confidence >= request.minimumConfidence) {
      return result;
    }
    return PerceptionInsufficient(
      reason:
          'Confianza insuficiente (${result.confidence} < '
          '${request.minimumConfidence}).',
      recommendedSource: recommendedSource,
    );
  }

  /// Conserva evidencia estructurada útil cuando una fuente más cara falla.
  /// Un resultado probabilístico resuelto sí puede completar una observación
  /// insuficiente; un fallo probabilístico no borra una ambigüedad factual.
  PerceptionResult _preferStructured(
    PerceptionResult structured,
    PerceptionResult escalated,
  ) {
    if (_resultRank(structured) >= _resultRank(escalated)) return structured;
    return escalated;
  }

  int _resultRank(PerceptionResult result) => switch (result) {
    PerceptionResolved() => 4,
    PerceptionAmbiguous() => 3,
    PerceptionInsufficient() => 2,
    PerceptionUnavailable() => 1,
    PerceptionMemoryHint() => 0,
  };

  /// Fusiona un resultado OCR resuelto con el candidato accesible que ocupa
  /// la misma región. El objeto resultante es el ACCESIBLE (target real y
  /// ejecutable); la observación OCR refuerza la evidencia. null si no hay
  /// candidato compatible — el resultado OCR (virtual) se conserva.
  PerceptionResolved? _fuseWithStructuredCandidates(
    PerceptionResult structured,
    PerceptionResolved ocrResult,
  ) {
    if (structured is! PerceptionAmbiguous) return null;
    for (final candidate in structured.candidates) {
      if (candidate.bounds.xOverlapRatio(ocrResult.object.bounds) > 0.5) {
        return PerceptionResolved(
          object: candidate,
          confidence: PerceptionFusionEngine.combine(
            candidate.confidence,
            ocrResult.confidence,
          ),
          evidence: [
            PerceptionEvidence(
              source: PerceptionEvidenceSource.accessibility,
              reference: candidate.id,
              confidence: candidate.confidence,
            ),
            ...ocrResult.evidence,
          ],
        );
      }
    }
    return null;
  }

  /// Si Accessibility encontró candidatos ambiguos, limita OCR/Vision al
  /// rectángulo que ya contiene evidencia estructurada. Sin candidatos no se
  /// inventa una región: OCR conserva su fallback actual y Vision full-screen
  /// sigue bloqueada salvo autorización explícita de policy + budget.
  PerceptionRequest _targetedRequest(
    PerceptionRequest request,
    PerceptionResult structured,
  ) {
    if (request.region != null || structured is! PerceptionAmbiguous) {
      return request;
    }
    final candidates = structured.candidates;
    if (candidates.isEmpty) return request;
    var left = candidates.first.bounds.left;
    var top = candidates.first.bounds.top;
    var right = candidates.first.bounds.right;
    var bottom = candidates.first.bounds.bottom;
    for (final candidate in candidates.skip(1)) {
      final bounds = candidate.bounds;
      if (bounds.left < left) left = bounds.left;
      if (bounds.top < top) top = bounds.top;
      if (bounds.right > right) right = bounds.right;
      if (bounds.bottom > bottom) bottom = bounds.bottom;
    }
    return request.withRegion(
      NanoBounds(left: left, top: top, right: right, bottom: bottom),
    );
  }
}
