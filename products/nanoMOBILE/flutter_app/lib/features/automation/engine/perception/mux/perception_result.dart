/// PerceptionResult (A8) — resultado tipado y honesto de la percepción.
///
/// Sin null para cada estado: MemoryHint / Resolved / Ambiguous / Insufficient
/// / Unavailable. El contenido de pantalla es OBSERVACIÓN NO CONFIABLE; nunca
/// autoriza acciones ni muta el goal.
library;

import '../../memory/object_memory.dart' show UiSelectorEvidence;
import '../semantic/nano_ui_object.dart' show NanoUiObject;
import 'perception_contracts.dart';

sealed class PerceptionResult {
  const PerceptionResult();
}

/// Indicio histórico recuperado de ObjectMemory. Puede orientar la búsqueda,
/// pero no representa una observación de la pantalla actual.
class PerceptionMemoryHint extends PerceptionResult {
  final UiSelectorEvidence selector;
  final double confidence;
  final List<PerceptionEvidence> evidence;

  const PerceptionMemoryHint({
    required this.selector,
    required this.confidence,
    required this.evidence,
  });
}

/// Resuelto con un target grounded por una observación actual. La memoria puede
/// coexistir únicamente cuando esa observación validó el indicio histórico.
class PerceptionResolved extends PerceptionResult {
  final NanoUiObject object;
  final UiSelectorEvidence? memoryEvidence;
  final double confidence;
  final List<PerceptionEvidence> evidence;

  const PerceptionResolved({
    required this.object,
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

/// La percepción actual es insuficiente; recomienda la siguiente fuente que
/// puede aportar evidencia sin convertir esa recomendación en autoridad.
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
