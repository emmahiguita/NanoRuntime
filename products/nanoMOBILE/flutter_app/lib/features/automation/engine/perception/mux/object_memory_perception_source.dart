/// ObjectMemoryPerceptionSource (A8) — memoria verificada como fuente de
/// percepción. Solo devuelve lo que la memoria YA verificó; no toca la pantalla
/// (la validación contra el ScreenGraph actual la hace el PerceptionMux).
library;

import '../../memory/object_memory.dart' show NanoObjectMemory, UiObjectKey;
import 'perception_contracts.dart';
import 'perception_result.dart';
import 'perception_source.dart';

class ObjectMemoryPerceptionSource implements PerceptionSource {
  ObjectMemoryPerceptionSource(this._memory);

  final NanoObjectMemory _memory;

  @override
  Future<PerceptionResult> perceive(
    PerceptionRequest request,
    PerceptionBudget budget,
  ) async {
    final key = UiObjectKey(
      concept: request.targetConcept,
      package: request.packageName ?? '',
    );
    final evidence = _memory.resolve(key);
    if (evidence == null) {
      return const PerceptionInsufficient(
        reason: 'Sin memoria verificada para el concepto.',
        recommendedSource: PerceptionEvidenceSource.accessibility,
      );
    }
    final confidence = _memory.confidence(key);
    return PerceptionResolved(
      memoryEvidence: evidence,
      confidence: confidence,
      evidence: [
        PerceptionEvidence(
          source: PerceptionEvidenceSource.objectMemory,
          reference: evidence.fingerprint,
          confidence: confidence,
        ),
      ],
    );
  }
}
