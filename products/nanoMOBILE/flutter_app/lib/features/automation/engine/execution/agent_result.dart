/// Tipos de resultado del agente de UI: resolución y ejecución tipadas.
///
/// Principio: un fallo no es una excepción ni un bool false — es un
/// [AgentExecutionResult] con [AgentErrorCode] y motivo legible. La UI y el
/// futuro LLM aguas arriba deciden cómo reaccionar sin parsear strings.
library;

import '../perception/actionability_engine.dart';
import '../perception/nano_snapshot.dart';

/// Estado de una resolución de selector.
enum ResolveStatus { resolved, ambiguous, notFound, serviceOff }

/// Un candidato con su puntuación y los criterios que aportaron puntos.
class ScoreEntry {
  final NanoNode node;
  final int score;
  final List<String> matchedCriteria;

  const ScoreEntry({
    required this.node,
    required this.score,
    required this.matchedCriteria,
  });
}

/// Resultado de `NanoSelectorEngine.resolve`.
class ResolveOutcome {
  final ResolveStatus status;

  /// Top candidatos ordenados desc por score (máx 5).
  final List<ScoreEntry> candidates;

  /// Motivo legible en español (ambigüedad con scores, paquete erróneo…).
  final String reason;

  const ResolveOutcome({
    required this.status,
    required this.candidates,
    required this.reason,
  });

  bool get isResolved => status == ResolveStatus.resolved;

  /// Mejor candidato si resuelto.
  ScoreEntry? get best =>
      isResolved && candidates.isNotEmpty ? candidates.first : null;
}

/// Códigos de error del ejecutor de alto nivel.
enum AgentErrorCode {
  serviceOff,
  ambiguousTarget,
  notFound,
  unstableTarget,
  notActionable,
  gestureFailed,
  inputFailed,
  snapshotEmpty,
  timeout,
}

/// Resultado tipado de una ejecución de alto nivel (tap / setText).
class AgentExecutionResult {
  final bool ok;
  final AgentErrorCode? errorCode;

  /// Motivo en español, listo para UI.
  final String? reason;

  final ResolveOutcome? resolve;
  final ActionabilityState? actionability;

  /// Nodo finalmente actuado (solo en ok).
  final NanoNode? targetNode;

  const AgentExecutionResult.ok({
    this.resolve,
    this.actionability,
    this.targetNode,
  }) : ok = true,
       errorCode = null,
       reason = null;

  const AgentExecutionResult.failure({
    required AgentErrorCode this.errorCode,
    required String this.reason,
    this.resolve,
    this.actionability,
  }) : ok = false,
       targetNode = null;

  @override
  String toString() => ok
      ? 'AgentExecutionResult.ok(target=${targetNode?.label})'
      : 'AgentExecutionResult.failure($errorCode: $reason)';
}
