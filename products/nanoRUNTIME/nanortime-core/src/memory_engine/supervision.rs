//! Supervision — watchdog del motor (P4) + memory guard (P3).
//!
//! Principio: NUNCA auto-restart agresivo. Un fallo transitorio no debe
//! convertirse en cascada. El supervisor distingue `SERVER_UNREACHABLE`,
//! `MODEL_LOADING`, `GENERATION_STALLED` y `PROCESS_DEAD`, y cada uno produce
//! una acción distinta. La parada deliberada (memoria/térmica) NO provoca
//! auto-restart inmediato — espera a que la presión baje.

/// Estado de salud del motor.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EngineHealth {
    /// Health OK, sin fallos.
    Healthy,
    /// Health falló 1..N veces — transitorio, esperar.
    Suspect,
    /// Health falló N veces — acción requerida (verificar proceso).
    Unhealthy,
    /// Reiniciando / cargando modelo.
    Loading,
    /// Reinicios agotados → fallback al modelo seguro (1.5B).
    SafeMode,
}

/// Motivo de una parada deliberada del motor. Distinto de un crash: un
/// `MemoryEmergency`/`ThermalEmergency` NO debe disparar auto-restart.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EngineStopReason {
    User,
    MemoryEmergency,
    ThermalEmergency,
    ModelFailure,
    Crash,
}

impl EngineStopReason {
    /// True si la parada es deliberada y el supervisor debe esperar.
    pub fn is_deliberate(&self) -> bool {
        matches!(
            self,
            EngineStopReason::MemoryEmergency | EngineStopReason::ThermalEmergency
        )
    }
}

/// Intención de recuperación. Los subsistemas (MemoryGuard, EngineSupervisor)
/// NO actúan directamente: emiten intenciones que el RecoveryCoordinator
/// ordena y ejecuta, evitando decisiones contradictorias.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RecoveryIntent {
    None,
    TrimCaches,
    CancelGeneration,
    UnloadModel,
    FallbackSafeModel,
    RestartEngine,
}

/// Estado de presión de memoria (P3), con histéresis.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum MemoryPressure {
    Normal,
    Pressure,
    Critical,
    Emergency,
}

/// Política del supervisor: umbrales + backoff + presupuesto de reinicios.
#[derive(Debug, Clone)]
pub struct SupervisorPolicy {
    pub health_interval_ms: u64,
    pub consecutive_failures_before_action: u32,
    pub restart_backoff_ms: u64,
    pub max_restarts_per_window: u32,
    pub recovery_timeout_ms: u64,
}

impl Default for SupervisorPolicy {
    fn default() -> Self {
        Self {
            health_interval_ms: 2_000,
            consecutive_failures_before_action: 3,
            restart_backoff_ms: 5_000,
            max_restarts_per_window: 3,
            recovery_timeout_ms: 30_000,
        }
    }
}

/// MemoryGuard con histéresis (P3): umbrales distintos para subir y bajar,
/// evitando oscilación `PRESSURE → NORMAL → PRESSURE` cada pocos segundos.
pub struct MemoryGuard {
    pub state: MemoryPressure,
    enter_pressure_mb: u64,
    enter_critical_mb: u64,
    enter_emergency_mb: u64,
    /// Margen extra para bajar de nivel (histéresis).
    hysteresis_mb: u64,
}

impl MemoryGuard {
    pub fn new() -> Self {
        Self {
            state: MemoryPressure::Normal,
            enter_pressure_mb: 1500,
            enter_critical_mb: 800,
            enter_emergency_mb: 400,
            hysteresis_mb: 200,
        }
    }

    /// Actualiza el estado según la RAM libre (MemAvailable) y el fault rate.
    /// Subir es inmediato; bajar exige margen extra (histéresis).
    pub fn update(&mut self, free_mem_mb: u64, _major_faults_per_sec: f64) -> MemoryPressure {
        // Empeorar (o entrar) es inmediato.
        if free_mem_mb < self.enter_emergency_mb {
            self.state = MemoryPressure::Emergency;
        } else if free_mem_mb < self.enter_critical_mb {
            self.state = MemoryPressure::Critical;
        } else if free_mem_mb < self.enter_pressure_mb {
            self.state = MemoryPressure::Pressure;
        } else {
            // Mejorar solo con margen de histéresis.
            self.state = match self.state {
                MemoryPressure::Emergency
                    if free_mem_mb > self.enter_emergency_mb + self.hysteresis_mb =>
                {
                    MemoryPressure::Critical
                }
                MemoryPressure::Critical
                    if free_mem_mb > self.enter_critical_mb + self.hysteresis_mb =>
                {
                    MemoryPressure::Pressure
                }
                MemoryPressure::Pressure
                    if free_mem_mb > self.enter_pressure_mb + self.hysteresis_mb =>
                {
                    MemoryPressure::Normal
                }
                s => s,
            };
        }
        self.state
    }

    /// Intención de recuperación que corresponde al estado actual.
    pub fn intent(&self) -> RecoveryIntent {
        match self.state {
            MemoryPressure::Normal => RecoveryIntent::None,
            MemoryPressure::Pressure => RecoveryIntent::TrimCaches,
            MemoryPressure::Critical => RecoveryIntent::CancelGeneration,
            MemoryPressure::Emergency => RecoveryIntent::FallbackSafeModel,
        }
    }
}

impl Default for MemoryGuard {
    fn default() -> Self {
        Self::new()
    }
}

/// Watchdog del motor (P4): máquina de estados + backoff + presupuesto.
///
/// El `now_ms` lo provee el llamador (monotónico) para que la máquina sea
/// pura y determinista. El "progreso" (last_token_at, etc.) lo rastrea el
/// llamador vía telemetría; aquí solo se decide la transición.
pub struct EngineSupervisor {
    pub health: EngineHealth,
    policy: SupervisorPolicy,
    consecutive_failures: u32,
    restarts_in_window: u32,
    backoff_until_ms: u64,
}

impl EngineSupervisor {
    pub fn new(policy: SupervisorPolicy) -> Self {
        Self {
            health: EngineHealth::Healthy,
            policy,
            consecutive_failures: 0,
            restarts_in_window: 0,
            backoff_until_ms: 0,
        }
    }

    /// Health OK: resetear fallos y volver a Healthy.
    pub fn on_health_ok(&mut self) {
        self.consecutive_failures = 0;
        if matches!(self.health, EngineHealth::Suspect | EngineHealth::Unhealthy) {
            self.health = EngineHealth::Healthy;
        }
    }

    /// Health fallido. Decide la acción según proceso + motivo de parada.
    pub fn on_health_fail(
        &mut self,
        now_ms: u64,
        process_alive: bool,
        stop_reason: Option<EngineStopReason>,
    ) -> RecoveryIntent {
        // Parada deliberada (memoria/térmica): NO auto-restart, esperar a que
        // la presión baje. Evita el loop MemoryGuard↔Supervisor.
        if let Some(reason) = stop_reason {
            if reason.is_deliberate() {
                self.health = EngineHealth::Suspect;
                return RecoveryIntent::None;
            }
        }

        self.consecutive_failures += 1;
        if self.consecutive_failures < self.policy.consecutive_failures_before_action {
            // Fallo transitorio: esperar, no reiniciar aún.
            self.health = EngineHealth::Suspect;
            return RecoveryIntent::None;
        }

        if process_alive {
            // Proceso vivo pero health falla N veces → posible generation stalled.
            // No reiniciar; primero cancelar la generación.
            self.health = EngineHealth::Unhealthy;
            return RecoveryIntent::CancelGeneration;
        }

        // Proceso muerto → restart con backoff + presupuesto.
        if now_ms < self.backoff_until_ms {
            return RecoveryIntent::None; // en backoff
        }
        if self.restarts_in_window >= self.policy.max_restarts_per_window {
            self.health = EngineHealth::SafeMode;
            return RecoveryIntent::FallbackSafeModel;
        }
        self.restarts_in_window += 1;
        self.backoff_until_ms = now_ms + self.policy.restart_backoff_ms;
        self.health = EngineHealth::Loading;
        RecoveryIntent::RestartEngine
    }

    /// Restart OK: cargando modelo, resetear fallos.
    pub fn on_restart_ok(&mut self) {
        self.consecutive_failures = 0;
        self.health = EngineHealth::Loading;
    }

    /// Modelo listo tras restart.
    pub fn on_model_ready(&mut self) {
        self.health = EngineHealth::Healthy;
        self.restarts_in_window = 0;
        self.backoff_until_ms = 0;
    }
}
