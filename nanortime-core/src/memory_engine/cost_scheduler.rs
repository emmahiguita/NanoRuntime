//! Cost Scheduler — Formal optimization with constraints.
//!
//! Implements the multi-objective cost function:
//!
//!   C = α·RAM_use + β·IO_cost + γ·Energy + δ·Latency
//!
//! Subject to: RSS ≤ RAM_avail, Temp ≤ T_max, Acc_loss ≤ ε, Context ≥ 256
//!
//! This module bridges the PolicyEngine (decisions) with the RuntimeConfig
//! (execution parameters), providing a formal, reproducible selection mechanism.

use crate::memory_engine::auto_config::{KvCompression, PageStrategy, RuntimeConfig};
use crate::memory_engine::policy_engine::{Constraints, CostWeights, Decision, PolicyEngine, QosMode};

/// Snapshot of system state at a point in time.
#[derive(Debug, Clone)]
pub struct SystemState {
    /// Available RAM (MB).
    pub ram_avail_mb: u64,
    /// Total RAM (MB).
    pub ram_total_mb: u64,
    /// CPU temperature (°C). -1 if unavailable.
    pub cpu_temp_c: i32,
    /// Current OOM score.
    pub oom_score: i32,
    /// Whether ZRAM is active.
    pub zram_active: bool,
    /// Current context window (tokens).
    pub current_context: usize,
    /// Current batch size.
    pub current_batch: usize,
}

impl SystemState {
    /// Build from a DeviceProfile and RuntimeConfig.
    pub fn from_device(
        profile: &crate::memory_engine::hardware_hal::DeviceProfile,
        config: &RuntimeConfig,
    ) -> Self {
        Self {
            ram_avail_mb: profile.ram_available_mb,
            ram_total_mb: profile.ram_total_mb,
            cpu_temp_c: profile.cpu_temp_c,
            oom_score: profile.oom_score,
            zram_active: profile.zram_active,
            current_context: config.max_context_tokens,
            current_batch: config.batch_size,
        }
    }
}

/// Result of running the cost scheduler.
#[derive(Debug, Clone)]
pub struct ScheduleResult {
    /// The selected decision.
    pub decision: Decision,
    /// Original system state.
    pub before: SystemState,
    /// Whether the scheduler changed anything.
    pub changed: bool,
    /// Estimated RAM savings (MB).
    pub ram_saved_mb: f64,
    /// Latency impact (ms).
    pub latency_impact_ms: f64,
}

/// Cost Scheduler — selects optimal execution parameters.
///
/// # Usage
///
/// ```ignore
/// let mut scheduler = CostScheduler::new(QosMode::Balanced);
/// let result = scheduler.optimize(&state);
/// if result.changed {
///     config.apply(result.decision);
/// }
/// ```
pub struct CostScheduler {
    engine: PolicyEngine,
    history: Vec<ScheduleResult>,
    convergence_counter: usize,
    stable: bool,
}

impl CostScheduler {
    /// Create a new cost scheduler.
    pub fn new(mode: QosMode) -> Self {
        Self {
            engine: PolicyEngine::new(mode),
            history: Vec::new(),
            convergence_counter: 0,
            stable: false,
        }
    }

    /// Run optimization for the given system state.
    pub fn optimize(&mut self, state: &SystemState) -> ScheduleResult {
        let previous_context = state.current_context;
        let previous_batch = state.current_batch;

        // Generate feasible decisions
        self.engine.generate_decisions(
            state.ram_avail_mb,
            state.ram_total_mb,
            state.cpu_temp_c,
            state.current_context,
        );

        // Select best
        let best = self.engine
            .select_best()
            .cloned()
            .unwrap_or_else(|| Decision {
                kv: KvCompression::Int2,
                context: 256,
                batch: 128,
                page: PageStrategy::Conservative,
                cost: 999.0,
                violates_constraints: false,
                label: "Fallback".into(),
            });

        let changed = best.context != previous_context
            || best.batch != previous_batch;

        // Estimate RAM savings
        let old_kv_mb = previous_context as f64 * 0.03; // Assuming FP16
        let new_kv_mb = match best.kv {
            KvCompression::None => best.context as f64 * 0.03,
            KvCompression::Int8 => best.context as f64 * 0.015,
            KvCompression::Int4 => best.context as f64 * 0.0075,
            KvCompression::Int2 => best.context as f64 * 0.00375,
        };
        let ram_saved = (old_kv_mb - new_kv_mb).max(0.0);

        // Estimate latency impact
        let latency_impact = (best.context as f64 - previous_context as f64) * 0.005;

        let result = ScheduleResult {
            decision: best,
            before: state.clone(),
            changed,
            ram_saved_mb: ram_saved,
            latency_impact_ms: latency_impact,
        };

        // Track convergence
        if !changed {
            self.convergence_counter += 1;
            if self.convergence_counter > 5 {
                self.stable = true;
            }
        } else {
            self.convergence_counter = 0;
            self.stable = false;
        }

        self.history.push(result.clone());
        result
    }

    /// Whether the scheduler has converged (no changes for 5+ cycles).
    pub fn is_stable(&self) -> bool {
        self.stable
    }

    /// Number of scheduling decisions made.
    pub fn decision_count(&self) -> usize {
        self.history.len()
    }

    /// Reset convergence tracking.
    pub fn reset(&mut self) {
        self.convergence_counter = 0;
        self.stable = false;
    }

    /// Switch QoS mode without losing history.
    pub fn set_mode(&mut self, mode: QosMode) {
        self.engine.set_qos(mode);
        self.reset();
    }

    /// Current QoS mode.
    pub fn mode(&self) -> QosMode {
        self.engine.qos_mode()
    }

    /// Get the last schedule result.
    pub fn last_result(&self) -> Option<&ScheduleResult> {
        self.history.last()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::memory_engine::hardware_hal::DeviceProfile;

    fn samsung_state() -> SystemState {
        SystemState {
            ram_avail_mb: 1900,
            ram_total_mb: 3814,
            cpu_temp_c: 42,
            oom_score: 180,
            zram_active: true,
            current_context: 8192,
            current_batch: 512,
        }
    }

    fn oppo_state() -> SystemState {
        SystemState {
            ram_avail_mb: 3900,
            ram_total_mb: 7823,
            cpu_temp_c: 35,
            oom_score: 85,
            zram_active: false,
            current_context: 8192,
            current_batch: 512,
        }
    }

    #[test]
    fn test_samsung_conservative() {
        let mut s = CostScheduler::new(QosMode::Eco);
        let r = s.optimize(&samsung_state());
        // Samsung should NOT keep 8192 context with 1900 MB RAM
        assert!(r.changed);
        assert!(r.ram_saved_mb > 0.0);
    }

    #[test]
    fn test_oppo_produces_valid_schedule() {
        let mut s = CostScheduler::new(QosMode::Performance);
        let r = s.optimize(&oppo_state());
        // OPPO with 3900 MB: should produce some decision
        assert!(r.decision.context > 0);
        assert!(!r.decision.violates_constraints);
    }

    #[test]
    fn test_scheduler_produces_decisions() {
        let mut s = CostScheduler::new(QosMode::Eco);
        let state = SystemState {
            ram_avail_mb: 1000, ram_total_mb: 3814, cpu_temp_c: 35,
            oom_score: 200, zram_active: true, current_context: 512, current_batch: 256,
        };
        let r = s.optimize(&state);
        assert!(r.decision.context > 0);
        assert!(s.decision_count() > 0);
    }

    #[test]
    fn test_mode_switch_resets_convergence() {
        let mut s = CostScheduler::new(QosMode::Eco);
        for _ in 0..7 {
            s.optimize(&oppo_state());
        }
        s.set_mode(QosMode::Performance);
        assert!(!s.is_stable());
    }
}
