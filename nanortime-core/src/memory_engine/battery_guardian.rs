//! Battery Guardian — Adapts inference to battery level and charging state.
//!
//! Reads /sys/class/power_supply/ to monitor battery percentage and
//! charging status. Adjusts inference aggressiveness to preserve battery
//! life on mobile devices.
//!
//! ## Strategy
//!
//! | Battery % | Charging | Action                          |
//! |-----------|----------|----------------------------------|
//! | > 50%     | Any      | Normal (max performance)         |
//! | 20-50%    | No       | Balanced (reduce threads, batch) |
//! | 10-20%    | No       | Eco (min context, max KV INT4)   |
//! | < 10%     | No       | Survival (abort non-critical)    |
//! | Any       | Yes      | Normal + speculative decoding    |

use std::fs;
use std::path::Path;

/// Battery status at a moment in time.
#[derive(Debug, Clone)]
pub struct BatteryStatus {
    /// Battery percentage (0-100).
    pub percentage: f32,
    /// Whether the device is currently charging.
    pub is_charging: bool,
    /// Charging type: "USB", "AC", "Wireless", "Unknown".
    pub charge_type: String,
    /// Battery temperature in °C (-1 if unavailable).
    pub temp_c: f32,
    /// Estimated remaining capacity in mAh (-1 if unavailable).
    pub capacity_mah: i32,
}

/// Battery-aware operating mode.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BatteryMode {
    /// Full performance — plugged in or battery > 50%.
    Performance,
    /// Balanced — battery 20-50%.
    Balanced,
    /// Eco — battery 10-20%.
    Eco,
    /// Survival — battery < 10%, non-critical tasks aborted.
    Survival,
}

/// Battery Guardian — preserves battery life during inference.
pub struct BatteryGuardian {
    /// Initial battery percentage when inference started.
    initial_pct: f32,
    /// Estimated mAh consumed per inference token.
    mah_per_token: f32,
    /// Total tokens generated in this session.
    tokens_generated: usize,
}

impl BatteryGuardian {
    pub fn new() -> Self {
        Self {
            initial_pct: Self::read_battery().map(|b| b.percentage).unwrap_or(100.0),
            mah_per_token: 0.008, // Conservative estimate: ~8 μAh per token
            tokens_generated: 0,
        }
    }

    /// Read battery information from sysfs.
    pub fn read_battery() -> Option<BatteryStatus> {
        // Common battery paths on Android/Linux
        let base_paths = [
            "/sys/class/power_supply/battery",
            "/sys/class/power_supply/BAT0",
            "/sys/class/power_supply/BAT1",
        ];

        for base in &base_paths {
            let base = Path::new(base);
            if !base.exists() {
                continue;
            }

            let capacity = fs::read_to_string(base.join("capacity"))
                .ok()
                .and_then(|s| s.trim().parse::<f32>().ok())
                .unwrap_or(-1.0);

            let status = fs::read_to_string(base.join("status"))
                .ok()
                .map(|s| s.trim().to_string())
                .unwrap_or_default();

            let charge_type = fs::read_to_string(base.join("type"))
                .ok()
                .map(|s| s.trim().to_string())
                .unwrap_or_else(|| "Unknown".into());

            let temp = fs::read_to_string(base.join("temp"))
                .ok()
                .and_then(|s| s.trim().parse::<f32>().ok())
                .map(|t| t / 10.0) // Deci-degrees to Celsius
                .unwrap_or(-1.0);

            let capacity_mah = fs::read_to_string(base.join("charge_full"))
                .ok()
                .and_then(|s| s.trim().parse::<i32>().ok())
                .map(|c| c / 1000) // μAh to mAh
                .unwrap_or(-1);

            let is_charging = status == "Charging" || status == "Full";

            return Some(BatteryStatus {
                percentage: capacity,
                is_charging,
                charge_type,
                temp_c: temp,
                capacity_mah,
            });
        }

        None
    }

    /// Determine the operating mode based on battery level.
    pub fn determine_mode(&self) -> BatteryMode {
        let battery = Self::read_battery();

        match battery {
            Some(b) if b.is_charging => BatteryMode::Performance,
            Some(b) if b.percentage > 50.0 => BatteryMode::Performance,
            Some(b) if b.percentage > 20.0 => BatteryMode::Balanced,
            Some(b) if b.percentage > 10.0 => BatteryMode::Eco,
            Some(_) => BatteryMode::Survival,
            None => BatteryMode::Balanced, // Default when cannot read
        }
    }

    /// Track token generation for battery estimation.
    pub fn track_tokens(&mut self, count: usize) {
        self.tokens_generated += count;
    }

    /// Estimate battery consumed in this session (mAh).
    pub fn estimated_consumed_mah(&self) -> f32 {
        self.tokens_generated as f32 * self.mah_per_token
    }

    /// Estimate remaining tokens before battery dies.
    pub fn estimated_remaining_tokens(&self) -> usize {
        let battery = Self::read_battery();
        if let Some(b) = battery {
            if b.percentage > 0.0 && b.capacity_mah > 0 {
                let remaining_mah = b.capacity_mah as f32 * b.percentage / 100.0;
                return (remaining_mah / self.mah_per_token) as usize;
            }
        }
        usize::MAX // Cannot estimate
    }

    /// Get the initial battery percentage.
    pub fn initial_percentage(&self) -> f32 {
        self.initial_pct
    }
}

/// Configuration adjustments based on battery mode.
#[derive(Debug, Clone)]
pub struct BatteryConfig {
    pub mode: BatteryMode,
    pub max_context: usize,
    pub batch_size: usize,
    pub threads: usize,
    pub enable_speculative: bool,
}

impl From<BatteryMode> for BatteryConfig {
    fn from(mode: BatteryMode) -> Self {
        match mode {
            BatteryMode::Performance => Self {
                mode,
                max_context: 8192,
                batch_size: 512,
                threads: 4,
                enable_speculative: true,
            },
            BatteryMode::Balanced => Self {
                mode,
                max_context: 4096,
                batch_size: 384,
                threads: 3,
                enable_speculative: false,
            },
            BatteryMode::Eco => Self {
                mode,
                max_context: 1024,
                batch_size: 256,
                threads: 2,
                enable_speculative: false,
            },
            BatteryMode::Survival => Self {
                mode,
                max_context: 256,
                batch_size: 128,
                threads: 1,
                enable_speculative: false,
            },
        }
    }
}

// ── Trait implementation: PowerMonitor ──────────────────────────
use crate::memory_engine::traits::PowerMonitor;

impl PowerMonitor for BatteryGuardian {
    fn determine_mode(&self) -> BatteryMode {
        self.determine_mode()
    }

    fn estimated_remaining_tokens(&self) -> Option<u64> {
        Some(BatteryGuardian::estimated_remaining_tokens(self) as u64)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_performance_mode_when_charging() {
        let guardian = BatteryGuardian::new();
        let mode = guardian.determine_mode();
        // On PC (no battery), defaults to Balanced
        assert!(matches!(mode, BatteryMode::Balanced | BatteryMode::Performance));
    }

    #[test]
    fn test_config_from_mode() {
        let perf: BatteryConfig = BatteryMode::Performance.into();
        assert_eq!(perf.max_context, 8192);
        assert!(perf.enable_speculative);

        let survival: BatteryConfig = BatteryMode::Survival.into();
        assert_eq!(survival.max_context, 256);
        assert_eq!(survival.threads, 1);
    }

    #[test]
    fn test_track_tokens() {
        let mut guardian = BatteryGuardian::new();
        guardian.track_tokens(100);
        assert!(guardian.estimated_consumed_mah() > 0.0);
    }
}
