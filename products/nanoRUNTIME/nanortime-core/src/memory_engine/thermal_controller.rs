//! Thermal Controller — Prevents thermal throttling and device overheating.
//!
//! Reads /sys/class/thermal/ to monitor CPU/GPU/SOC temperature.
//! When temperature exceeds thresholds, reduces inference workload
//! to let the device cool down. Prevents Android's thermal-engine from
//! killing the process.
//!
//! ## Strategy
//!
//! | Temp Range    | Action                                    |
//! |---------------|-------------------------------------------|
//! | < 35°C        | Normal operation                          |
//! | 35-42°C       | Reduce batch size by 25%                  |
//! | 42-48°C       | Reduce context + batch, insert cooldown pauses |
//! | > 48°C        | Pause inference, wait for cooldown, retry |

use std::fs;

/// Thermal condition of the device.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum ThermalCondition {
    Cool,
    Warm,
    Hot,
    Critical,
}

/// Current thermal reading.
#[derive(Debug, Clone)]
pub struct ThermalReading {
    /// Maximum temperature across all thermal zones (°C).
    pub max_temp_c: f32,
    /// Whether `max_temp_c` came from a physical sensor. A value of `0.0`
    /// must not be interpreted as a real temperature when this is false.
    pub sensor_available: bool,
    /// Whether the device is currently throttling.
    pub is_throttling: bool,
    /// Current thermal state.
    pub state: ThermalCondition,
    /// Number of active cooling pauses in the last minute.
    pub cooldown_count: usize,
}

/// Thermal Controller — prevents overheating during inference.
pub struct ThermalController {
    /// History of temperatures for trend detection.
    temp_history: Vec<f32>,
    /// Number of cooldown pauses in the current window.
    cooldown_count: usize,
    /// Maximum observed temperature.
    max_observed: f32,
}

impl ThermalController {
    pub fn new() -> Self {
        Self {
            temp_history: Vec::with_capacity(60),
            cooldown_count: 0,
            max_observed: 0.0,
        }
    }
}

impl Default for ThermalController {
    fn default() -> Self {
        Self::new()
    }
}

impl ThermalController {
    fn normalize_temp(raw: f32) -> Option<f32> {
        if !raw.is_finite() {
            return None;
        }
        // Linux thermal zones normally expose milli-degrees, while a few
        // Android kernels expose degrees directly.
        let temp_c = if raw.abs() >= 1_000.0 {
            raw / 1_000.0
        } else {
            raw
        };
        (-20.0..=150.0).contains(&temp_c).then_some(temp_c)
    }

    /// Read all thermal zones and return the maximum temperature.
    pub fn read_max_temp() -> Option<f32> {
        let mut max_temp: Option<f32> = None;

        for i in 0..20 {
            let path = format!("/sys/class/thermal/thermal_zone{}/temp", i);
            if let Ok(content) = fs::read_to_string(&path) {
                if let Ok(temp_milli) = content.trim().parse::<f32>() {
                    if let Some(temp_c) = Self::normalize_temp(temp_milli) {
                        max_temp = Some(max_temp.map_or(temp_c, |current| current.max(temp_c)));
                    }
                }
            }
        }
        max_temp
    }

    /// Sample the current thermal state.
    pub fn sample(&mut self) -> ThermalReading {
        let measured_temp = Self::read_max_temp();
        let temp = measured_temp.unwrap_or(0.0);

        // Missing permissions/sensors must not inject a fictional sample into
        // trend or throttling decisions.
        if measured_temp.is_some() {
            self.temp_history.push(temp);
            if self.temp_history.len() > 30 {
                self.temp_history.remove(0);
            }
            if temp > self.max_observed {
                self.max_observed = temp;
            }
        }

        // Classify state
        let state = if temp > 48.0 {
            ThermalCondition::Critical
        } else if temp > 42.0 {
            ThermalCondition::Hot
        } else if temp > 35.0 {
            ThermalCondition::Warm
        } else {
            ThermalCondition::Cool
        };

        // Update cooldown counter: increment when hot/critical, decay when cool.
        // Prevents permanent Cooldown state (previously cooldown_count was never
        // incremented, so the controller never transitioned Cooldown→Normal).
        match state {
            ThermalCondition::Hot | ThermalCondition::Critical => {
                self.cooldown_count = self.cooldown_count.saturating_add(1);
            }
            ThermalCondition::Cool => {
                self.cooldown_count = self.cooldown_count.saturating_sub(1);
            }
            ThermalCondition::Warm => {
                // Decay slowly — one decrement per 3 warm samples
                if self.cooldown_count > 0 && self.temp_history.len().is_multiple_of(3) {
                    self.cooldown_count = self.cooldown_count.saturating_sub(1);
                }
            }
        }

        // Detect if Android is already throttling
        let is_throttling = self.temp_history.len() >= 5
            && self.temp_history.iter().rev().take(5).sum::<f32>() / 5.0 > 42.0;

        ThermalReading {
            max_temp_c: temp,
            sensor_available: measured_temp.is_some(),
            is_throttling,
            state,
            cooldown_count: self.cooldown_count,
        }
    }

    /// Get the recommended action based on current thermal state.
    pub fn recommend_action(&self, reading: &ThermalReading) -> ThermalAction {
        match reading.state {
            ThermalCondition::Cool => ThermalAction::Normal,
            ThermalCondition::Warm => ThermalAction::ReduceBatch { factor: 0.75 },
            ThermalCondition::Hot => ThermalAction::Cooldown {
                pause_ms: 50,
                reduce_context: 0.5,
            },
            ThermalCondition::Critical => ThermalAction::Pause {
                pause_ms: 200,
                min_context: 256,
            },
        }
    }

    /// Check if the device has been consistently hot (trend analysis).
    pub fn is_trending_hot(&self) -> bool {
        if self.temp_history.len() < 10 {
            return false;
        }
        let recent: f32 = self.temp_history.iter().rev().take(5).sum::<f32>() / 5.0;
        let older: f32 = self.temp_history.iter().take(5).sum::<f32>() / 5.0;
        recent > older + 2.0 // Rising more than 2°C
    }

    /// Get the maximum temperature ever observed.
    pub fn max_ever(&self) -> f32 {
        self.max_observed
    }
}

/// Action recommended by the thermal controller.
#[derive(Debug, Clone)]
pub enum ThermalAction {
    /// No action needed.
    Normal,
    /// Reduce batch size by a factor (e.g., 0.75 = 25% reduction).
    ReduceBatch { factor: f32 },
    /// Insert cooldown pauses between tokens and reduce context.
    Cooldown { pause_ms: u64, reduce_context: f32 },
    /// Pause inference entirely for cooldown, then resume at min context.
    Pause { pause_ms: u64, min_context: usize },
}

// ── Trait implementation: TemperatureSensor ─────────────────────
use crate::memory_engine::traits::TemperatureSensor;

impl TemperatureSensor for ThermalController {
    fn sample(&mut self) -> Option<ThermalReading> {
        Some(ThermalController::sample(self))
    }

    fn recommend_action(&self, reading: &ThermalReading) -> ThermalAction {
        ThermalController::recommend_action(self, reading)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_thermal_states() {
        let mut tc = ThermalController::new();
        // Manually set temp history for testing
        tc.temp_history = vec![30.0, 31.0, 32.0, 33.0, 34.0];
        let reading = ThermalReading {
            max_temp_c: 33.0,
            sensor_available: true,
            is_throttling: false,
            state: ThermalCondition::Cool,
            cooldown_count: 0,
        };
        let action = tc.recommend_action(&reading);
        assert!(matches!(action, ThermalAction::Normal));
    }

    #[test]
    fn test_critical_triggers_pause() {
        let tc = ThermalController::new();
        let reading = ThermalReading {
            max_temp_c: 50.0,
            sensor_available: true,
            is_throttling: true,
            state: ThermalCondition::Critical,
            cooldown_count: 0,
        };
        let action = tc.recommend_action(&reading);
        assert!(matches!(action, ThermalAction::Pause { .. }));
    }

    #[test]
    fn test_trend_detection() {
        let mut tc = ThermalController::new();
        tc.temp_history = vec![30.0; 5]; // Older: 30
        tc.temp_history.extend(vec![35.0; 5]); // Recent: 35
        assert!(tc.is_trending_hot());
    }

    #[test]
    fn normalizes_kernel_temperature_units_and_rejects_invalid_values() {
        assert_eq!(ThermalController::normalize_temp(42_500.0), Some(42.5));
        assert_eq!(ThermalController::normalize_temp(42.5), Some(42.5));
        assert_eq!(ThermalController::normalize_temp(999_999.0), None);
        assert_eq!(ThermalController::normalize_temp(f32::NAN), None);
    }
}
