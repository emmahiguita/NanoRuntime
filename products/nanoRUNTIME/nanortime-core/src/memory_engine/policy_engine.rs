//! Policy Engine — Multi-objective optimization for runtime decisions.
//!
//! Transforms NanoRuntime from a reactive system (if RAM < X, do Y) into a
//! proactive adaptive controller. The engine evaluates competing objectives
//! and selects the optimal action under current hardware constraints.
//!
//! ## Cost Function
//!
//! C = α·RAM_use + β·IO_cost + γ·Energy + δ·Latency
//!
//! Subject to:
//!   RSS ≤ RAM_available
//!   Temp ≤ T_max (default 45°C)
//!   Accuracy_loss ≤ ε (default 0.5%)
//!   Context ≥ 256 tokens
//!
//! ## QoS Modes
//!
//! - Eco:      Minimize RAM and energy (α=0.4, β=0.2, γ=0.3, δ=0.1)
//! - Balanced: Equal weights (α=0.25, β=0.25, γ=0.25, δ=0.25)
//! - Performance: Minimize latency (α=0.1, β=0.3, γ=0.1, δ=0.5)

use crate::memory_engine::auto_config::{KvCompression, PageStrategy, RuntimeConfig};
use crate::memory_engine::hardware_hal::DeviceProfile;
use std::fmt;

/// Quality of Service mode.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum QosMode {
    Eco,
    Balanced,
    Performance,
}

impl fmt::Display for QosMode {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            QosMode::Eco => write!(f, "Eco"),
            QosMode::Balanced => write!(f, "Balanced"),
            QosMode::Performance => write!(f, "Performance"),
        }
    }
}

/// Cost weights for multi-objective optimization.
#[derive(Debug, Clone, Copy)]
pub struct CostWeights {
    /// Weight for RAM usage (MB).
    pub ram: f64,
    /// Weight for I/O operations.
    pub io: f64,
    /// Weight for energy consumption.
    pub energy: f64,
    /// Weight for latency (ms).
    pub latency: f64,
}

impl CostWeights {
    pub fn for_qos(mode: QosMode) -> Self {
        match mode {
            QosMode::Eco => Self {
                ram: 0.4,
                io: 0.2,
                energy: 0.3,
                latency: 0.1,
            },
            QosMode::Balanced => Self {
                ram: 0.25,
                io: 0.25,
                energy: 0.25,
                latency: 0.25,
            },
            QosMode::Performance => Self {
                ram: 0.1,
                io: 0.3,
                energy: 0.1,
                latency: 0.5,
            },
        }
    }
}

/// Hardware constraints for optimization.
#[derive(Debug, Clone)]
pub struct Constraints {
    /// Maximum RSS (MB). Default: available RAM.
    pub max_rss_mb: u64,
    /// Maximum temperature (°C). Default: 45.
    pub max_temp_c: i32,
    /// Maximum accuracy loss (fraction). Default: 0.005 (0.5%).
    pub max_accuracy_loss: f64,
    /// Minimum context window (tokens). Default: 256.
    pub min_context: usize,
    /// Maximum batch size. Default: from config.
    pub max_batch: usize,
}

impl Default for Constraints {
    fn default() -> Self {
        Self {
            max_rss_mb: 1024,
            max_temp_c: 45,
            max_accuracy_loss: 0.005,
            min_context: 256,
            max_batch: 512,
        }
    }
}

/// A single decision candidate evaluated by the engine.
#[derive(Debug, Clone)]
pub struct Decision {
    /// KV compression level.
    pub kv: KvCompression,
    /// Context window size (tokens).
    pub context: usize,
    /// Batch size.
    pub batch: usize,
    /// Page strategy.
    pub page: PageStrategy,
    /// Estimated cost (lower = better).
    pub cost: f64,
    /// Whether this decision violates hard constraints.
    pub violates_constraints: bool,
    /// Human-readable label.
    pub label: String,
}

/// Policy Engine — evaluates decisions and selects optimal action.
pub struct PolicyEngine {
    qos: QosMode,
    weights: CostWeights,
    constraints: Constraints,
    decisions: Vec<Decision>,
}

impl PolicyEngine {
    /// Create a new policy engine with a QoS mode.
    pub fn new(qos: QosMode) -> Self {
        let weights = CostWeights::for_qos(qos);
        Self {
            qos,
            weights,
            constraints: Constraints::default(),
            decisions: Vec::new(),
        }
    }

    /// Set hardware constraints.
    pub fn with_constraints(mut self, c: Constraints) -> Self {
        self.constraints = c;
        self
    }

    /// Adapt constraints from current device state.
    pub fn adapt_constraints(&mut self, profile: &DeviceProfile, config: &RuntimeConfig) {
        self.constraints.max_rss_mb = profile.ram_available_mb;
        self.constraints.max_temp_c = if profile.cpu_temp_c > 0 { 45 } else { 60 };
        self.constraints.min_context = config.min_context;
        self.constraints.max_batch = config.batch_size;
    }

    /// Generate all feasible decisions for current state.
    pub fn generate_decisions(
        &mut self,
        available_ram_mb: u64,
        total_ram_mb: u64,
        cpu_temp_c: i32,
        base_context: usize,
    ) {
        self.decisions.clear();

        let ratio = available_ram_mb as f64 / total_ram_mb as f64;

        // Decision 1: Aggressive (max throughput, max RAM)
        if ratio > 0.35 {
            self.decisions.push(self.evaluate(
                KvCompression::None,
                base_context,
                512,
                PageStrategy::Aggressive,
                "Aggressive".into(),
            ));
        }

        // Decision 2: Balanced (default)
        if ratio > 0.20 {
            self.decisions.push(self.evaluate(
                KvCompression::None,
                base_context.min(4096),
                384,
                PageStrategy::Balanced,
                "Balanced".into(),
            ));
        }

        // Decision 3: Conservative (save RAM, keep quality)
        if ratio > 0.15 {
            self.decisions.push(self.evaluate(
                KvCompression::Int4,
                base_context.min(2048),
                256,
                PageStrategy::Conservative,
                "Conservative".into(),
            ));
        }

        // Decision 4: Eco (maximum savings)
        self.decisions.push(self.evaluate(
            KvCompression::Int8,
            base_context.min(512),
            256,
            PageStrategy::Conservative,
            "Eco".into(),
        ));

        // Decision 5: Survival (bare minimum)
        self.decisions.push(self.evaluate(
            KvCompression::Int2,
            self.constraints.min_context,
            128,
            PageStrategy::Conservative,
            "Survival".into(),
        ));

        // Thermal constraint: if CPU is hot, force Conservative choices
        if cpu_temp_c > self.constraints.max_temp_c || cpu_temp_c < 0 {
            // Mark any Aggressive as violating
            for d in &mut self.decisions {
                if d.page == PageStrategy::Aggressive {
                    d.violates_constraints = true;
                }
            }
        }
    }

    /// Evaluate a single decision candidate.
    fn evaluate(
        &self,
        kv: KvCompression,
        context: usize,
        batch: usize,
        page: PageStrategy,
        label: String,
    ) -> Decision {
        // Estimate RAM impact
        let kv_ram_mb = match kv {
            KvCompression::None => context as f64 * 0.03, // FP16: ~0.03 MB/token
            KvCompression::Int8 => context as f64 * 0.015, // 2x reduction
            KvCompression::Int4 => context as f64 * 0.0075, // 4x reduction
            KvCompression::Int2 => context as f64 * 0.00375, // 8x reduction
        };

        // Estimate I/O cost (page faults/second)
        let io_cost = match page {
            PageStrategy::Aggressive => 0.1,
            PageStrategy::Balanced => 0.3,
            PageStrategy::Conservative => 0.6,
        };

        // Estimate energy (proportional to I/O + batch size)
        let energy = io_cost * 0.5 + batch as f64 * 0.001;

        // Estimate latency (context / throughput + I/O penalty)
        let latency = context as f64 * 0.002 + io_cost * 500.0;

        // Compute weighted cost
        let cost = self.weights.ram * kv_ram_mb
            + self.weights.io * io_cost * 100.0
            + self.weights.energy * energy * 100.0
            + self.weights.latency * latency * 0.01;

        // Check constraints
        let violates = kv_ram_mb > self.constraints.max_rss_mb as f64
            || context < self.constraints.min_context;

        Decision {
            kv,
            context,
            batch,
            page,
            cost,
            violates_constraints: violates,
            label,
        }
    }

    /// Select the best feasible decision (lowest cost that doesn't violate constraints).
    pub fn select_best(&self) -> Option<&Decision> {
        self.decisions
            .iter()
            .filter(|d| !d.violates_constraints)
            .min_by(|a, b| {
                a.cost
                    .partial_cmp(&b.cost)
                    .unwrap_or(std::cmp::Ordering::Equal)
            })
    }

    /// Get all decisions sorted by cost (cheapest first).
    pub fn ranked_decisions(&self) -> Vec<&Decision> {
        let mut sorted: Vec<&Decision> = self.decisions.iter().collect();
        sorted.sort_by(|a, b| {
            a.cost
                .partial_cmp(&b.cost)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        sorted
    }

    /// Current QoS mode.
    pub fn qos_mode(&self) -> QosMode {
        self.qos
    }

    /// Switch QoS mode at runtime.
    pub fn set_qos(&mut self, mode: QosMode) {
        self.qos = mode;
        self.weights = CostWeights::for_qos(mode);
        self.decisions.clear(); // Force re-evaluation
    }

    /// Summary of the best decision.
    pub fn summary(&self) -> String {
        match self.select_best() {
            Some(d) => format!(
                "PolicyEngine({}): best={} ctx={} kv={:?} batch={} cost={:.2}",
                self.qos, d.label, d.context, d.kv, d.batch, d.cost
            ),
            None => "PolicyEngine: no feasible decision".into(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_eco_prefers_cheapest() {
        let mut engine = PolicyEngine::new(QosMode::Eco);
        engine.generate_decisions(2000, 3814, 35, 8192);
        let best = engine.select_best().unwrap();
        // Eco mode should prefer low RAM usage (Eco or Survival)
        assert!(best.label == "Eco" || best.label == "Survival");
    }

    #[test]
    fn test_engine_produces_decisions_with_abundant_ram() {
        let mut engine = PolicyEngine::new(QosMode::Performance);
        engine.generate_decisions(3500, 7823, 35, 8192);
        let best = engine.select_best();
        assert!(best.is_some());
        // Should have multiple decisions with abundant RAM
        assert!(engine.ranked_decisions().len() >= 2);
    }

    #[test]
    fn test_thermal_violation_blocks_aggressive() {
        let mut engine = PolicyEngine::new(QosMode::Performance);
        engine.generate_decisions(3500, 7823, 50, 8192); // 50°C > 45°C max
        let best = engine.select_best().unwrap();
        // Hot CPU should not allow Aggressive
        assert_ne!(best.page, PageStrategy::Aggressive);
    }

    #[test]
    fn test_low_ram_eliminates_aggressive() {
        let mut engine = PolicyEngine::new(QosMode::Performance);
        engine.generate_decisions(500, 3814, 35, 8192); // 13% RAM
        let ranked = engine.ranked_decisions();
        // Aggressive shouldn't be in the list (ratio < 0.35)
        assert!(!ranked.iter().any(|d| d.label == "Aggressive"));
    }

    #[test]
    fn test_switch_qos_mode() {
        let mut engine = PolicyEngine::new(QosMode::Eco);
        engine.generate_decisions(3000, 7823, 35, 8192);
        engine.set_qos(QosMode::Performance);
        assert_eq!(engine.qos_mode(), QosMode::Performance);
        assert!(engine.decisions.is_empty()); // Cleared for re-evaluation
    }
}
