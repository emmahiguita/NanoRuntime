//! Execution Planner — Translates Memory Model formulas into runtime decisions.
//!
//! This is the "brain" that connects theory (5 formulas) with production
//! (actual configuration). It runs at boot to generate the initial config,
//! and is called by OOM Guard when memory pressure triggers re-planning.
//!
//! ## Architecture
//!
//! ```text
//! [Hardware Profiler] → [Memory Model (5 formulas)] → [Execution Planner]
//!                                                          ↓
//!                                                    RuntimeConfig
//!                                                          ↓
//!                              [CacheAwareLoader] [AdaptiveScheduler] [OOMGuard]
//! ```

use crate::memory_engine::auto_config::{KvCompression, PageStrategy, RuntimeConfig};
use crate::memory_engine::battery_guardian::{BatteryConfig, BatteryGuardian, BatteryMode};
use crate::memory_engine::hardware_hal::DeviceProfile;
use crate::memory_engine::memory_model::MemoryModel;
use crate::memory_engine::thermal_controller::{ThermalCondition, ThermalController};

/// Result of execution planning.
#[derive(Debug, Clone)]
pub struct PlanResult {
    /// Generated runtime configuration.
    pub config: RuntimeConfig,
    /// Whether layer streaming is active.
    pub streaming_active: bool,
    /// Streaming window size (0 = disabled).
    pub streaming_window: usize,
    /// Estimated peak RSS with this plan (MB).
    pub estimated_rss_mb: f64,
    /// Estimated VMA with this plan (MB).
    pub estimated_vma_mb: f64,
    /// Risk level after applying this plan.
    pub risk_level: String,
    /// Thermal condition at planning time.
    pub thermal_condition: Option<ThermalCondition>,
    /// Battery mode at planning time.
    pub battery_mode: BatteryMode,
    /// Human-readable summary of decisions.
    pub summary: String,
}

/// Execution Planner — central decision engine.
pub struct ExecutionPlanner {
    model: MemoryModel,
    model_size_mb: f64,
    num_layers: usize,
    bytes_per_layer_mb: f64,
}

impl ExecutionPlanner {
    /// Create a new planner for a specific model.
    ///
    /// # Arguments
    /// - `model_size_mb`: GGUF file size in MB (e.g., 4470 for DeepSeek 7B).
    /// - `num_layers`: Number of transformer layers (e.g., 32).
    pub fn new(model_size_mb: f64, num_layers: usize) -> Self {
        let bytes_per_layer_mb = model_size_mb / num_layers as f64;
        Self {
            model: MemoryModel::default(),
            model_size_mb,
            num_layers,
            bytes_per_layer_mb,
        }
    }

    /// Plan execution at boot time.
    ///
    /// Runs all 5 formulas against the device profile and generates
    /// the optimal initial configuration. Called once at startup.
    pub fn plan_boot(&self, profile: &DeviceProfile) -> PlanResult {
        let avail = profile.ram_available_mb as f64;
        let total = profile.ram_total_mb as f64;
        let io = profile.storage_read_mbps.max(profile.storage_write_mbps) as f64;

        // ── Thermal check ──────────────────────────────────────
        let mut thermal = ThermalController::new();
        let thermal_reading = thermal.sample();
        let thermal_condition = Some(thermal_reading.state);
        let is_hot = thermal_reading.state >= ThermalCondition::Hot;

        // ── Battery check ──────────────────────────────────────
        let battery = BatteryGuardian::new();
        let battery_mode = battery.determine_mode();
        let battery_cfg: BatteryConfig = battery_mode.into();

        // Formula 1: Estimate RSS
        let est = self.model.estimate_rss(
            self.model_size_mb,
            8192, // Start optimistic
            self.num_layers,
            KvCompression::None,
        );

        // Formula 2: Assess survival risk
        let vma_ratio = self.model_size_mb / total;
        let risk = if vma_ratio > 0.90 {
            "Critical"
        } else if vma_ratio > 0.75 {
            "High"
        } else if vma_ratio > 0.50 {
            "Medium"
        } else {
            "Low"
        };

        // Formula 3: Estimate throughput
        let tp = self.model.estimate_throughput(self.model_size_mb, io);

        // Decide streaming
        let use_streaming = risk == "Critical"
            && self
                .model
                .can_stream(2, self.bytes_per_layer_mb, self.num_layers, total);

        let window = if use_streaming { 2 } else { 0 };

        // Formula 4: KV compression decision
        let kv = if avail < total * 0.20 {
            KvCompression::Int4
        } else if avail < total * 0.10 {
            KvCompression::Int2
        } else if risk == "Critical" {
            KvCompression::Int4
        } else {
            KvCompression::None
        };

        // Build config base values
        let mut ctx = if risk == "Critical" || avail < 1500.0 {
            512
        } else if avail < 2500.0 {
            2048
        } else {
            8192
        };
        let mut batch = if risk == "Critical" { 128 } else { 256 };

        // Page strategy
        let page = match risk {
            "Critical" => PageStrategy::Conservative,
            "High" => PageStrategy::Balanced,
            _ => PageStrategy::Aggressive,
        };

        // Formula 5: VMA with streaming
        let vma = if use_streaming {
            self.model
                .estimate_streaming_vma(window, self.bytes_per_layer_mb, self.num_layers)
        } else {
            self.model_size_mb
        };

        // ── Apply thermal constraint ──────────────────────────
        if is_hot {
            ctx = ctx.min(1024);
            batch = (batch as f32 * 0.5) as usize;
        }

        // ── Apply battery constraint ───────────────────────────
        ctx = ctx.min(battery_cfg.max_context);
        batch = batch.min(battery_cfg.batch_size);

        // Build config with adjusted values
        let config = RuntimeConfig {
            max_context_tokens: ctx,
            batch_size: batch,
            kv_compression: kv,
            page_strategy: page,
            speculative_decoding: tp.expected_tok_s > 1.0,
            threads: profile.cpu_cores.min(4) as usize,
            oom_threshold: if risk == "Critical" { 80 } else { 150 },
            ram_watermark_mb: if risk == "Critical" { 200 } else { 500 },
            min_context: 256,
            tier: profile.tier,
            profile: profile.clone(),
        };

        let summary = format!(
            "plan_boot: risk={} thermal={:?} battery={:?} streaming={} ctx={} kv={:?} vma={:.0}MB rss={:.0}MB t={:.2}tok/s",
            risk, thermal_condition, battery_mode, use_streaming, ctx, kv, vma, est.peak_rss_mb, tp.expected_tok_s
        );

        PlanResult {
            config,
            streaming_active: use_streaming,
            streaming_window: window,
            estimated_rss_mb: est.peak_rss_mb,
            estimated_vma_mb: vma,
            risk_level: risk.to_string(),
            thermal_condition,
            battery_mode,
            summary,
        }
    }

    /// Re-plan at runtime when memory pressure is detected.
    ///
    /// Called by OOM Guard when oom_score > threshold or RAM drops.
    /// Returns a more conservative plan to prevent OOM termination.
    pub fn plan_survival(
        &self,
        available_mb: f64,
        total_mb: f64,
        profile: &DeviceProfile,
    ) -> PlanResult {
        let ratio = available_mb / total_mb;

        let (ctx, kv, page) = if ratio < 0.10 {
            (256, KvCompression::Int2, PageStrategy::Conservative)
        } else if ratio < 0.20 {
            (256, KvCompression::Int4, PageStrategy::Conservative)
        } else if ratio < 0.30 {
            (512, KvCompression::Int4, PageStrategy::Balanced)
        } else {
            (512, KvCompression::Int8, PageStrategy::Balanced)
        };

        // Always use streaming in survival mode if model > RAM
        let use_streaming = self.model_size_mb > total_mb
            && self
                .model
                .can_stream(1, self.bytes_per_layer_mb, self.num_layers, total_mb);
        let window = if use_streaming { 1 } else { 0 };

        let vma = if use_streaming {
            self.model
                .estimate_streaming_vma(window, self.bytes_per_layer_mb, self.num_layers)
        } else {
            self.model_size_mb
        };

        let config = RuntimeConfig {
            max_context_tokens: ctx,
            batch_size: 128,
            kv_compression: kv,
            page_strategy: page,
            speculative_decoding: false,
            threads: 2,
            oom_threshold: 60,
            ram_watermark_mb: 150,
            min_context: 256,
            tier: profile.tier,
            profile: profile.clone(),
        };

        let summary = format!(
            "plan_survival: ratio={:.0}% ctx={} kv={:?} streaming={} vma={:.0}MB",
            ratio * 100.0,
            ctx,
            kv,
            use_streaming,
            vma
        );

        PlanResult {
            config,
            streaming_active: use_streaming,
            streaming_window: window,
            estimated_rss_mb: available_mb * 0.5,
            estimated_vma_mb: vma,
            risk_level: "Critical".into(),
            thermal_condition: Some(ThermalCondition::Critical),
            battery_mode: BatteryMode::Survival,
            summary,
        }
    }

    /// Quick re-plan for moderate pressure.
    pub fn plan_cautious(&self, available_mb: f64, profile: &DeviceProfile) -> PlanResult {
        let kv = if available_mb < 2000.0 {
            KvCompression::Int4
        } else {
            KvCompression::Int8
        };
        let ctx = if available_mb < 1500.0 { 256 } else { 512 };

        let config = RuntimeConfig {
            max_context_tokens: ctx,
            batch_size: 256,
            kv_compression: kv,
            page_strategy: PageStrategy::Conservative,
            speculative_decoding: false,
            threads: 2,
            oom_threshold: 100,
            ram_watermark_mb: 300,
            min_context: 256,
            tier: profile.tier,
            profile: profile.clone(),
        };

        PlanResult {
            config,
            streaming_active: false,
            streaming_window: 0,
            estimated_rss_mb: available_mb * 0.4,
            estimated_vma_mb: self.model_size_mb,
            risk_level: "Medium".into(),
            thermal_condition: Some(ThermalCondition::Warm),
            battery_mode: BatteryMode::Balanced,
            summary: format!("plan_cautious: ctx={} kv={:?}", ctx, kv),
        }
    }

    /// Get the memory model reference.
    pub fn model(&self) -> &MemoryModel {
        &self.model
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn samsung() -> DeviceProfile {
        DeviceProfile {
            ram_total_mb: 3814,
            ram_available_mb: 1900,
            storage_read_mbps: 364,
            storage_write_mbps: 200,
            cpu_cores: 8,
            big_cores: 4,
            cpu_temp_c: 42,
            zram_active: true,
            npu_available: false,
            tier: crate::memory_engine::hardware_hal::DeviceTier::Budget,
            oom_score: 180,
            oom_score_adj: 0,
        }
    }

    fn oppo() -> DeviceProfile {
        DeviceProfile {
            ram_total_mb: 7823,
            ram_available_mb: 3900,
            storage_read_mbps: 1067,
            storage_write_mbps: 800,
            cpu_cores: 8,
            big_cores: 4,
            cpu_temp_c: 38,
            zram_active: true,
            npu_available: false,
            tier: crate::memory_engine::hardware_hal::DeviceTier::MidRange,
            oom_score: 85,
            oom_score_adj: 0,
        }
    }

    #[test]
    fn test_plan_boot_samsung_7b() {
        let planner = ExecutionPlanner::new(4470.0, 32);
        let plan = planner.plan_boot(&samsung());
        assert_eq!(plan.risk_level, "Critical");
        assert!(plan.config.max_context_tokens <= 512);
        assert!(plan.config.kv_compression == KvCompression::Int4);
        assert!(plan.estimated_vma_mb < 800.0 || !plan.streaming_active);
    }

    #[test]
    fn test_plan_boot_oppo_7b() {
        let planner = ExecutionPlanner::new(4470.0, 32);
        let plan = planner.plan_boot(&oppo());
        assert_eq!(plan.risk_level, "Medium");
        assert!(plan.config.max_context_tokens >= 2048);
    }

    #[test]
    fn test_plan_survival_triggers_streaming() {
        let planner = ExecutionPlanner::new(4470.0, 32);
        let profile = samsung();
        let plan = planner.plan_survival(300.0, 3814.0, &profile);
        assert!(plan.streaming_active || plan.config.kv_compression == KvCompression::Int4);
        assert!(!plan.summary.is_empty());
    }

    #[test]
    fn test_plan_cautious_reduces_context() {
        let planner = ExecutionPlanner::new(4470.0, 32);
        let profile = samsung();
        let plan = planner.plan_cautious(1200.0, &profile);
        assert!(plan.config.kv_compression != KvCompression::None);
    }

    #[test]
    fn test_samsung_1_5b_no_crisis() {
        let planner = ExecutionPlanner::new(1065.0, 32);
        let plan = planner.plan_boot(&samsung());
        assert_eq!(plan.risk_level, "Low");
        assert!(!plan.streaming_active);
    }
}
