/// CandidateAction (A5) — dominio de planificación "grounded".
///
/// Diferencia frente a [ToolCall]: ToolCall responde "QUÉ debe ejecutar el
/// ejecutor?"; CandidateAction responde "POR QUÉ esta acción es real, DE DÓNDE
/// salió, CÓMO de grounded está, QUÉ canal la ejecutaría, QUÉ probará que
/// funcionó, QUÉ riesgo tiene". ToolCall permanece como transporte de
/// ejecución; CandidateAction es la acción grounded a nivel de planificación.
///
/// Puro Dart: sin Flutter UI, MethodChannel, Android SDK, PackageManager ni
/// singletons. `args` usa el contrato canónico A4 (sin selector/text/key).
library;

import '../../execution/action_verifier.dart' show ActionExpectation;
import '../../execution/tool_registry.dart' show ToolRisk;
import '../../system/system_capability.dart' show SystemCapability;

/// Identidad estable y determinista de un candidato grounded.
///
/// Ejemplos futuros: `app:launch:com.android.chrome`,
/// `system:intent:bluetooth_settings`, `ui:<screenSignature>:<id>:tap`.
/// El ID jamás se genera con un package inventado por el modelo.
final class CandidateId {
  final String value;

  CandidateId(this.value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(
        value,
        'value',
        'CandidateId no puede ser vacío.',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is CandidateId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// CÓMO puede ejecutarse la acción (mecanismo).
///
/// La presencia en el enum NO implica implementación disponible NI autorización.
/// Esas son decisiones de availability (A3) y política (A11).
enum ActionChannel {
  nanoFlow,
  deterministic,
  androidApi,
  androidIntent,
  notification,
  structuredTool,
  linux,
  accessibility,
  ocr,
  vision,
  coordinates,
  mcp,
  shizuku,
  deviceOwner,
  rootLab,
}

/// POR QUÉ Nano cree que la acción existe (proveniencia).
///
/// No incluye `llm`: el modelo puede rankear/razonar después, pero NO hace
/// real una acción. La evidencia de grounding viene de hechos observados.
enum ActionEvidenceSource {
  deterministicCatalog,
  packageManager,
  systemGraph,
  systemIntentCatalog,
  notificationCapability,
  nanoFlow,
  objectMemory,
  accessibility,
  ocr,
  vision,
  linuxToolRegistry,
  explicitConfiguration,
}

/// Una pieza de evidencia de grounding (inmutable, value equality).
class ActionEvidence {
  final ActionEvidenceSource source;
  final String reference;
  final double confidence;

  ActionEvidence({
    required this.source,
    required this.reference,
    required this.confidence,
  }) {
    if (confidence < 0.0 || confidence > 1.0) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'debe estar en [0,1].',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ActionEvidence &&
      other.source == source &&
      other.reference == reference &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(source, reference, confidence);
}

/// "Una acción que Nano realmente sabe cómo podría ejecutar." (grounded)
///
/// Inmutable: `args`, `requiredCapabilities` y `evidence` se protegen contra
/// mutación externa. El constructor rechaza candidatos estructuralmente
/// inválidos (id/semanticAction/tool vacíos, confidences fuera de [0,1],
/// evidence vacía). Un candidato grounded SIEMPRE tiene evidence.
final class CandidateAction {
  final CandidateId id;

  /// QUÉ significa la acción, independiente del ejecutor (ID semántico estable,
  /// no prosa libre del LLM): `open_app`, `open_bluetooth_settings`, etc.
  final String semanticAction;

  /// Tool del ejecutor (referenciado por ID string, como el ToolRegistry).
  final String tool;

  final Map<String, Object?> args;
  final ActionChannel channel;

  /// Confianza en que el candidato se refiere a una acción/target REAL y
  /// disponible. NO es la probabilidad de éxito de la tarea.
  final double groundingConfidence;

  /// Probabilidad histórica/estimada de que el camino complete con éxito.
  /// Distinta de [groundingConfidence]. null = sin telemetría aún.
  final double? expectedSuccess;

  final Duration? expectedLatency;
  final ToolRisk risk;

  /// ESTIMACIÓN semántica (no derivada de ToolRisk). El provider la declara.
  final bool reversible;

  /// Requisitos factuales de capability (A3). No es PrivilegeBroker (A11).
  final Set<SystemCapability> requiredCapabilities;

  final List<ActionEvidence> evidence;

  /// Postcondición de la ACCIÓN (no del goal completo: eso es GoalVerifier).
  final ActionExpectation? expectation;

  CandidateAction({
    required this.id,
    required this.semanticAction,
    required this.tool,
    required Map<String, Object?> args,
    required this.channel,
    required this.groundingConfidence,
    this.expectedSuccess,
    this.expectedLatency,
    required this.risk,
    required this.reversible,
    Set<SystemCapability> requiredCapabilities = const {},
    required List<ActionEvidence> evidence,
    this.expectation,
  }) : args = Map.unmodifiable(args),
       requiredCapabilities = Set.unmodifiable(requiredCapabilities),
       evidence = List.unmodifiable(evidence) {
    if (semanticAction.trim().isEmpty) {
      throw ArgumentError('semanticAction no puede ser vacío.');
    }
    if (tool.trim().isEmpty) {
      throw ArgumentError('tool no puede ser vacío.');
    }
    if (groundingConfidence < 0.0 || groundingConfidence > 1.0) {
      throw ArgumentError.value(
        groundingConfidence,
        'groundingConfidence',
        'debe estar en [0,1].',
      );
    }
    if (expectedSuccess != null &&
        (expectedSuccess! < 0.0 || expectedSuccess! > 1.0)) {
      throw ArgumentError.value(
        expectedSuccess,
        'expectedSuccess',
        'debe estar en [0,1].',
      );
    }
    if (evidence.isEmpty) {
      throw ArgumentError(
        'CandidateAction es grounded: evidence no puede ser vacía.',
      );
    }
  }
}
