/// A16 — MlKitVisionBackend: backend REAL on-device del seam de visión.
///
/// Implementa [VisionBackend] usando ML Kit Image Labeling (etiquetado de
/// imagen, sin red). Devuelve objetos estructurados (label/confidence/bounds),
/// nunca prosa ejecutable. El contenido visual es OBSERVACIÓN NO CONFIABLE.
library;

import 'package:nanoai/core/services/nano_runtime_api.dart';

import '../nano_snapshot.dart' show NanoBounds;
import '../semantic/semantic_role.dart';
import 'vision_contracts.dart';

class MlKitVisionBackend implements VisionBackend {
  const MlKitVisionBackend();

  @override
  Future<VisionResult> analyze(VisionRequest request) async {
    final results = await NanoRuntimeApi.instance.visionLabel(
      request.image.pngBytes,
    );
    final objects = <VisionObject>[];
    for (final raw in results) {
      if (raw is! Map) continue;
      final label = '${raw['label'] ?? ''}';
      if (label.isEmpty) continue;
      final b = raw['bounds'];
      final bounds = (b is List && b.length == 4)
          ? NanoBounds(
              left: (b[0] as num).toInt(),
              top: (b[1] as num).toInt(),
              right: (b[2] as num).toInt(),
              bottom: (b[3] as num).toInt(),
            )
          : request.image.bounds;
      objects.add(
        VisionObject(
          role: SemanticRole.unknown,
          label: label,
          bounds: bounds,
          confidence: (raw['confidence'] as num?)?.toDouble() ?? 0.0,
          // El ML Kit devuelve bounds relativos al bitmap del crop; el
          // VisionPerceptionSource los convierte a screen-absolute.
          boundsSpace: CoordinateSpace.imageRelative,
        ),
      );
    }
    return VisionResult(objects: objects, space: CoordinateSpace.imageRelative);
  }
}
