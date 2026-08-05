//! OOM Guard — Monitor Android OOM Killer. Linux/Android only.
//! Static risk assessment and quick_check available on all platforms.


#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum OomRisk { Low, Medium, High, Critical }

#[derive(Debug, Clone, Copy)]
pub enum SurvivalAction { Continue, ShrinkWindow, ShrinkContext, Pause { pause_ms: u64 }, Abort }

/// Quick VMA-based risk check — works on all platforms (no /proc needed).
pub fn quick_check(ram_total_mb: u64, current_vma_mb: u64) -> OomRisk {
    let ratio = current_vma_mb as f64 / ram_total_mb as f64;
    if ratio > 0.75 { OomRisk::Critical }
    else if ratio > 0.50 { OomRisk::High }
    else if ratio > 0.30 { OomRisk::Medium }
    else { OomRisk::Low }
}

// ── Linux/Android implementation ─────────────────────────────────────
#[cfg(any(target_os = "linux", target_os = "android"))]
pub mod imp {
    use std::fs;
    use super::{OomRisk, SurvivalAction};

    #[derive(Debug, Clone)]
    pub struct OomStatus {
        pub oom_score: i32,
        pub oom_score_adj: i32,
        pub mem_available_mb: u64,
        pub vm_rss_mb: u64,
        pub vm_size_mb: u64,
        pub risk: OomRisk,
    }

    pub struct OomGuard {
        medium_threshold: i32,
        high_threshold: i32,
        critical_threshold: i32,
        min_ram_mb: u64,
        current: Option<OomStatus>,
    }

    impl OomGuard {
        pub fn new() -> Self {
            Self { medium_threshold: 120, high_threshold: 200, critical_threshold: 350, min_ram_mb: 250, current: None }
        }
        pub fn with_thresholds(mut self, m: i32, h: i32, c: i32, ram: u64) -> Self {
            self.medium_threshold = m; self.high_threshold = h; self.critical_threshold = c; self.min_ram_mb = ram; self
        }
        pub fn sample(&mut self) -> Option<OomStatus> {
            let oom_score: i32 = fs::read_to_string("/proc/self/oom_score").ok()?.trim().parse().ok()?;
            let oom_score_adj: i32 = fs::read_to_string("/proc/self/oom_score_adj").ok().map(|s| s.trim().parse().unwrap_or(0)).unwrap_or(0);
            let mem_available_mb = {
                let c = fs::read_to_string("/proc/meminfo").ok()?;
                let kb: u64 = c.lines().find(|l| l.starts_with("MemAvailable:"))?
                    .split_whitespace().nth(1)?.parse().ok()?;
                kb / 1024
            };
            let (vm_rss_mb, vm_size_mb) = {
                let c = fs::read_to_string("/proc/self/status").ok()?;
                let rss: u64 = c.lines().find(|l| l.starts_with("VmRSS:"))
                    .and_then(|l| l.split_whitespace().nth(1)?.parse().ok()).unwrap_or(0);
                let sz: u64 = c.lines().find(|l| l.starts_with("VmSize:"))
                    .and_then(|l| l.split_whitespace().nth(1)?.parse().ok()).unwrap_or(0);
                (rss / 1024, sz / 1024)
            };
            let risk = if oom_score >= self.critical_threshold || mem_available_mb < self.min_ram_mb {
                OomRisk::Critical
            } else if oom_score >= self.high_threshold { OomRisk::High }
            else if oom_score >= self.medium_threshold { OomRisk::Medium }
            else { OomRisk::Low };
            let s = OomStatus { oom_score, oom_score_adj, mem_available_mb, vm_rss_mb, vm_size_mb, risk };
            self.current = Some(s.clone()); Some(s)
        }
        pub fn recommend_action(&self) -> SurvivalAction {
            match self.current.as_ref().map(|s| s.risk) {
                Some(OomRisk::Critical) => SurvivalAction::Pause { pause_ms: 100 },
                Some(OomRisk::High) => SurvivalAction::ShrinkWindow,
                Some(OomRisk::Medium) => SurvivalAction::ShrinkContext,
                _ => SurvivalAction::Continue,
            }
        }
        pub fn last_status(&self) -> Option<&OomStatus> { self.current.as_ref() }
        pub fn should_abort(&self) -> bool { matches!(self.current.as_ref().map(|s| s.risk), Some(OomRisk::Critical)) }
        pub fn summary(&self) -> String {
            match &self.current {
                Some(s) => format!("OOM score={} risk={:?} RAM={}MB RSS={}MB", s.oom_score, s.risk, s.mem_available_mb, s.vm_rss_mb),
                None => "OOM unavailable".into(),
            }
        }
    }
} // close mod imp (linux/android)

// ── Non-Linux stub ──────────────────────────────────────────────────
#[cfg(not(any(target_os = "linux", target_os = "android")))]
pub mod imp {
    use super::{OomRisk, SurvivalAction};
    #[derive(Debug, Clone)]
    pub struct OomStatus { pub oom_score: i32, pub oom_score_adj: i32, pub mem_available_mb: u64, pub vm_rss_mb: u64, pub vm_size_mb: u64, pub risk: OomRisk }
    pub struct OomGuard;
    impl OomGuard {
        pub fn new() -> Self { Self }
        pub fn with_thresholds(self, _m: i32, _h: i32, _c: i32, _r: u64) -> Self { self }
        pub fn sample(&mut self) -> Option<OomStatus> { None }
        pub fn recommend_action(&self) -> SurvivalAction { SurvivalAction::Continue }
        pub fn last_status(&self) -> Option<&OomStatus> { None }
        pub fn should_abort(&self) -> bool { false }
        pub fn summary(&self) -> String { "OOM guard: /proc unavailable (non-Linux)".into() }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_quick_check_critical() { assert_eq!(quick_check(3724, 4680), OomRisk::Critical); }
    #[test]
    fn test_quick_check_medium() { assert_eq!(quick_check(3724, 1400), OomRisk::Medium); }
    #[test]
    fn test_quick_check_low() { assert_eq!(quick_check(7823, 500), OomRisk::Low); }
    #[test]
    fn test_risk_ordering() { assert!(OomRisk::Critical > OomRisk::Low); }
}
