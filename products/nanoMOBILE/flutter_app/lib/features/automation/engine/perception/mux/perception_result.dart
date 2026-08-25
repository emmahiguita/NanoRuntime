/// PerceptionResult (A8) — resultado tipado y honesto de la percepción.
///
/// Sin null para cada modo de fallo: Resolved / Ambiguous / Insufficient /
/// Unavailable. El contenido de pantalla es OBSERVACIÓN NO CONFIABLE; nunca
/// autoriza acciones ni muta el goal.
library;

import '../../memory/object_memory.dart' show UiSelectorEvidence;
import '../semantic/nano_ui_object.dart' show NanoUiObject;
import 'perception_contracts.dart';

sealed class PerceptionResult {
  const PerceptionResult();
}

/// Resuelto con un target grounded. [object] (vivo, Accessibility) y/o
/// [memoryEvidence] (verificado en memoria) pueden coexistir (más fuerte).
class PerceptionResolved extends PerceptionResult {
  final NanoUiObject? object;
  final UiSelectorEvidence? memoryEvidence;
  final double confidence;
  final List<PerceptionEvidence> evidence;

  const PerceptionResolved({
    this.object,
    this.memoryEvidence,
    required this.confidence,
    required this.evidence,
  });
}

/// Varios candidatos igualmente plausibles: NO elegir a ciegas.
class PerceptionAmbiguous extends PerceptionResult {
  final List<NanoUiObject> candidates;
  final String reason;
  final List<PerceptionEvidence> evidence;

  const PerceptionAmbiguous({
    required this.candidates,
    required this.reason,
    required this.evidence,
  });
}

/// La percepción estructurada es insuficiente; recomienda escalar a otra
/// fuente (A8: OCR futuro, aún NO implementado).
class PerceptionInsufficient extends PerceptionResult {
  final String reason;
  final PerceptionEvidenceSource recommendedSource;

  const PerceptionInsufficient({
    required this.reason,
    required this.recommendedSource,
  });
}

/// Fuente no disponible (p. ej. Accessibility apagada / snapshot null).
class PerceptionUnavailable extends PerceptionResult {
  final String reason;

  const PerceptionUnavailable(this.reason);
}
