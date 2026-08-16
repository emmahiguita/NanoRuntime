//! Auto-Config — Boot-time hardware detection and strategy selection.
//!
//! On startup, scans hardware capabilities and generates an optimal
//! runtime configuration without any manual tuning. The same binary
//! adapts to a Samsung A30s (3.72 GB) or a desktop (32 GB) automatically.
//!
//! ## Strategy selection
//!
//! | Device Tier | Context | Batch | KV Compression | Page Strategy |
//! |-------------|---------|-------|----------------|---------------|
//! | Budget      | 512     | 256   | INT4           | Conservative  |
//! | MidRange    | 8192    | 512   | None (FP16)    | Balanced      |
//! | Flagship    | 8192    | 512   | None (FP16)    | Aggressive    |
//! | Desktop     | 8192    | 1024  | None (FP16)    | Aggressive    |
//!
//! All values adjust dynamically at runtime if RAM pressure changes.

use crate::memory_engine::hardware_hal::{DeviceProfile, DeviceTier};

/// Full runtime configuration generated at boot.
#[derive(Debug, Clone)]
pub struct RuntimeConfig {
    /// Maximum KV cache context size (tokens).
    pub max_context_tokens: usize,
    /// Batch size for inference.
    pub batch_size: usize,
    /// KV cache compression level.
    pub kv_compression: KvCompression,
    /// Weight page cache strategy.
    pub page_strategy: PageStrategy,
    /// Enables speculative decoding if device supports it.
    pub speculative_decoding: bool,
    /// Number of threads for inference.
    pub threads: usize,
    /// OOM score threshold to activate survival mode.
    pub oom_threshold: i32,
    /// Minimum free RAM (MB) before Graceful Degradation.
    pub ram_watermark_mb: u64,
    /// Minimum context before abort (tokens).
    pub min_context: usize,
    /// Device tier.
    pub tier: DeviceTier,
    /// Full hardware profile.
    pub profile: DeviceProfile,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum KvCompression {
    None,
    Int8,
    Int4,
    Int2,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum PageStrategy {
    /// Warm weights, keep resident.
    Aggressive,
    /// Warm on load, let kernel manage.
    Balanced,
    /// Warm only active layer.
    Conservative,
}

impl RuntimeConfig {
    /// Generate optimal config from a device profile.
    pub fn from_profile(profile: DeviceProfile) -> Self {
        let tier = profile.tier;

        let (max_ctx, batch, kv_comp, page_strat, speculative, threads) = match tier {
            DeviceTier::Budget => {
                // Samsung A30s: ~1.4 GB usable. Extreme Graceful Degradation.
                let ctx = if profile.ram_available_mb < 1500 {
                    512
                } else if profile.ram_available_mb < 2000 {
                    1024
                } else {
                    2048
                };
                (
                    ctx,
                    256,
                    KvCompression::Int4,
                    PageStrategy::Conservative,
                    false,
                    2,
                )
            }
            DeviceTier::MidRange => {
                // OPPO CPH2557: ~4 GB usable. Full context.
                (
                    8192,
                    512,
                    KvCompression::None,
                    PageStrategy::Balanced,
                    false,
                    4,
                )
            }
            DeviceTier::Flagship => (
                8192,
                512,
                KvCompression::None,
                PageStrategy::Aggressive,
                true,
                profile.cpu_cores as usize / 2,
            ),
            DeviceTier::Desktop => (
                8192,
                1024,
                KvCompression::None,
                PageStrategy::Aggressive,
                true,
                profile.cpu_cores as usize,
            ),
        };

        let oom_threshold = match tier {
            DeviceTier::Budget => 100,
            DeviceTier::MidRange => 150,
            DeviceTier::Flagship => 200,
            DeviceTier::Desktop => 300,
        };

        let ram_watermark = match tier {
            DeviceTier::Budget => 250,
            DeviceTier::MidRange => 500,
            DeviceTier::Flagship => 750,
            DeviceTier::Desktop => 1000,
        };

        Self {
            max_context_tokens: max_ctx,
            batch_size: batch,
            kv_compression: kv_comp,
            page_strategy: page_strat,
            speculative_decoding: speculative,
            threads,
            oom_threshold,
            ram_watermark_mb: ram_watermark,
            min_context: 256,
            tier,
            profile,
        }
    }

    /// Adjust config if available RAM is too low.
    #[cfg(feature = "unstable")]
    pub fn adapt_to_ram(&mut self, available_mb: u64, total_mb: u64) {
        let ratio = available_mb as f64 / total_mb as f64;

        if ratio < 0.10 {
            // Critical: bare minimum
            self.max_context_tokens = self.max_context_tokens.min(256);
            self.batch_size = self.batch_size.min(128);
            self.kv_compression = KvCompression::Int2;
            self.page_strategy = PageStrategy::Conservative;
        } else if ratio < 0.20 {
            // High pressure
            self.max_context_tokens = self.max_context_tokens.min(512);
            self.batch_size = self.batch_size.min(256);
            self.kv_compression = KvCompression::Int4;
        } else if ratio < 0.35 {
            // Moderate pressure
            self.kv_compression = KvCompression::Int8;
        }
        // >35%: keep original config
    }

    /// Whether the device can run 7B models.
    #[cfg(feature = "unstable")]
    pub fn can_run_7b(&self) -> bool {
        self.profile.ram_available_mb > 2500
    }

    /// Whether 7B can run with extreme Graceful Degradation.
    #[cfg(feature = "unstable")]
    pub fn can_run_7b_degraded(&self) -> bool {
        self.profile.ram_available_mb > 1400
    }

    /// Summary for logging.
    #[cfg(feature = "unstable")]
    pub fn summary(&self) -> String {
        format!(
            "AutoConfig: tier={} ctx={} batch={} kv={:?} page={:?} spec={} threads={} oom_thresh={} watermark={}MB can_7b={}",
            self.tier,
            self.max_context_tokens,
            self.batch_size,
            self.kv_compression,
            self.page_strategy,
            self.speculative_decoding,
            self.threads,
            self.oom_threshold,
            self.ram_watermark_mb,
            self.can_run_7b()
        )
    }
}

#[cfg(all(test, feature = "unstable"))]
mod tests {
    use super::*;
    use crate::memory_engine::hardware_hal::DeviceProfile;

    fn samsung_profile() -> DeviceProfile {
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
            tier: DeviceTier::Budget,
            oom_score: 180,
            oom_score_adj: 0,
        }
    }

    fn oppo_profile() -> DeviceProfile {
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
            tier: DeviceTier::MidRange,
            oom_score: 85,
            oom_score_adj: 0,
        }
    }

    #[test]
    fn test_samsung_budget_config() {
        let cfg = RuntimeConfig::from_profile(samsung_profile());
        assert_eq!(cfg.tier, DeviceTier::Budget);
        assert_eq!(cfg.batch_size, 256);
        assert_eq!(cfg.kv_compression, KvCompression::Int4);
        assert!(!cfg.speculative_decoding);
        assert!(cfg.can_run_7b_degraded());
        assert!(!cfg.can_run_7b());
    }

    #[test]
    fn test_oppo_midrange_config() {
        let cfg = RuntimeConfig::from_profile(oppo_profile());
        assert_eq!(cfg.tier, DeviceTier::MidRange);
        assert_eq!(cfg.max_context_tokens, 8192);
        assert_eq!(cfg.batch_size, 512);
        assert_eq!(cfg.kv_compression, KvCompression::None);
        assert!(cfg.can_run_7b());
    }

    #[test]
    fn test_adapt_to_ram_critical() {
        let mut cfg = RuntimeConfig::from_profile(samsung_profile());
        cfg.adapt_to_ram(300, 3814); // 7.8% RAM
        assert_eq!(cfg.max_context_tokens, 256);
        assert_eq!(cfg.kv_compression, KvCompression::Int2);
    }

    #[test]
    fn test_adapt_to_ram_moderate() {
        let mut cfg = RuntimeConfig::from_profile(samsung_profile());
        cfg.adapt_to_ram(900, 3814); // 23.6% RAM -> Int8
        assert_eq!(cfg.kv_compression, KvCompression::Int8);
    }

    #[test]
    fn test_adapt_to_ram_abundant() {
        let mut cfg = RuntimeConfig::from_profile(oppo_profile());
        let orig = cfg.kv_compression;
        cfg.adapt_to_ram(3500, 7823); // 44% RAM
        assert_eq!(cfg.kv_compression, orig); // No change
    }
}
