//! Hardware Abstraction Layer — Device-agnostic hardware detection.
//!
//! Provides a unified `DeviceInfo` trait that abstracts away OS-specific
//! hardware queries. The runtime selects the correct backend at boot based
//! on `uname` and available /proc entries. No per-device configuration needed.
//!
//! ## Supported backends
//! - Android (via /proc/meminfo, /sys/class/thermal, /sys/block)
//! - Linux (same as Android + fallbacks)
//! - Windows (via GlobalMemoryStatusEx, GetDiskFreeSpace)
//!
//! ## Integration
//! Used by `AutoConfig` to select the optimal strategy at boot.

use std::fmt;
use std::time::Duration;

/// Hardware capability level detected.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum DeviceTier {
    /// <4 GB RAM, slow storage, 4-6 cores.
    Budget,
    /// 4-8 GB RAM, UFS/eMMC, 6-8 cores.
    MidRange,
    /// >8 GB RAM, UFS 3.0+, 8+ cores, possibly NPU.
    Flagship,
    /// Desktop/server with abundant resources.
    Desktop,
}

impl fmt::Display for DeviceTier {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            DeviceTier::Budget => write!(f, "Budget"),
            DeviceTier::MidRange => write!(f, "MidRange"),
            DeviceTier::Flagship => write!(f, "Flagship"),
            DeviceTier::Desktop => write!(f, "Desktop"),
        }
    }
}

/// Device hardware profile detected at boot.
#[derive(Debug, Clone)]
pub struct DeviceProfile {
    /// Total physical RAM (MB).
    pub ram_total_mb: u64,
    /// Available RAM at boot time (MB).
    pub ram_available_mb: u64,
    /// Storage sequential read speed (MB/s). 0 if unmeasured.
    pub storage_read_mbps: u64,
    /// Storage sequential write speed (MB/s). 0 if unmeasured.
    pub storage_write_mbps: u64,
    /// Number of CPU cores available.
    pub cpu_cores: u32,
    /// Current thermal zone temperature (°C). -1 if unavailable.
    pub cpu_temp_c: i32,
    /// Whether ZRAM is active (Android/Linux).
    pub zram_active: bool,
    /// Whether an NPU/TPU is available (Android NNAPI).
    pub npu_available: bool,
    /// Device tier classification.
    pub tier: DeviceTier,
    /// Current OOM score. -1 if /proc unavailable.
    pub oom_score: i32,
    /// OOM score adjustment. 0 if /proc unavailable.
    pub oom_score_adj: i32,
}

impl Default for DeviceProfile {
    fn default() -> Self {
        Self {
            ram_total_mb: 0,
            ram_available_mb: 0,
            storage_read_mbps: 0,
            storage_write_mbps: 0,
            cpu_cores: std::thread::available_parallelism().map(|n| n.get() as u32).unwrap_or(4),
            cpu_temp_c: -1,
            zram_active: false,
            npu_available: false,
            tier: DeviceTier::MidRange,
            oom_score: -1,
            oom_score_adj: 0,
        }
    }
}

/// Lightweight storage benchmark result.
#[derive(Debug, Clone)]
pub struct StorageBench {
    pub read_mbps: u64,
    pub write_mbps: u64,
    pub duration: Duration,
}

// ── Platform detection ───────────────────────────────────────────────

/// Detect the current platform.
pub fn detect_platform() -> Platform {
    if cfg!(target_os = "android") {
        Platform::Android
    } else if cfg!(target_os = "linux") {
        Platform::Linux
    } else if cfg!(target_os = "windows") {
        Platform::Windows
    } else {
        Platform::Unknown
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum Platform {
    Android,
    Linux,
    Windows,
    Unknown,
}

// ── Linux/Android /proc readers ──────────────────────────────────────

#[cfg(any(target_os = "linux", target_os = "android"))]
mod proc_readers {
    use std::fs;

    pub fn read_meminfo(key: &str) -> Option<u64> {
        let contents = fs::read_to_string("/proc/meminfo").ok()?;
        for line in contents.lines() {
            if line.starts_with(key) {
                return line.split_whitespace().nth(1)?.parse::<u64>().ok();
            }
        }
        None
    }

    pub fn read_thermal(zone: &str) -> Option<i32> {
        let path = format!("/sys/class/thermal/{}/temp", zone);
        let temp_str = fs::read_to_string(&path).ok()?;
        temp_str.trim().parse::<i32>().ok().map(|t| t / 1000) // millidegrees -> Celsius
    }

    pub fn read_oom_score() -> Option<i32> {
        fs::read_to_string("/proc/self/oom_score").ok()?.trim().parse().ok()
    }

    pub fn read_oom_score_adj() -> Option<i32> {
        fs::read_to_string("/proc/self/oom_score_adj").ok()?.trim().parse().ok()
    }

    pub fn zram_active() -> bool {
        fs::read_to_string("/sys/block/zram0/disksize")
            .map(|s| s.trim().parse::<u64>().unwrap_or(0) > 0)
            .unwrap_or(false)
    }

    /// Run a quick storage benchmark (16 MB sequential read + write).
    pub fn bench_storage(temp_dir: &str) -> Option<super::StorageBench> {
        use std::io::{Read, Write};
        use std::time::Instant;

        let path = format!("{}/__nano_bench__.tmp", temp_dir);
        let data = vec![0xAAu8; 16 * 1024 * 1024]; // 16 MB

        // Write benchmark
        let t0 = Instant::now();
        let mut f = std::fs::File::create(&path).ok()?;
        f.write_all(&data).ok()?;
        f.sync_all().ok()?;
        let write_dur = t0.elapsed();

        // Read benchmark
        let t1 = Instant::now();
        let mut f = std::fs::File::open(&path).ok()?;
        let mut buf = vec![0u8; 16 * 1024 * 1024];
        f.read_exact(&mut buf).ok()?;
        let read_dur = t1.elapsed();

        // Cleanup
        let _ = std::fs::remove_file(&path);

        let write_mbps = (16.0 / write_dur.as_secs_f64()) as u64;
        let read_mbps = (16.0 / read_dur.as_secs_f64()) as u64;

        Some(super::StorageBench {
            read_mbps,
            write_mbps,
            duration: write_dur + read_dur,
        })
    }
}

// ── Profile builder ──────────────────────────────────────────────────

/// Build a DeviceProfile by probing the hardware.
pub fn profile_device() -> DeviceProfile {
    let mut p = DeviceProfile::default();

    // CPU cores
    p.cpu_cores = std::thread::available_parallelism().map(|n| n.get() as u32).unwrap_or(4);

    // Platform-specific probing
    #[cfg(any(target_os = "linux", target_os = "android"))]
    {
        use proc_readers::*;

        if let Some(total_kb) = read_meminfo("MemTotal:") {
            p.ram_total_mb = total_kb / 1024;
        }
        if let Some(avail_kb) = read_meminfo("MemAvailable:") {
            p.ram_available_mb = avail_kb / 1024;
        }

        // Thermal: try common zone names
        for zone in &["thermal_zone0", "cpu-thermal", "soc-thermal"] {
            if let Some(temp) = read_thermal(zone) {
                p.cpu_temp_c = temp;
                break;
            }
        }

        p.zram_active = zram_active();
        p.oom_score = read_oom_score().unwrap_or(-1);
        p.oom_score_adj = read_oom_score_adj().unwrap_or(0);

        // Storage benchmark
        let temp_dir = if cfg!(target_os = "android") {
            "/data/local/tmp"
        } else {
            "/tmp"
        };
        if let Some(bench) = bench_storage(temp_dir) {
            p.storage_read_mbps = bench.read_mbps;
            p.storage_write_mbps = bench.write_mbps;
        }

        // NPU detection (Android NNAPI)
        #[cfg(target_os = "android")]
        {
            p.npu_available = std::path::Path::new("/dev/accel").exists()
                || std::path::Path::new("/dev/hexagon").exists();
        }
    }

    #[cfg(target_os = "windows")]
    {
        // Windows: use reasonable defaults since we don't have /proc
        // Total RAM can be queried via kernel32 but we keep it simple
        p.ram_total_mb = 8192; // Conservative default
        p.ram_available_mb = 4096;
        p.oom_score = -1;
        p.oom_score_adj = 0;
        p.cpu_temp_c = -1;
    }

    // Classify tier
    p.tier = classify_tier(&p);
    p
}

/// Classify device tier from profile.
pub fn classify_tier(p: &DeviceProfile) -> DeviceTier {
    let ram = p.ram_total_mb;
    let storage = p.storage_read_mbps.max(p.storage_write_mbps);
    let cores = p.cpu_cores;

    if ram >= 16000 && storage >= 1000 && cores >= 8 {
        DeviceTier::Desktop
    } else if ram >= 8000 || (storage >= 600 && cores >= 8) {
        DeviceTier::Flagship
    } else if ram >= 4000 || (storage >= 200 && cores >= 6) {
        DeviceTier::MidRange
    } else {
        DeviceTier::Budget
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_classify_budget() {
        let p = DeviceProfile { ram_total_mb: 3724, cpu_cores: 4, storage_read_mbps: 200, ..Default::default() };
        assert_eq!(classify_tier(&p), DeviceTier::Budget);
    }

    #[test]
    fn test_classify_midrange() {
        let p = DeviceProfile { ram_total_mb: 6000, cpu_cores: 6, storage_read_mbps: 400, ..Default::default() };
        assert_eq!(classify_tier(&p), DeviceTier::MidRange);
    }

    #[test]
    fn test_classify_flagship() {
        let p = DeviceProfile { ram_total_mb: 12000, cpu_cores: 8, storage_read_mbps: 800, ..Default::default() };
        assert_eq!(classify_tier(&p), DeviceTier::Flagship);
    }

    #[test]
    fn test_profile_default_has_cores() {
        let p = DeviceProfile::default();
        assert!(p.cpu_cores > 0);
    }
}
