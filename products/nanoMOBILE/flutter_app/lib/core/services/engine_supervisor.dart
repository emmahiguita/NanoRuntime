// Espejo Dart de la política de supervisión definida en Rust
// (`memory_engine/supervision.rs`). Flutter ejecuta las acciones; la política
// (máquina de estados + backoff + presupuesto) es consistente con NanoRuntime.
//
// Principio: NUNCA auto-restart agresivo. Un fallo transitorio no debe
// convertirse en cascada. `deliberateStop` (memoria/térmica) NO provoca
// auto-restart inmediato.

enum EngineHealthState { healthy, suspect, unhealthy, loading, safeMode }

enum RecoveryIntent {
  none,
  trimCaches,
  cancelGeneration,
  unloadModel,
  fallbackSafeModel,
  restartEngine,
}

class SupervisorPolicy {
  final int consecutiveFailuresBeforeAction;
  final int restartBackoffMs;
  final int maxRestartsPerWindow;

  const SupervisorPolicy({
    this.consecutiveFailuresBeforeAction = 3,
    this.restartBackoffMs = 5000,
    this.maxRestartsPerWindow = 3,
  });
}

/// Máquina de estados del watchdog. Espejo de `EngineSupervisor` en Rust.
class EngineSupervisorState {
  final SupervisorPolicy policy;
  EngineHealthState health = EngineHealthState.healthy;

  int _consecutiveFailures = 0;
  int _restartsInWindow = 0;
  int _backoffUntilMs = 0;

  EngineSupervisorState({this.policy = const SupervisorPolicy()});

  void onHealthOk() {
    _consecutiveFailures = 0;
    if (health == EngineHealthState.suspect ||
        health == EngineHealthState.unhealthy) {
      health = EngineHealthState.healthy;
    }
  }

  /// Señal de health fallido. Decide la acción según proceso + parada deliberada.
  RecoveryIntent onHealthFail({
    required int nowMs,
    required bool processAlive,
    bool deliberateStop = false,
  }) {
    // Parada deliberada (memoria/térmica): NO auto-restart, esperar.
    if (deliberateStop) {
      health = EngineHealthState.suspect;
      return RecoveryIntent.none;
    }

    _consecutiveFailures++;
    if (_consecutiveFailures < policy.consecutiveFailuresBeforeAction) {
      // Fallo transitorio: esperar, no reiniciar aún.
      health = EngineHealthState.suspect;
      return RecoveryIntent.none;
    }

    if (processAlive) {
      // Proceso vivo pero health falla N veces → posible generation stalled.
      health = EngineHealthState.unhealthy;
      return RecoveryIntent.cancelGeneration;
    }

    // Proceso muerto → restart con backoff + presupuesto.
    if (nowMs < _backoffUntilMs) return RecoveryIntent.none;
    if (_restartsInWindow >= policy.maxRestartsPerWindow) {
      health = EngineHealthState.safeMode;
      return RecoveryIntent.fallbackSafeModel;
    }
    _restartsInWindow++;
    _backoffUntilMs = nowMs + policy.restartBackoffMs;
    health = EngineHealthState.loading;
    return RecoveryIntent.restartEngine;
  }

  void onRestartOk() {
    _consecutiveFailures = 0;
    health = EngineHealthState.loading;
  }

  void onModelReady() {
    health = EngineHealthState.healthy;
    _restartsInWindow = 0;
    _backoffUntilMs = 0;
  }
}
