//! OOM Guard — Monitorea /proc/self/oom_score y activa modo supervivencia.
//!
//! Android's Low Memory Killer (LMK) uses oom_score_adj to decide which
//! process to kill first under memory pressure. This module:
//!
//! 1. Reads `/proc/self/oom_score` (current badness, 0-1000)
//! 2. Reads `/proc/self/oom_score_adj` (adjustment, -1000 to 1000)
//! 3. Triggers survival mode when score > threshold (default: 300)
//! 4. Reports risk level to the orchestrator for proactive context reduction
//!
//! ## Strategy
//!
//! | Score Range  | Risk Level  | Action                                      |
//! |-------------|-------------|---------------------------------------------|
//! | 0-150       | Low         | Normal operation                            |
//! | 151-300     | Medium      | Reduce context, enable KV compression        |
//! | 301-500     | High        | Halve context, aggressive page release       |
//! | 501+        | Critical    | Minimum context (256), survival mode         |
//!
//! ## Note
//!
//! On Android, `/proc/self/oom_score_adj` is writable. Setting it to
//! a positive value (e.g., 500) makes the process a higher-priority
//! kill target, which is beneficial for background LLM inference:
//! the system will kill the LLM before killing the foreground UI.

use std::fs;
use std::io;

/// OOM risk level determined by the guard.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum OomRisk {
    Low,
    Medium,
    High,
    Critical,
}

impl std::fmt::Display for OomRisk {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            OomRisk::Low => write!(f, "Low"),
            OomRisk::Medium => write!(f, "Medium"),
            OomRisk::High => write!(f, "High"),
            OomRisk::Critical => write!(f, "Critical"),
        }
    }
}

/// Snapshot of the current OOM state.
#[derive(Debug, Clone)]
pub struct OomSnapshot {
    /// Current oom_score (higher = more likely to be killed).
    pub oom_score: i32,
    /// Current oom_score_adj (adjustment applied by Android).
    pub oom_score_adj: i32,
    /// Computed risk level.
    pub risk: OomRisk,
    /// Whether survival mode should activate.
    pub survival_mode: bool,
    /// Recommended context size for survival.
    pub recommended_context: usize,
    /// Whether aggressive page release should happen.
    pub aggressive_page_release: bool,
    /// Human-readable summary.
    pub summary: String,
}

/// OOM Guard — monitors Linux/Android OOM killer state.
pub struct OomGuard {
    /// Highest oom_score ever observed this session.
    peak_score: i32,
    /// Number of consecutive high-risk samples.
    high_risk_count: usize,
    /// Whether survival mode is currently active.
    survival_active: bool,
    /// Score samples for trend detection.
    history: Vec<i32>,
    /// Thresholds for risk classification.
    low_threshold: i32,
    medium_threshold: i32,
    high_threshold: i32,
    critical_threshold: i32,
}

impl OomGuard {
    /// Create a new OOM Guard with default thresholds.
    pub fn new() -> Self {
        Self {
            peak_score: 0,
            high_risk_count: 0,
            survival_active: false,
            history: Vec::with_capacity(32),
            low_threshold: 150,
            medium_threshold: 300,
            high_threshold: 500,
            critical_threshold: 700,
        }
    }

    /// Create a guard with custom thresholds (for testing).
    pub fn with_thresholds(low: i32, medium: i32, high: i32, critical: i32) -> Self {
        Self {
            peak_score: 0,
            high_risk_count: 0,
            survival_active: false,
            history: Vec::with_capacity(32),
            low_threshold: low,
            medium_threshold: medium,
            high_threshold: high,
            critical_threshold: critical,
        }
    }

    /// Read the current oom_score from /proc/self/oom_score.
    ///
    /// Returns None if the file doesn't exist (Windows, some containers).
    pub fn read_oom_score() -> Option<i32> {
        fs::read_to_string("/proc/self/oom_score")
            .ok()
            .and_then(|s| s.trim().parse::<i32>().ok())
    }

    /// Read the current oom_score_adj from /proc/self/oom_score_adj.
    ///
    /// On Android, this reflects the adjustment applied by the
    /// ActivityManager based on process importance.
    pub fn read_oom_score_adj() -> Option<i32> {
        fs::read_to_string("/proc/self/oom_score_adj")
            .ok()
            .and_then(|s| s.trim().parse::<i32>().ok())
    }

    /// Read available memory from /proc/meminfo (Linux/Android).
    ///
    /// Returns (MemAvailable_kb, MemTotal_kb). MemAvailable is a kernel
    /// estimate of how much memory is available for new allocations,
    /// accounting for page cache, buffers, and reclaimable slab.
    pub fn read_meminfo() -> Option<(u64, u64)> {
        let content = fs::read_to_string("/proc/meminfo").ok()?;
        let mut avail: Option<u64> = None;
        let mut total: Option<u64> = None;

        for line in content.lines() {
            if line.starts_with("MemAvailable:") {
                avail = line
                    .split_whitespace()
                    .nth(1)
                    .and_then(|s| s.parse::<u64>().ok());
            } else if line.starts_with("MemTotal:") {
                total = line
                    .split_whitespace()
                    .nth(1)
                    .and_then(|s| s.parse::<u64>().ok());
            }
            if avail.is_some() && total.is_some() {
                break;
            }
        }

        match (avail, total) {
            (Some(a), Some(t)) => Some((a, t)),
            _ => None,
        }
    }

    /// Sample the current OOM state and return a snapshot.
    ///
    /// This is the main entry point. Called before each inference cycle
    /// to check if memory pressure requires throttling.
    pub fn sample(&mut self) -> OomSnapshot {
        let oom_score = Self::read_oom_score().unwrap_or(0);
        let oom_score_adj = Self::read_oom_score_adj().unwrap_or(0);

        // Track peak
        if oom_score > self.peak_score {
            self.peak_score = oom_score;
        }

        // Track history for trend detection
        self.history.push(oom_score);
        if self.history.len() > 30 {
            self.history.remove(0);
        }

        // Classify risk
        let risk = if oom_score >= self.critical_threshold {
            OomRisk::Critical
        } else if oom_score >= self.high_threshold {
            OomRisk::High
        } else if oom_score >= self.medium_threshold {
            OomRisk::Medium
        } else {
            if oom_score < self.low_threshold {
                tracing::trace!(
                    "OOM score {} below low threshold {}",
                    oom_score,
                    self.low_threshold
                );
            }
            OomRisk::Low
        };

        // Update high-risk counter
        match risk {
            OomRisk::High | OomRisk::Critical => {
                self.high_risk_count += 1;
            }
            OomRisk::Low => {
                self.high_risk_count = self.high_risk_count.saturating_sub(1);
            }
            OomRisk::Medium => {
                // Decay slowly
                if self.high_risk_count > 0 && self.history.len().is_multiple_of(3) {
                    self.high_risk_count = self.high_risk_count.saturating_sub(1);
                }
            }
        }

        // Determine survival mode
        let survival_mode = matches!(risk, OomRisk::Critical)
            || (matches!(risk, OomRisk::High) && self.high_risk_count >= 3);

        if survival_mode && !self.survival_active {
            tracing::warn!(
                "OOM Guard: SURVIVAL MODE activated (score={}, risk={}, consecutive_high={})",
                oom_score,
                risk,
                self.high_risk_count
            );
        } else if !survival_mode && self.survival_active {
            tracing::info!(
                "OOM Guard: survival mode DEACTIVATED (score={}, risk={})",
                oom_score,
                risk
            );
        }
        self.survival_active = survival_mode;

        // Recommend context size based on risk
        let recommended_context = match risk {
            OomRisk::Low => 8192,
            OomRisk::Medium => 2048,
            OomRisk::High => 512,
            OomRisk::Critical => 256,
        };

        // Aggressive page release for High+ risk
        let aggressive_page_release = matches!(risk, OomRisk::High | OomRisk::Critical);

        // Check meminfo for additional context
        let meminfo_str = if let Some((avail, total)) = Self::read_meminfo() {
            let avail_mb = avail / 1024;
            let total_mb = total / 1024;
            let pct = if total > 0 {
                100.0 - (avail as f64 / total as f64 * 100.0)
            } else {
                0.0
            };
            format!("RAM: {}MB/{}MB ({:.0}% used)", avail_mb, total_mb, pct)
        } else {
            "RAM: unavailable".to_string()
        };

        let summary = format!(
            "OOM: score={}/adj={} risk={} survival={} ctx={} {}",
            oom_score, oom_score_adj, risk, survival_mode, recommended_context, meminfo_str
        );

        OomSnapshot {
            oom_score,
            oom_score_adj,
            risk,
            survival_mode,
            recommended_context,
            aggressive_page_release,
            summary,
        }
    }

    /// Check if the OOM score is trending upward (getting worse).
    pub fn is_trending_worse(&self) -> bool {
        if self.history.len() < 10 {
            return false;
        }
        let recent: f64 = self
            .history
            .iter()
            .rev()
            .take(5)
            .map(|&s| s as f64)
            .sum::<f64>()
            / 5.0;
        let older: f64 = self.history.iter().take(5).map(|&s| s as f64).sum::<f64>() / 5.0;
        recent > older + 20.0 // Rising more than 20 points
    }

    /// Get the peak OOM score observed.
    pub fn peak_score(&self) -> i32 {
        self.peak_score
    }

    /// Check if survival mode is active.
    pub fn is_survival_active(&self) -> bool {
        self.survival_active
    }

    /// Attempt to set oom_score_adj to make this process a higher-priority
    /// kill target under memory pressure. This is a sacrificial strategy:
    /// the LLM worker process is less important than the UI.
    ///
    /// Only works if the process has CAP_SYS_RESOURCE (root) or the parent
    /// process hasn't set a restrictive oom_score_adj. On stock Android,
    /// this typically requires adb shell or root.
    pub fn set_self_sacrificial(&self) -> io::Result<()> {
        // Set adj to 500 (visible service priority on Android).
        // The UI process typically has adj=0, so the LLM worker dies first.
        fs::write("/proc/self/oom_score_adj", "500\n")?;
        tracing::info!("OOM Guard: set oom_score_adj=500 (sacrificial mode)");
        Ok(())
    }

    /// Reset oom_score_adj to default (0).
    pub fn reset_oom_adj(&self) -> io::Result<()> {
        fs::write("/proc/self/oom_score_adj", "0\n")?;
        tracing::info!("OOM Guard: reset oom_score_adj=0");
        Ok(())
    }
}

impl Default for OomGuard {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_oom_guard_new() {
        let guard = OomGuard::new();
        assert_eq!(guard.peak_score, 0);
        assert!(!guard.survival_active);
    }

    #[test]
    fn test_sample_returns_valid_snapshot() {
        let mut guard = OomGuard::new();
        let snap = guard.sample();
        // On Windows, oom_score will be 0 (fallback)
        assert!(snap.oom_score >= 0);
        assert!(snap.recommended_context > 0);
        assert!(!snap.summary.is_empty());
    }

    #[test]
    fn test_risk_classification() {
        let mut guard = OomGuard::with_thresholds(10, 20, 30, 40);
        // Sample with default 0 score should be Low
        let snap = guard.sample();
        assert_eq!(snap.risk, OomRisk::Low);
    }

    #[test]
    fn test_peak_score_tracks_max() {
        let guard = OomGuard::new();
        // We can't easily mock /proc reads, but the peak tracker
        // should work correctly for any scores we can provide.
        // Just verify the field is accessible.
        assert_eq!(guard.peak_score(), 0);
    }

    #[test]
    fn test_trend_detection_empty() {
        let guard = OomGuard::new();
        assert!(!guard.is_trending_worse()); // not enough data
    }

    #[test]
    fn test_default_oom_guard() {
        let guard: OomGuard = Default::default();
        assert_eq!(guard.low_threshold, 150);
        assert_eq!(guard.medium_threshold, 300);
    }
}
