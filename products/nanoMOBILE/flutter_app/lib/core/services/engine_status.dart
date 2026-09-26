// engine_status.dart — Estado observable y fases del motor nanortime.
// QUÉ HACE: Modela las fases de vida del motor de inferencia (idle, starting, ready, degraded, failed).
// CÓMO FUNCIONA: Inmutable value object con métodos de copia, comprobación de liveness y comparación.
// POR QUÉ: Extraído de runtime_engine.dart para aplicar SOLID (SRP) y mantener archivos < 200 líneas.
library;

/// Fase del motor nanortime según la evidencia real (canal + HTTP).
///
/// - [EnginePhase.idle]: no arrancado.
/// - [EnginePhase.starting]: spawn aceptado por el supervisor Kotlin,
///   health poll en curso.
/// - [EnginePhase.ready]: /health OK y /api/status 200 (modelo cargado).
/// - [EnginePhase.degraded]: /health OK pero /api/status 503
///   runtime_unavailable — motor vivo sin GGUF instalado.
/// - [EnginePhase.failed]: el supervisor reportó fallo (spawn, health
///   timeout, proceso muerto).
enum EnginePhase { idle, starting, ready, degraded, failed }

/// Estado observable del motor para chips, dashboard y monitores.
class EngineStatus {
  final EnginePhase phase;
  final int? pid;
  final int port;
  final String? reason;

  /// Ruta del GGUF con el que arrancó el motor (null = --no-model).
  /// Permite detectar cambio de modelo y reiniciar honestamente.
  final String? modelPath;

  const EngineStatus({
    this.phase = EnginePhase.idle,
    this.pid,
    this.port = 8080,
    this.reason,
    this.modelPath,
  });

  EngineStatus copyWith({
    EnginePhase? phase,
    int? pid,
    int? port,
    String? reason,
    String? modelPath,
    bool clearReason = false,
    bool clearModelPath = false,
  }) => EngineStatus(
    phase: phase ?? this.phase,
    pid: pid ?? this.pid,
    port: port ?? this.port,
    reason: clearReason ? null : (reason ?? this.reason),
    modelPath: clearModelPath ? null : (modelPath ?? this.modelPath),
  );

  bool get isLive =>
      phase == EnginePhase.ready || phase == EnginePhase.degraded;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EngineStatus &&
          phase == other.phase &&
          pid == other.pid &&
          port == other.port &&
          reason == other.reason &&
          modelPath == other.modelPath;

  @override
  int get hashCode => Object.hash(phase, pid, port, reason, modelPath);
}
