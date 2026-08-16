//! Memory Model — Formal RAM estimation for LLM inference on constrained devices.
//!
//! Implements the five key formulas that govern memory behavior in NanoRuntime:
//!
//! Formula 1: RSS_peak = (model_size × overhead_factor) + KV_cache + runtime
//! Formula 2: VMA vs RSS distinction for OOM Killer behavior
//! Formula 3: I/O-bound throughput = storage_bandwidth / model_size
//! Formula 4: KV cache savings with hierarchical compression
//! Formula 5: VMA reduction via Layer Streaming

use crate::memory_engine::auto_config::KvCompression;

/// Memory estimation result for a given configuration.
#[derive(Debug, Clone)]
pub struct MemoryEstimate {
    /// Peak RSS (MB) — actual physical RAM used by process.
    pub peak_rss_mb: f64,
    /// Virtual Memory Area (MB) — address space reservation.
    pub vma_mb: f64,
    /// KV cache size (MB) at current precision.
    pub kv_cache_mb: f64,
    /// Model weight contribution (MB).
    pub model_mb: f64,
    /// Runtime overhead (MB).
    pub overhead_mb: f64,
    /// Whether the device can survive (OOM risk assessment).
    pub survives: bool,
    /// Risk level: Low, Medium, High, Critical.
    pub risk: String,
}

/// Throughput estimation result.
#[derive(Debug, Clone)]
pub struct ThroughputEstimate {
    /// Theoretical maximum (tok/s) based on I/O bandwidth.
    pub theoretical_tok_s: f64,
    /// Measured/expected (tok/s) with caching effects.
    pub expected_tok_s: f64,
    /// I/O-bound confirmation.
    pub io_bound: bool,
}

/// Memory Model — formal RAM and throughput estimation.
#[derive(Clone)]
pub struct MemoryModel {
    /// Overhead factor (file-to-RAM ratio).
    overhead_factor: f64,
    /// KV cache per token per layer pair (MB).
    kv_per_token_mb: f64,
    /// Runtime heap overhead (MB).
    runtime_overhead_mb: f64,
    /// Maximum safe VMA ratio (VMA / RAM_total).
    max_vma_ratio: f64,
}

impl Default for MemoryModel {
    fn default() -> Self {
        Self {
            overhead_factor: 1.08,
            kv_per_token_mb: 0.03,
            runtime_overhead_mb: 200.0,
            max_vma_ratio: 0.90,
        }
    }
}

impl MemoryModel {
    /// Create with custom parameters.
    pub fn new(overhead: f64, kv_per_token: f64, runtime_mb: f64) -> Self {
        Self {
            overhead_factor: overhead,
            kv_per_token_mb: kv_per_token,
            runtime_overhead_mb: runtime_mb,
            max_vma_ratio: 0.90,
        }
    }

    // ── Formula 1: Peak RSS estimation ────────────────────────────

    /// Estimate peak RSS for a given model and context.
    pub fn estimate_rss(
        &self,
        model_size_mb: f64,
        context_tokens: usize,
        num_layers: usize,
        kv_compression: KvCompression,
    ) -> MemoryEstimate {
        let model_mb = model_size_mb * self.overhead_factor;
        let kv_raw_mb = context_tokens as f64 * self.kv_per_token_mb * num_layers as f64 / 32.0;
        let kv_cache_mb = match kv_compression {
            KvCompression::None => kv_raw_mb,
            KvCompression::Int8 => kv_raw_mb * 0.5,
            KvCompression::Int4 => kv_raw_mb * 0.25,
            KvCompression::Int2 => kv_raw_mb * 0.125,
        };
        let overhead_mb = self.runtime_overhead_mb;
        let peak_rss_mb = model_mb + kv_cache_mb + overhead_mb;
        let vma_mb = model_size_mb.max(peak_rss_mb);

        MemoryEstimate {
            peak_rss_mb,
            vma_mb,
            kv_cache_mb,
            model_mb,
            overhead_mb,
            survives: false, // Set by caller
            risk: "Unknown".into(),
        }
    }

    // ── Formula 2: OOM survival assessment ────────────────────────

    /// Assess whether a device can survive with a given VMA.
    pub fn assess_survival(
        &self,
        estimate: &mut MemoryEstimate,
        ram_total_mb: f64,
        ram_available_mb: f64,
    ) {
        let vma_ratio = estimate.vma_mb / ram_total_mb;
        let rss_ratio = estimate.peak_rss_mb / ram_available_mb;

        let (survives, risk) = if vma_ratio > self.max_vma_ratio {
            (false, "Critical".into())
        } else if vma_ratio > 0.75 {
            (true, "High".into())
        } else if vma_ratio > 0.50 || rss_ratio > 0.70 {
            (true, "Medium".into())
        } else {
            (true, "Low".into())
        };

        estimate.survives = survives;
        estimate.risk = risk;
    }

    // ── Formula 3: I/O-bound throughput ───────────────────────────

    /// Estimate throughput based on storage bandwidth.
    pub fn estimate_throughput(
        &self,
        model_size_mb: f64,
        storage_read_mbps: f64,
    ) -> ThroughputEstimate {
        let theoretical = if storage_read_mbps > 0.0 {
            storage_read_mbps / model_size_mb
        } else {
            0.0
        };
        // Measured values typically 1.5-2x theoretical due to OS caching
        let expected = theoretical * 1.8;
        let io_bound = theoretical < 1.0; // <1 tok/s = I/O-bound

        ThroughputEstimate {
            theoretical_tok_s: theoretical,
            expected_tok_s: expected,
            io_bound,
        }
    }

    // ── Formula 4: KV cache savings ───────────────────────────────

    /// Estimate KV cache savings from compression.
    pub fn kv_savings(
        &self,
        context_tokens: usize,
        num_layers: usize,
        from: KvCompression,
        to: KvCompression,
    ) -> f64 {
        let raw = context_tokens as f64 * self.kv_per_token_mb * num_layers as f64 / 32.0;
        let multiplier_from = match from {
            KvCompression::None => 1.0,
            KvCompression::Int8 => 0.5,
            KvCompression::Int4 => 0.25,
            KvCompression::Int2 => 0.125,
        };
        let multiplier_to = match to {
            KvCompression::None => 1.0,
            KvCompression::Int8 => 0.5,
            KvCompression::Int4 => 0.25,
            KvCompression::Int2 => 0.125,
        };
        raw * (multiplier_from - multiplier_to)
    }

    // ── Formula 5: VMA with Layer Streaming ────────────────────────

    /// Estimate VMA when using sliding-window layer streaming.
    pub fn estimate_streaming_vma(
        &self,
        window_layers: usize,
        bytes_per_layer_mb: f64,
        num_layers: usize,
    ) -> f64 {
        let window_mb = window_layers.min(num_layers) as f64 * bytes_per_layer_mb;
        let kv_mb = 512.0 * self.kv_per_token_mb; // Minimum context
        window_mb + kv_mb + self.runtime_overhead_mb
    }

    /// Check if streaming makes a model viable on a device.
    pub fn can_stream(
        &self,
        window_layers: usize,
        bytes_per_layer_mb: f64,
        num_layers: usize,
        ram_total_mb: f64,
    ) -> bool {
        let vma = self.estimate_streaming_vma(window_layers, bytes_per_layer_mb, num_layers);
        vma < ram_total_mb * self.max_vma_ratio
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_formula_1_oppo_7b() {
        let mm = MemoryModel::default();
        let est = mm.estimate_rss(4470.0, 512, 32, KvCompression::None);
        // 4470 × 1.08 + 15.36 KV + 200 overhead ≈ 5043 MB (~4.9 GB)
        // Consistente con el paper: "approximately 4.9 GB, within ±200 MB of 4.82 GB"
        assert!(est.peak_rss_mb > 4900.0 && est.peak_rss_mb < 5200.0);
        assert!(est.model_mb > 4700.0);
    }

    #[test]
    fn test_formula_2_samsung_survival() {
        let mm = MemoryModel::default();
        let mut est = mm.estimate_rss(4470.0, 512, 32, KvCompression::None);
        mm.assess_survival(&mut est, 3724.0, 1900.0);
        // VMA 4.68GB / 3.72GB = 1.26 > 0.90 → Critical
        assert_eq!(est.risk, "Critical");
        assert!(!est.survives);
    }

    #[test]
    fn test_formula_3_oppo_throughput() {
        let mm = MemoryModel::default();
        let tp = mm.estimate_throughput(4470.0, 1067.0);
        assert!(tp.theoretical_tok_s > 0.20 && tp.theoretical_tok_s < 0.30);
        assert!(tp.io_bound);
    }

    #[test]
    fn test_formula_4_kv_savings() {
        let mm = MemoryModel::default();
        let saved = mm.kv_savings(8192, 32, KvCompression::None, KvCompression::Int4);
        assert!(saved > 50.0); // Should save at least 50 MB
    }

    #[test]
    fn test_formula_5_streaming_vma() {
        let mm = MemoryModel::default();
        let vma = mm.estimate_streaming_vma(3, 140.0, 32);
        // 3 × 140 + 15 + 200 = 635 MB
        assert!(vma < 800.0);
        assert!(mm.can_stream(3, 140.0, 32, 3724.0));
    }
}
