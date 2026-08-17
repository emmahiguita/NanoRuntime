//! Working Set Estimator + Thrashing Detector
//!
//! The heart of the control plane philosophy: estimate the active working set
//! (WeightsActive + KV + Buffers + Runtime) and detect when the model technically
//! "lives" but is already useless due to I/O thrashing.
//!
//! This component distinguishes real RAM savings from simple cost shifting to
//! storage by monitoring the actual active memory footprint and I/O patterns.
//!
//! ## Working Set Components
//!
//! - **WeightsActive**: Currently active model weights in RAM
//! - **KV Cache**: Key-value cache for context window
//! - **Buffers**: Runtime buffers and temporary allocations
//! - **Runtime**: Overhead for the runtime itself
//!
//! ## Thrashing Detection
//!
//! Detects when the system is in a state where:
//! - The model is technically resident in memory
//! - But performance is degraded due to excessive paging
//! - The model becomes practically useless despite being "loaded"

use crate::memory_engine::runtime_metrics::RuntimeMetricsCollector;
use std::collections::VecDeque;
use std::time::Instant;

/// Working set breakdown
#[derive(Debug, Clone)]
pub struct WorkingSetBreakdown {
    /// Active model weights in RAM (bytes)
    pub weights_active: u64,
    /// KV cache size (bytes)
    pub kv_cache: u64,
    /// Runtime buffers (bytes)
    pub buffers: u64,
    /// Runtime overhead (bytes)
    pub runtime: u64,
    /// Total working set (bytes)
    pub total: u64,
    /// Percentage of total RAM used
    pub ram_percentage: f64,
}

/// Thrashing state
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ThrashingState {
    /// No thrashing detected
    None,
    /// Mild thrashing - performance degradation starting
    Mild,
    /// Moderate thrashing - significant performance impact
    Moderate,
    /// Severe thrashing - model practically unusable
    Severe,
}

impl ThrashingState {
    /// Returns whether the system is thrashing
    pub fn is_thrashing(&self) -> bool {
        !matches!(self, ThrashingState::None)
    }

    /// Returns the severity level (0-3)
    pub fn severity(&self) -> u8 {
        match self {
            ThrashingState::None => 0,
            ThrashingState::Mild => 1,
            ThrashingState::Moderate => 2,
            ThrashingState::Severe => 3,
        }
    }
}

/// Thrashing detection result
#[derive(Debug, Clone)]
pub struct ThrashingDetection {
    /// Current thrashing state
    pub state: ThrashingState,
    /// Confidence in the detection (0.0-1.0)
    pub confidence: f64,
    /// Primary contributing factors
    pub factors: Vec<ThrashingFactor>,
    /// Recommended action
    pub recommended_action: ThrashingAction,
}

/// Factors contributing to thrashing
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ThrashingFactor {
    /// High page fault rate
    HighPageFaultRate,
    /// High memory pressure
    HighMemoryPressure,
    /// Low cache hit rate
    LowCacheHitRate,
    /// High I/O wait time
    HighIOWait,
    /// Insufficient working set
    InsufficientWorkingSet,
    /// Fragmentation issues
    MemoryFragmentation,
}

/// Recommended actions for thrashing
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ThrashingAction {
    /// No action needed
    None,
    /// Reduce working set by offloading layers
    ReduceWorkingSet,
    /// Increase prefetch aggressiveness
    IncreasePrefetch,
    /// Switch to more aggressive caching
    AggressiveCaching,
    /// Emergency mode - minimal working set
    EmergencyMode,
    /// Suggest context window reduction
    ReduceContext,
}

/// Working set history for trend analysis
#[derive(Debug, Clone)]
pub struct WorkingSetHistory {
    samples: VecDeque<WorkingSetSample>,
    max_samples: usize,
}

#[derive(Debug, Clone)]
struct WorkingSetSample {
    timestamp: Instant,
    working_set: WorkingSetBreakdown,
    fault_rate: f64,
    io_rate: f64,
}

/// Working Set Estimator
pub struct WorkingSetEstimator {
    /// Runtime metrics collector
    metrics: RuntimeMetricsCollector,
    /// Working set history
    history: WorkingSetHistory,
    /// Current active layers
    active_layers: Vec<usize>,
    /// KV cache size per token (bytes)
    kv_per_token: u64,
    /// Context window size
    context_window: usize,
    /// Runtime overhead estimate (bytes)
    runtime_overhead: u64,
    /// Buffer overhead estimate (bytes)
    buffer_overhead: u64,
}

impl WorkingSetEstimator {
    /// Create a new working set estimator
    pub fn new() -> Self {
        Self {
            metrics: RuntimeMetricsCollector::new(),
            history: WorkingSetHistory {
                samples: VecDeque::new(),
                max_samples: 100,
            },
            active_layers: Vec::new(),
            kv_per_token: 1024, // Default 1KB per token per layer
            context_window: 512,
            runtime_overhead: 200 * 1024 * 1024, // 200MB default
            buffer_overhead: 100 * 1024 * 1024,  // 100MB default
        }
    }

    /// Set the active layers
    pub fn set_active_layers(&mut self, layers: Vec<usize>) {
        self.active_layers = layers;
    }

    /// Set KV cache parameters
    pub fn set_kv_params(&mut self, per_token: u64, context_window: usize) {
        self.kv_per_token = per_token;
        self.context_window = context_window;
    }

    /// Set runtime overhead estimates
    pub fn set_overhead(&mut self, runtime: u64, buffers: u64) {
        self.runtime_overhead = runtime;
        self.buffer_overhead = buffers;
    }

    /// Estimate the current working set
    pub fn estimate_working_set(&mut self) -> WorkingSetBreakdown {
        let weights_active = self.estimate_active_weights();
        let kv_cache = self.estimate_kv_cache();
        let buffers = self.buffer_overhead;
        let runtime = self.runtime_overhead;

        let total = weights_active + kv_cache + buffers + runtime;

        // Get total RAM from metrics
        let total_ram = self.metrics.memory_pressure() * 1_000_000_000.0; // Convert ratio to bytes estimate
        let ram_percentage = if total_ram > 0.0 {
            (total as f64 / total_ram) * 100.0
        } else {
            0.0
        };

        WorkingSetBreakdown {
            weights_active,
            kv_cache,
            buffers,
            runtime,
            total,
            ram_percentage,
        }
    }

    /// Estimate active weights in RAM.
    ///
    /// Estimate por conteo de capas: 140MB/capa típico. Sin índice GGUF
    /// (módulo `unstable`) no hay tamaños reales por capa disponibles;
    /// la estimación se calibra con el tamaño real del modelo vía
    /// `set_overhead` si se necesita precisión.
    fn estimate_active_weights(&self) -> u64 {
        let estimated_per_layer = 140 * 1024 * 1024; // 140MB per layer
        estimated_per_layer * self.active_layers.len() as u64
    }

    /// Estimate KV cache size
    fn estimate_kv_cache(&self) -> u64 {
        // KV cache = tokens × per_token × active_layers
        self.kv_per_token * self.context_window as u64 * self.active_layers.len() as u64
    }

    /// Detect thrashing based on current metrics
    pub fn detect_thrashing(&mut self) -> ThrashingDetection {
        let current_metrics = self.metrics.collect();
        let working_set = self.estimate_working_set();

        // Add to history
        self.add_history_sample(
            working_set.clone(),
            current_metrics.memory.fault_rate,
            current_metrics.io.io_rate,
        );

        // Analyze factors
        let mut factors = Vec::new();
        let mut confidence: f64 = 0.0;

        // Factor 1: High memory pressure
        if current_metrics.memory.pressure_ratio > 0.85 {
            factors.push(ThrashingFactor::HighMemoryPressure);
            confidence += 0.3;
        }

        // Factor 2: High page fault rate
        if current_metrics.memory.fault_rate > 100.0 {
            factors.push(ThrashingFactor::HighPageFaultRate);
            confidence += 0.4;
        }

        // Factor 3: High I/O rate
        if current_metrics.io.io_rate > 10_000_000.0 {
            // 10MB/s
            factors.push(ThrashingFactor::HighIOWait);
            confidence += 0.2;
        }

        // Factor 4: Insufficient working set
        if working_set.ram_percentage > 90.0 {
            factors.push(ThrashingFactor::InsufficientWorkingSet);
            confidence += 0.3;
        }

        // Factor 5: Trend analysis (increasing fault rate)
        if self.is_fault_rate_increasing() {
            factors.push(ThrashingFactor::MemoryFragmentation);
            confidence += 0.2;
        }

        // Determine state based on factors and confidence
        let state = if confidence > 0.8 {
            ThrashingState::Severe
        } else if confidence > 0.6 {
            ThrashingState::Moderate
        } else if confidence > 0.3 {
            ThrashingState::Mild
        } else {
            ThrashingState::None
        };

        // Recommend action based on state
        let recommended_action = match state {
            ThrashingState::None => ThrashingAction::None,
            ThrashingState::Mild => ThrashingAction::IncreasePrefetch,
            ThrashingState::Moderate => ThrashingAction::ReduceWorkingSet,
            ThrashingState::Severe => ThrashingAction::EmergencyMode,
        };

        ThrashingDetection {
            state,
            confidence: confidence.min(1.0),
            factors,
            recommended_action,
        }
    }

    /// Add a sample to history
    fn add_history_sample(
        &mut self,
        working_set: WorkingSetBreakdown,
        fault_rate: f64,
        io_rate: f64,
    ) {
        let sample = WorkingSetSample {
            timestamp: Instant::now(),
            working_set,
            fault_rate,
            io_rate,
        };

        self.history.samples.push_back(sample);

        if self.history.samples.len() > self.history.max_samples {
            self.history.samples.pop_front();
        }
    }

    /// Check if fault rate is increasing over time
    ///
    /// Real: usa las 3 señales de cada muestra — pendiente temporal de
    /// fault_rate (timestamp), confirmación de I/O creciente (io_rate) y
    /// working set que no encogió (working_set.total).
    fn is_fault_rate_increasing(&self) -> bool {
        if self.history.samples.len() < 10 {
            return false;
        }

        let samples: Vec<_> = self.history.samples.iter().collect();
        let recent: Vec<_> = samples.iter().rev().take(5).collect();
        let older: Vec<_> = samples.iter().take(5).collect();
        let recent_avg: f64 = recent.iter().map(|s| s.fault_rate).sum::<f64>() / 5.0;
        let older_avg: f64 = older.iter().map(|s| s.fault_rate).sum::<f64>() / 5.0;

        // Ventana temporal REAL entre la muestra más antigua y la más
        // reciente — sin ella, muestras tomadas con 1ms de diferencia
        // producirían una falsa pendiente.
        let (Some(oldest), Some(newest)) = (older.first(), recent.last()) else {
            return false;
        };
        let window_secs = newest
            .timestamp
            .duration_since(oldest.timestamp)
            .as_secs_f64();
        if window_secs < 1.0 {
            return false; // muestras demasiado juntas: tendencia no confiable
        }

        // Pendiente real: faults/segundo por segundo.
        let fault_slope = (recent_avg - older_avg) / window_secs;

        // I/O creciente confirma que los faults son por disco (thrashing),
        // no ruido transitorio de asignación.
        let older_io: f64 = older.iter().map(|s| s.io_rate).sum::<f64>() / 5.0;
        let recent_io: f64 = recent.iter().map(|s| s.io_rate).sum::<f64>() / 5.0;

        // Working set que NO encogió: si encogió y faults igual suben,
        // la causa no es presión de RAM del proceso (no es thrashing).
        let older_ws: f64 = older
            .iter()
            .map(|s| s.working_set.total as f64)
            .sum::<f64>()
            / 5.0;
        let recent_ws: f64 = recent
            .iter()
            .map(|s| s.working_set.total as f64)
            .sum::<f64>()
            / 5.0;

        fault_slope > 5.0 && recent_io >= older_io && recent_ws >= older_ws
    }

    /// Get working set efficiency score (0.0-1.0)
    /// Higher means more efficient use of memory
    pub fn efficiency_score(&mut self) -> f64 {
        let working_set = self.estimate_working_set();
        let detection = self.detect_thrashing();

        // Base efficiency on RAM usage and thrashing state
        let ram_efficiency = if working_set.ram_percentage < 50.0 {
            1.0
        } else if working_set.ram_percentage < 75.0 {
            0.8
        } else if working_set.ram_percentage < 90.0 {
            0.5
        } else {
            0.2
        };

        // Penalize for thrashing
        let thrashing_penalty = match detection.state {
            ThrashingState::None => 0.0,
            ThrashingState::Mild => 0.2,
            ThrashingState::Moderate => 0.5,
            ThrashingState::Severe => 0.8,
        };

        let result = ram_efficiency - thrashing_penalty;
        if result < 0.0_f64 {
            0.0_f64
        } else {
            result
        }
    }

    /// Check if the current working set is sustainable
    pub fn is_sustainable(&mut self) -> bool {
        let working_set = self.estimate_working_set();
        let detection = self.detect_thrashing();

        // Sustainable if: not thrashing AND under memory pressure threshold
        !detection.state.is_thrashing() && working_set.ram_percentage < 80.0
    }

    /// Get recommended working set size
    pub fn recommended_working_set(&mut self) -> usize {
        let current_ram_percentage = self.estimate_working_set().ram_percentage;

        // Target 60-70% RAM usage for optimal performance
        if current_ram_percentage > 80.0 {
            // Aggressively reduce
            (self.active_layers.len() as f64 * 0.5) as usize
        } else if current_ram_percentage > 70.0 {
            // Moderate reduction
            (self.active_layers.len() as f64 * 0.75) as usize
        } else {
            // Current is fine
            self.active_layers.len()
        }
    }

    /// Update metrics and refresh state
    pub fn update(&mut self) {
        self.metrics.collect();
    }

    /// Get current metrics reference
    pub fn metrics(&self) -> &RuntimeMetricsCollector {
        &self.metrics
    }

    /// Get mutable metrics reference
    pub fn metrics_mut(&mut self) -> &mut RuntimeMetricsCollector {
        &mut self.metrics
    }
}

impl Default for WorkingSetEstimator {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_working_set_estimator_creation() {
        let estimator = WorkingSetEstimator::new();
        assert_eq!(estimator.active_layers.len(), 0);
        assert_eq!(estimator.context_window, 512);
    }

    #[test]
    fn test_working_set_estimation() {
        let mut estimator = WorkingSetEstimator::new();
        estimator.set_active_layers(vec![0, 1, 2]);

        let working_set = estimator.estimate_working_set();

        // Should have some working set estimate
        assert!(working_set.total > 0);
        assert!(working_set.weights_active > 0);
        assert!(working_set.kv_cache > 0);
    }

    #[test]
    fn test_thrashing_detection() {
        let mut estimator = WorkingSetEstimator::new();
        estimator.set_active_layers(vec![0, 1, 2]);

        let detection = estimator.detect_thrashing();

        // Should return a detection result
        assert!(matches!(
            detection.state,
            ThrashingState::None | ThrashingState::Mild
        ));
        assert!(detection.confidence >= 0.0 && detection.confidence <= 1.0);
    }

    #[test]
    fn test_thrashing_state_properties() {
        assert!(!ThrashingState::None.is_thrashing());
        assert!(ThrashingState::Mild.is_thrashing());
        assert!(ThrashingState::Moderate.is_thrashing());
        assert!(ThrashingState::Severe.is_thrashing());

        assert_eq!(ThrashingState::None.severity(), 0);
        assert_eq!(ThrashingState::Severe.severity(), 3);
    }

    #[test]
    fn test_efficiency_score() {
        let mut estimator = WorkingSetEstimator::new();

        let score = estimator.efficiency_score();

        // Should be between 0.0 and 1.0
        assert!((0.0..=1.0).contains(&score));
    }

    #[test]
    fn test_recommended_working_set() {
        let mut estimator = WorkingSetEstimator::new();
        estimator.set_active_layers(vec![0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);

        let recommended = estimator.recommended_working_set();

        // Should recommend something reasonable
        assert!(recommended <= 10);
    }
}
