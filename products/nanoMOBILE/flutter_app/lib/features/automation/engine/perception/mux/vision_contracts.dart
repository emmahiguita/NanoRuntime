/// VisionBackend / VisionObject (A10) — percepción visual estructurada.
///
/// Vision es percepción, NO autoridad: el contenido visual es OBSERVACIÓN NO
/// CONFIABLE (como OCR/Accessibility). El backend devuelve objetos
/// ESTRUCTURADOS (role/label/bounds/confidence), nunca prosa ejecutable.
library;

import '../semantic/semantic_role.dart';
import '../nano_snapshot.dart' show NanoBounds;
import 'ocr_contracts.dart' show ScreenImage;

/// Espacio de coordenadas de los bounds (explícito, sin ambigüedad).
enum CoordinateSpace { screenAbsolute, cropRelative, imageRelative }

/// Modo de análisis visual (no un prompt libre como API primaria).
enum VisionMode { detectObjects, locateTarget }

/// Objeto visual estructurado. Reusa [SemanticRole] (sin taxonomía duplicada).
class VisionObject {
  final SemanticRole role;
  final String label;
  final NanoBounds bounds;
  final double confidence;
  final CoordinateSpace boundsSpace;

  const VisionObject({
    required this.role,
    required this.label,
    required this.bounds,
    required this.confidence,
    required this.boundsSpace,
  });
}

class VisionResult {
  final List<VisionObject> objects;
  final CoordinateSpace space;

  const VisionResult({required this.objects, required this.space});
}

class VisionRequest {
  final ScreenImage image;
  final String requestedConcept;
  final SemanticRole? expectedRole;
  final VisionMode mode;

  const VisionRequest({
    required this.image,
    required this.requestedConcept,
    this.expectedRole,
    this.mode = VisionMode.locateTarget,
  });
}

/// Analiza una imagen (crop o full-screen) y devuelve observaciones
/// estructuradas. Implementación concreta en platform (backend real NO listo
/// en A10: el runtime local es text-only).
abstract interface class VisionBackend {
  Future<VisionResult> analyze(VisionRequest request);
}

/// Convierte bounds crop-relative a screen-absolute sumando el offset del crop.
NanoBounds toScreenAbsolute(NanoBounds cropRelative, NanoBounds cropOrigin) {
  return NanoBounds(
    left: cropOrigin.left + cropRelative.left,
    top: cropOrigin.top + cropRelative.top,
    right: cropOrigin.left + cropRelative.right,
    bottom: cropOrigin.top + cropRelative.bottom,
  );
}
