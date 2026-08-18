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

/// Estado de presión de memoria (P3), espejo del Rust `MemoryPressure`.
enum MemoryPressureState { normal, pressure, critical, emergency }

/// MemoryGuard con histéresis (P3): umbrales distintos para subir y bajar.
/// Las acciones fuertes ocurren por TRANSICIÓN (newState != previous), no cada
/// tick — evita `fallback → fallback → fallback` en EMERGENCY sostenido.
class MemoryGuardState {
  MemoryPressureState state = MemoryPressureState.normal;

  final int enterPressureMb;
  final int enterCriticalMb;
  final int enterEmergencyMb;
  final int hysteresisMb;

  MemoryGuardState({
    this.enterPressureMb = 1500,
    this.enterCriticalMb = 800,
    this.enterEmergencyMb = 400,
    this.hysteresisMb = 200,
  });

  /// Actualiza el estado según MemAvailable. Subir es inmediato; bajar exige
  /// margen extra (histéresis) para evitar oscilación.
  MemoryPressureState update(int freeMemMb) {
    if (freeMemMb < enterEmergencyMb) {
      state = MemoryPressureState.emergency;
    } else if (freeMemMb < enterCriticalMb) {
      state = MemoryPressureState.critical;
    } else if (freeMemMb < enterPressureMb) {
      state = MemoryPressureState.pressure;
    } else {
      state = switch (state) {
        MemoryPressureState.emergency
            when freeMemMb > enterEmergencyMb + hysteresisMb =>
          MemoryPressureState.critical,
        MemoryPressureState.critical
            when freeMemMb > enterCriticalMb + hysteresisMb =>
          MemoryPressureState.pressure,
        MemoryPressureState.pressure
            when freeMemMb > enterPressureMb + hysteresisMb =>
          MemoryPressureState.normal,
        _ => state,
      };
    }
    return state;
  }

  /// Intención de recuperación que corresponde al estado actual.
  RecoveryIntent intent() {
    return switch (state) {
      MemoryPressureState.normal => RecoveryIntent.none,
      MemoryPressureState.pressure => RecoveryIntent.trimCaches,
      MemoryPressureState.critical => RecoveryIntent.cancelGeneration,
      MemoryPressureState.emergency => RecoveryIntent.fallbackSafeModel,
    };
  }
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
