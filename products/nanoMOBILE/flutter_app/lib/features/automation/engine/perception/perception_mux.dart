/// C12 — PerceptionMux V2 (A8): orquestación de percepción por confianza.
///
/// Orden: memoria verificada → Accessibility/ScreenGraph → escalado tipado
/// (OCR/Vision futuros). La percepción SOLO aporta evidencia para resolver el
/// target; NUNCA autoriza acciones por contenido observado (C11).
///
/// Orquestación, no ejecución: no ejecuta acciones, no rankea CandidateActions,
/// no cambia goals, no planifica.
library;

import '../memory/object_memory.dart' show UiSelectorEvidence;
import 'semantic/nano_ui_object.dart' show NanoUiObject;
import 'mux/accessibility_perception_source.dart';
import 'mux/object_memory_perception_source.dart';
import 'mux/ocr_perception_source.dart';
import 'mux/perception_contracts.dart';
import 'mux/perception_result.dart';

class PerceptionMux {
  const PerceptionMux({
    this.memorySource,
    this.accessibilitySource,
    this.ocrSource,
  });

  final ObjectMemoryPerceptionSource? memorySource;
  final AccessibilityPerceptionSource? accessibilitySource;
  final OcrPerceptionSource? ocrSource;

  bool get isEnabled =>
      memorySource != null || accessibilitySource != null || ocrSource != null;

  /// Percepción orquestada y tipada.
  Future<PerceptionResult> perceive(
    PerceptionRequest request, {
    PerceptionBudget budget = const PerceptionBudget(),
    ObservationPolicy policy = const ObservationPolicy(),
  }) async {
    // 1. Memoria verificada (si está permitida).
    final memory = memorySource;
    if (policy.allowMemory && memory != null) {
      final mem = await memory.perceive(request, budget);
      if (mem is PerceptionResolved && mem.memoryEvidence != null) {
        // 2. Validar la memoria contra Accessibility cuando es posible.
        final acc = accessibilitySource;
        if (policy.allowAccessibility &&
            acc != null &&
            budget.maxAccessibilityReads > 0) {
          final accResult = await acc.perceive(request, budget);
          if (accResult is PerceptionResolved &&
              accResult.object != null &&
              _matches(mem.memoryEvidence!, accResult.object!)) {
            // Memoria validada por Accessibility → evidencia combinada (fuerte).
            return PerceptionResolved(
              object: accResult.object,
              memoryEvidence: mem.memoryEvidence,
              confidence: _combined(mem.confidence, accResult.confidence),
              evidence: [...mem.evidence, ...accResult.evidence],
            );
          }
          // Memoria stale → el resultado de Accessibility manda.
          return accResult;
        }
        return mem; // memoria sin validación de pantalla
      }
    }

    // 3. Accessibility (si está permitida). Resuelto → 0 OCR.
    final acc = accessibilitySource;
    if (policy.allowAccessibility && acc != null) {
      final accResult = await acc.perceive(request, budget);
      if (accResult is PerceptionResolved) return accResult;
      // Insufficient/Ambiguous/Unavailable → escalar a OCR si está permitido.
      return _escalateToOcr(request, budget, policy, accResult);
    }

    // 4. Sin accesibilidad → OCR directo.
    return _escalateToOcr(
      request,
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
    final ocr = ocrSource;
    if (policy.allowOcr && ocr != null && budget.maxOcrCalls > 0) {
      return ocr.perceive(request, budget);
    }
    return fallback;
  }

  /// Compat legacy (selector string) para el AutomationCoordinator actual.
  Future<String?> resolve(
    String concept, {
    String? role,
    String? package,
    double minScore = 0.5,
  }) async {
    final result = await perceive(
      PerceptionRequest(
        targetConcept: concept,
        packageName: package,
        minimumConfidence: minScore,
      ),
    );
    if (result is! PerceptionResolved) return null;
    return _toSelector(result);
  }

  String? _toSelector(PerceptionResolved r) {
    final obj = r.object;
    if (obj != null) {
      if (obj.resourceId.isNotEmpty) return 'id=${obj.resourceId}';
      if (obj.text.isNotEmpty) return 'text=${obj.text}';
      if (obj.description.isNotEmpty) return 'desc=${obj.description}';
    }
    final ev = r.memoryEvidence;
    if (ev != null) {
      if (ev.resourceId != null && ev.resourceId!.isNotEmpty) {
        return 'id=${ev.resourceId}';
      }
      if (ev.text != null && ev.text!.isNotEmpty) return 'text=${ev.text}';
      if (ev.desc != null && ev.desc!.isNotEmpty) return 'desc=${ev.desc}';
    }
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

  double _combined(double a, double b) => (a + b) / 2;
}
