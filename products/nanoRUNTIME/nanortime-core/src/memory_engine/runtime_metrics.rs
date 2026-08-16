//! Runtime Metrics — Real system instrumentation for memory management
//!
//! Captures low-level system metrics to distinguish real RAM savings from
//! simple cost shifting to storage. Without this instrumentation, we cannot
//! tell if our optimizations are actually effective or just moving the
//! bottleneck.
//!
//! ## Metrics Captured
//!
//! - **Page Faults**: Minor (soft) and major (disk) faults
//! - **Memory Usage**: RSS (Resident Set Size), PSS (Proportional Set Size)
//! - **Pressure Stall Information (PSI)**: Memory and I/O pressure
//! - **I/O Statistics**: Bytes read/written, I/O operations
//! - **Cache Performance**: Cache hit/miss ratios
//! - **Token Throughput**: Tokens per second with breakdown by strategy
//! - **NGRAM Acceptance**: Speculative decoding acceptance rate

use std::time::{Duration, Instant, SystemTime};
use std::collections::HashMap;
use sysinfo::{System, Pid};
use serde::{Serialize, Deserialize};

/// Memory pressure metrics from the OS
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryPressureMetrics {
    /// Current RSS in bytes
    pub rss_bytes: u64,
    /// Current PSS in bytes (if available)
    pub pss_bytes: Option<u64>,
    /// Available memory in bytes
    pub available_bytes: u64,
    /// Total memory in bytes
    pub total_bytes: u64,
    /// Memory pressure as percentage (0.0-1.0)
    pub pressure_ratio: f64,
    /// Minor page faults (soft faults, resolved from cache)
    pub minor_faults: u64,
    /// Major page faults (disk I/O required)
    pub major_faults: u64,
    /// Major page fault rate (faults per second) — señal de thrashing por I/O
    pub fault_rate: f64,
}

/// I/O metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IoMetrics {
    /// Bytes read from storage
    pub bytes_read: u64,
    /// Bytes written to storage
    pub bytes_written: u64,
    /// Read operations count
    pub read_ops: u64,
    /// Write operations count
    pub write_ops: u64,
    /// I/O operations per second
    pub io_rate: f64,
    /// Average I/O latency in milliseconds
    pub avg_latency_ms: f64,
}

/// Pressure Stall Information (PSI) metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PsiMetrics {
    /// Memory PSI some percentage (time spent waiting for memory)
    pub memory_some: f64,
    /// Memory PSI full percentage (time fully stalled waiting for memory)
    pub memory_full: f64,
    /// I/O PSI some percentage (time spent waiting for I/O)
    pub io_some: f64,
    /// I/O PSI full percentage (time fully stalled waiting for I/O)
    pub io_full: f64,
    /// Whether PSI is available on this system
    pub available: bool,
}

/// Cache performance metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CacheMetrics {
    /// Cache hits count
    pub hits: u64,
    /// Cache misses count
    pub misses: u64,
    /// Cache hit rate (0.0-1.0)
    pub hit_rate: f64,
    /// Prefetch hits
    pub prefetch_hits: u64,
    /// Prefetch misses
    pub prefetch_misses: u64,
    /// Prefetch efficiency (0.0-1.0)
    pub prefetch_efficiency: f64,
}

/// Token throughput metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ThroughputMetrics {
    /// Total tokens generated
    pub total_tokens: u64,
    /// Tokens per second (overall)
    pub tokens_per_second: f64,
    /// Tokens per second by decode strategy
    pub by_strategy: HashMap<String, f64>,
    /// Average generation latency per token (ms)
    pub avg_token_latency_ms: f64,
    /// P90 latency per token (ms)
    pub p90_token_latency_ms: f64,
}

/// NGRAM speculative decoding metrics
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NgramMetrics {
    /// Total NGRAM speculation attempts
    pub total_attempts: u64,
    /// Accepted speculations
    pub accepted: u64,
    /// Rejected speculations
    pub rejected: u64,
    /// Acceptance rate (0.0-1.0)
    pub acceptance_rate: f64,
    /// Bytes read per useful token
    pub bytes_read_per_token: f64,
    /// Speculation accuracy (how often speculation was correct)
    pub speculation_accuracy: f64,
}

/// Comprehensive runtime metrics snapshot
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuntimeMetrics {
    /// Timestamp of this snapshot (as duration since UNIX epoch)
    pub timestamp_secs: f64,
    /// Memory pressure metrics
    pub memory: MemoryPressureMetrics,
    /// I/O metrics
    pub io: IoMetrics,
    /// PSI metrics (if available)
    pub psi: PsiMetrics,
    /// Cache performance
    pub cache: CacheMetrics,
    /// Token throughput
    pub throughput: ThroughputMetrics,
    /// NGRAM metrics
    pub ngram: NgramMetrics,
    /// Uptime since start (in seconds)
    pub uptime_secs: f64,
}

/// Runtime metrics collector
pub struct RuntimeMetricsCollector {
    /// System information collector
    system: System,
    /// Process ID to track
    pid: Pid,
    /// Previous metrics for delta calculations
    previous_memory: Option<MemoryPressureMetrics>,
    previous_io: Option<IoMetrics>,
    /// Último snapshot de memoria — usado por `is_thrashing` sin re-colectar
    last_memory: Option<MemoryPressureMetrics>,
    /// Instante del último collect — para tasas reales entre muestras
    last_collect: Option<Instant>,
    /// Start time for uptime calculation
    start_time: Instant,
    /// Token counter
    token_counter: u64,
    /// Token latencies for percentile calculations
    token_latencies: Vec<Duration>,
    /// NGRAM tracking
    ngram_attempts: u64,
    ngram_accepted: u64,
    ngram_rejected: u64,
    ngram_bytes_read: u64,
}

impl RuntimeMetricsCollector {
    /// Create a new metrics collector for the current process
    pub fn new() -> Self {
        let mut system = System::new_all();
        system.refresh_all();
        
        let pid = Pid::from(std::process::id() as usize);

        Self {
            system,
            pid,
            previous_memory: None,
            previous_io: None,
            last_memory: None,
            last_collect: None,
            start_time: Instant::now(),
            token_counter: 0,
            token_latencies: Vec::new(),
            ngram_attempts: 0,
            ngram_accepted: 0,
            ngram_rejected: 0,
            ngram_bytes_read: 0,
        }
    }

    /// Create a new metrics collector for a specific process
    pub fn for_pid(pid: u32) -> Self {
        let mut system = System::new_all();
        system.refresh_all();
        
        Self {
            system,
            pid: Pid::from(pid as usize),
            previous_memory: None,
            previous_io: None,
            last_memory: None,
            last_collect: None,
            start_time: Instant::now(),
            token_counter: 0,
            token_latencies: Vec::new(),
            ngram_attempts: 0,
            ngram_accepted: 0,
            ngram_rejected: 0,
            ngram_bytes_read: 0,
        }
    }

    /// Collect current runtime metrics
    pub fn collect(&mut self) -> RuntimeMetrics {
        self.system.refresh_all();
        
        let memory = self.collect_memory_metrics();
        let io = self.collect_io_metrics();
        let psi = self.collect_psi_metrics();
        let cache = self.collect_cache_metrics();
        let throughput = self.collect_throughput_metrics();
        let ngram = self.collect_ngram_metrics();
        
        // Update previous metrics for delta calculations
        self.previous_memory = Some(memory.clone());
        self.previous_io = Some(io.clone());
        self.last_memory = Some(memory.clone());
        self.last_collect = Some(Instant::now());

        let timestamp_secs = SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs_f64();
        
        RuntimeMetrics {
            timestamp_secs,
            memory,
            io,
            psi,
            cache,
            throughput,
            ngram,
            uptime_secs: self.start_time.elapsed().as_secs_f64(),
        }
    }

    /// Collect memory pressure metrics
    fn collect_memory_metrics(&mut self) -> MemoryPressureMetrics {
        let now = Instant::now();

        if let Some(process) = self.system.process(self.pid) {
            let rss_bytes = process.memory();
            let available_bytes = self.system.available_memory();
            let total_bytes = self.system.total_memory();

            // Page faults REALES desde /proc/self/stat (Linux/Android).
            // sysinfo no los expone; en Windows el parse devuelve (0, 0).
            let (minor_faults, major_faults) = Self::read_proc_stat_faults();
            let pss_bytes = Self::read_pss_bytes();

            // Calculate pressure ratio
            let pressure_ratio = if total_bytes > 0 {
                1.0 - (available_bytes as f64 / total_bytes as f64)
            } else {
                0.0
            };

            // Tasa de major faults entre este collect y el anterior.
            // Major fault = página que requiere I/O de disco → señal directa
            // de que el working set no cabe en RAM (thrashing).
            let fault_rate = if let (Some(prev), Some(last)) =
                (&self.previous_memory, self.last_collect)
            {
                let delta = major_faults.saturating_sub(prev.major_faults);
                let delta_time = now.duration_since(last).as_secs_f64();
                if delta_time > 0.0 {
                    delta as f64 / delta_time
                } else {
                    0.0
                }
            } else {
                0.0
            };

            MemoryPressureMetrics {
                rss_bytes,
                pss_bytes,
                available_bytes,
                total_bytes,
                pressure_ratio,
                minor_faults,
                major_faults,
                fault_rate,
            }
        } else {
            // Fallback if process not found
            MemoryPressureMetrics {
                rss_bytes: 0,
                pss_bytes: None,
                available_bytes: self.system.available_memory(),
                total_bytes: self.system.total_memory(),
                pressure_ratio: 0.0,
                minor_faults: 0,
                major_faults: 0,
                fault_rate: 0.0,
            }
        }
    }

    /// Lee minflt/majflt del proceso actual desde /proc/self/stat.
    ///
    /// Formato: `pid (comm) state ppid pgrp session tty tpgid flags
    /// minflt cminflt majflt cmajflt ...`
    /// `comm` va entre paréntesis y puede contener espacios; el resto de
    /// campos empieza tras el ÚLTIMO ')' (comm no puede contener ')').
    /// Índices tras ')': 0=state, 7=minflt, 9=majflt.
    #[cfg(any(target_os = "linux", target_os = "android"))]
    fn read_proc_stat_faults() -> (u64, u64) {
        let Ok(stat) = std::fs::read_to_string("/proc/self/stat") else {
            return (0, 0);
        };
        let Some(rparen) = stat.rfind(')') else {
            return (0, 0);
        };
        let fields: Vec<&str> = stat[rparen + 2..].split_whitespace().collect();
        let minflt = fields.get(7).and_then(|v| v.parse().ok()).unwrap_or(0);
        let majflt = fields.get(9).and_then(|v| v.parse().ok()).unwrap_or(0);
        (minflt, majflt)
    }

    #[cfg(not(any(target_os = "linux", target_os = "android")))]
    fn read_proc_stat_faults() -> (u64, u64) {
        (0, 0)
    }

    /// PSS real del proceso desde /proc/self/smaps_rollup (Linux/Android).
    /// El campo `Pss:` viene en kB — se convierte a bytes.
    #[cfg(any(target_os = "linux", target_os = "android"))]
    fn read_pss_bytes() -> Option<u64> {
        let rollup = std::fs::read_to_string("/proc/self/smaps_rollup").ok()?;
        let line = rollup.lines().find(|l| l.starts_with("Pss:"))?;
        let kb: u64 = line.split_whitespace().nth(1)?.parse().ok()?;
        Some(kb * 1024)
    }

    #[cfg(not(any(target_os = "linux", target_os = "android")))]
    fn read_pss_bytes() -> Option<u64> {
        None
    }

    /// Collect I/O metrics
    fn collect_io_metrics(&mut self) -> IoMetrics {
        // I/O REAL desde /proc/self/io (Linux/Android): read_bytes/write_bytes
        // son los bytes que fueron a storage de verdad (no page cache) — la
        // señal directa del thrashing por re-faulting.
        #[cfg(any(target_os = "linux", target_os = "android"))]
        let (bytes_read, bytes_written) = Self::read_proc_io();
        #[cfg(not(any(target_os = "linux", target_os = "android")))]
        let (bytes_read, bytes_written) = (0u64, 0u64);

        let io_rate = if let (Some(prev), Some(last)) = (&self.previous_io, self.last_collect) {
            let delta_bytes = (bytes_read + bytes_written)
                .saturating_sub(prev.bytes_read + prev.bytes_written);
            let delta_time = last.elapsed().as_secs_f64();
            if delta_time > 0.0 {
                delta_bytes as f64 / delta_time
            } else {
                0.0
            }
        } else {
            0.0
        };

        IoMetrics {
            bytes_read,
            bytes_written,
            read_ops: 0,
            write_ops: 0,
            io_rate,
            avg_latency_ms: 0.0,
        }
    }

    /// Bytes de I/O reales del proceso desde /proc/self/io.
    /// `read_bytes`/`write_bytes` = I/O que tocó storage (no cache).
    #[cfg(any(target_os = "linux", target_os = "android"))]
    fn read_proc_io() -> (u64, u64) {
        let Ok(io) = std::fs::read_to_string("/proc/self/io") else {
            return (0, 0);
        };
        let mut read_bytes = 0u64;
        let mut write_bytes = 0u64;
        for line in io.lines() {
            if let Some(v) = line.strip_prefix("read_bytes: ") {
                read_bytes = v.trim().parse().unwrap_or(0);
            } else if let Some(v) = line.strip_prefix("write_bytes: ") {
                write_bytes = v.trim().parse().unwrap_or(0);
            }
        }
        (read_bytes, write_bytes)
    }

    /// Collect PSI metrics (Linux-specific)
    fn collect_psi_metrics(&self) -> PsiMetrics {
        #[cfg(any(target_os = "linux", target_os = "android"))]
        {
            // Try to read PSI from /proc/pressure
            if let Ok(memory_psi) = std::fs::read_to_string("/proc/pressure/memory") {
                if let Ok(io_psi) = std::fs::read_to_string("/proc/pressure/io") {
                    return Self::parse_psi(&memory_psi, &io_psi);
                }
            }
            
            PsiMetrics {
                memory_some: 0.0,
                memory_full: 0.0,
                io_some: 0.0,
                io_full: 0.0,
                available: false,
            }
        }
        
        #[cfg(not(any(target_os = "linux", target_os = "android")))]
        {
            PsiMetrics {
                memory_some: 0.0,
                memory_full: 0.0,
                io_some: 0.0,
                io_full: 0.0,
                available: false,
            }
        }
    }

    #[cfg(any(target_os = "linux", target_os = "android"))]
    fn parse_psi(memory_psi: &str, io_psi: &str) -> PsiMetrics {
        let parse_psi_line = |line: &str| -> (f64, f64) {
            let parts: Vec<&str> = line.split_whitespace().collect();
            let some = parts.get(4).and_then(|s| s.trim_end_matches('%').parse().ok()).unwrap_or(0.0);
            let full = parts.get(7).and_then(|s| s.trim_end_matches('%').parse().ok()).unwrap_or(0.0);
            (some, full)
        };
        
        let memory_lines: Vec<&str> = memory_psi.lines().collect();
        let io_lines: Vec<&str> = io_psi.lines().collect();
        
        let (memory_some, memory_full) = memory_lines.first()
            .map(|line| parse_psi_line(line))
            .unwrap_or((0.0, 0.0));
        
        let (io_some, io_full) = io_lines.first()
            .map(|line| parse_psi_line(line))
            .unwrap_or((0.0, 0.0));
        
        PsiMetrics {
            memory_some,
            memory_full,
            io_some,
            io_full,
            available: true,
        }
    }

    /// Collect cache performance metrics
    fn collect_cache_metrics(&self) -> CacheMetrics {
        // These would be tracked by the cache manager
        // For now, return placeholder values
        CacheMetrics {
            hits: 0,
            misses: 0,
            hit_rate: 0.0,
            prefetch_hits: 0,
            prefetch_misses: 0,
            prefetch_efficiency: 0.0,
        }
    }

    /// Collect throughput metrics
    fn collect_throughput_metrics(&mut self) -> ThroughputMetrics {
        let elapsed = self.start_time.elapsed().as_secs_f64();
        let tokens_per_second = if elapsed > 0.0 {
            self.token_counter as f64 / elapsed
        } else {
            0.0
        };

        let avg_latency = if !self.token_latencies.is_empty() {
            let total: Duration = self.token_latencies.iter().sum();
            total.as_millis() as f64 / self.token_latencies.len() as f64
        } else {
            0.0
        };

        // Sort IN-PLACE (≤1000 Duration acotados): antes se clonaba y ordenaba
        // el Vec entero en CADA collect(), que se llama varias veces por
        // generación. El orden no importa para el sum del avg (ya calculado).
        let p90_latency = if !self.token_latencies.is_empty() {
            self.token_latencies.sort();
            let p90_idx = (self.token_latencies.len() as f64 * 0.9) as usize;
            self.token_latencies
                .get(p90_idx)
                .map(|d| d.as_millis() as f64)
                .unwrap_or(0.0)
        } else {
            0.0
        };
        
        ThroughputMetrics {
            total_tokens: self.token_counter,
            tokens_per_second,
            by_strategy: HashMap::new(), // Would be populated by decode strategy tracking
            avg_token_latency_ms: avg_latency,
            p90_token_latency_ms: p90_latency,
        }
    }

    /// Collect NGRAM metrics
    fn collect_ngram_metrics(&self) -> NgramMetrics {
        let total = self.ngram_attempts;
        let acceptance_rate = if total > 0 {
            self.ngram_accepted as f64 / total as f64
        } else {
            0.0
        };
        
        let bytes_per_token = if self.ngram_accepted > 0 {
            self.ngram_bytes_read as f64 / self.ngram_accepted as f64
        } else {
            0.0
        };
        
        let speculation_accuracy = if total > 0 {
            self.ngram_accepted as f64 / total as f64
        } else {
            0.0
        };
        
        NgramMetrics {
            total_attempts: total,
            accepted: self.ngram_accepted,
            rejected: self.ngram_rejected,
            acceptance_rate,
            bytes_read_per_token: bytes_per_token,
            speculation_accuracy,
        }
    }

    /// Record a token generation
    pub fn record_token(&mut self, latency: Duration, _strategy: &str) {
        self.token_counter += 1;
        self.token_latencies.push(latency);
        
        // Keep only last 1000 latencies for memory efficiency
        if self.token_latencies.len() > 1000 {
            self.token_latencies.remove(0);
        }
    }

    /// Record an NGRAM speculation attempt
    pub fn record_ngram_attempt(&mut self, accepted: bool, bytes_read: u64) {
        self.ngram_attempts += 1;
        if accepted {
            self.ngram_accepted += 1;
            self.ngram_bytes_read += bytes_read;
        } else {
            self.ngram_rejected += 1;
        }
    }

    /// Get current memory pressure ratio (0.0-1.0)
    pub fn memory_pressure(&self) -> f64 {
        let available = self.system.available_memory();
        let total = self.system.total_memory();
        if total > 0 {
            1.0 - (available as f64 / total as f64)
        } else {
            0.0
        }
    }

    /// Check if the system is under memory pressure
    pub fn is_under_pressure(&self, threshold: f64) -> bool {
        self.memory_pressure() > threshold
    }

    /// Check if the system is thrashing (high fault rate)
    ///
    /// Real: usa fault_rate (major faults/segundo) del último collect.
    /// Sin collect previo retorna false — sin datos, sin alarma.
    pub fn is_thrashing(&self, fault_threshold: f64) -> bool {
        match &self.last_memory {
            Some(m) => m.fault_rate > fault_threshold,
            None => false,
        }
    }

    /// Reset metrics counters
    pub fn reset_counters(&mut self) {
        self.token_counter = 0;
        self.token_latencies.clear();
        self.ngram_attempts = 0;
        self.ngram_accepted = 0;
        self.ngram_rejected = 0;
        self.ngram_bytes_read = 0;
    }

    /// Get current uptime
    pub fn uptime(&self) -> Duration {
        self.start_time.elapsed()
    }
}

impl Default for RuntimeMetricsCollector {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_metrics_collector_creation() {
        let collector = RuntimeMetricsCollector::new();
        assert_eq!(collector.pid, Pid::from(std::process::id() as usize));
        assert_eq!(collector.token_counter, 0);
    }

    #[test]
    fn test_metrics_collection() {
        let mut collector = RuntimeMetricsCollector::new();
        let metrics = collector.collect();
        
        // Should have collected some basic metrics
        assert!(metrics.memory.total_bytes > 0);
        assert!(metrics.uptime_secs >= 0.0);
    }

    #[test]
    fn test_token_recording() {
        let mut collector = RuntimeMetricsCollector::new();
        
        collector.record_token(Duration::from_millis(10), "default");
        collector.record_token(Duration::from_millis(15), "default");
        
        assert_eq!(collector.token_counter, 2);
        assert_eq!(collector.token_latencies.len(), 2);
    }

    #[test]
    fn test_ngram_recording() {
        let mut collector = RuntimeMetricsCollector::new();
        
        collector.record_ngram_attempt(true, 1024);
        collector.record_ngram_attempt(false, 0);
        collector.record_ngram_attempt(true, 2048);
        
        assert_eq!(collector.ngram_attempts, 3);
        assert_eq!(collector.ngram_accepted, 2);
        assert_eq!(collector.ngram_rejected, 1);
        assert_eq!(collector.ngram_bytes_read, 3072);
    }

    #[test]
    fn test_memory_pressure() {
        let collector = RuntimeMetricsCollector::new();
        let pressure = collector.memory_pressure();
        
        // Pressure should be between 0.0 and 1.0
        assert!((0.0..=1.0).contains(&pressure));
    }

    #[test]
    fn test_reset_counters() {
        let mut collector = RuntimeMetricsCollector::new();
        
        collector.record_token(Duration::from_millis(10), "default");
        collector.record_ngram_attempt(true, 1024);
        
        collector.reset_counters();
        
        assert_eq!(collector.token_counter, 0);
        assert_eq!(collector.ngram_attempts, 0);
    }
}