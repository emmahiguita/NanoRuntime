//! NGRAM-Scheduler Integration — connects speculative decoding with memory scheduling
//!
//! Integrates existing NGRAM acceptance rate tracking with the AdaptiveScheduler
//! to make memory decisions based on speculative decoding efficiency.
//!
//! This is NOT a duplicate of existing acceptance rate logic — it's the BRIDGE
//! between:
//! - speculative_decoder.rs (SpeculativeStats, QualityGuard)
//! - runtime_metrics.rs (NgramMetrics)  
//! - adaptive_scheduler.rs (AdaptiveScheduler)
//!
//! ## Logic (No Redundancy)
//!
//! Uses existing acceptance rate from speculative decoder as a factor in memory
//! scheduling decisions:
//! - High acceptance rate → can be more aggressive with offload (speculative saves compute)
//! - Low acceptance rate → must be conservative (speculative overhead without benefit)
//! - Tracks bytes_read_per_token to validate Samsung hypothesis about storage-bound regime

use crate::memory_engine::adaptive_scheduler::AdaptiveScheduler;
use crate::memory_engine::runtime_metrics::RuntimeMetricsCollector;

/// NGRAM-aware scheduling decision
#[derive(Debug, Clone)]
pub struct NgramSchedulingDecision {
    /// Recommended scheduling strategy adjustment
    pub strategy_adjustment: StrategyAdjustment,
    /// Whether to increase prefetch aggressiveness
    pub increase_prefetch: bool,
    /// Whether to reduce context window
    pub reduce_context: bool,
    /// Confidence in this decision (0.0-1.0)
    pub confidence: f64,
}

/// Strategy adjustment based on NGRAM performance
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum StrategyAdjustment {
    /// No adjustment needed
    None,
    /// Be more aggressive (high acceptance rate = speculative is working)
    MoreAggressive,
    /// Be more conservative (low acceptance rate = speculative overhead)
    MoreConservative,
    /// Maintain current strategy
    Maintain,
}

/// Integration between NGRAM metrics and memory scheduling
pub struct NgramSchedulerIntegration {
    /// Runtime metrics collector (has NgramMetrics)
    metrics: RuntimeMetricsCollector,
    /// Historical acceptance rates for trend analysis
    acceptance_history: Vec<f32>,
    /// Last decision made
    last_decision: Option<NgramSchedulingDecision>,
    /// Threshold for considering NGRAM "effective" (default 0.4)
    effectiveness_threshold: f64,
    /// Bytes read per useful token threshold (for Samsung hypothesis validation)
    bytes_per_token_threshold: f64,
}

impl NgramSchedulerIntegration {
    /// Create new integration
    pub fn new(metrics: RuntimeMetricsCollector) -> Self {
        Self {
            metrics,
            acceptance_history: Vec::with_capacity(20),
            last_decision: None,
            effectiveness_threshold: 0.4, // 40% acceptance rate threshold
            bytes_per_token_threshold: 8192.0, // 8KB per token threshold
        }
    }

    /// Get current NGRAM metrics from runtime metrics
    pub fn current_ngram_metrics(&mut self) -> crate::memory_engine::runtime_metrics::NgramMetrics {
        let current_metrics = self.metrics.collect();
        current_metrics.ngram
    }

    /// Analyze NGRAM performance and make scheduling recommendation
    pub fn analyze_and_recommend(&mut self) -> NgramSchedulingDecision {
        let ngram = self.current_ngram_metrics();

        // Add to history
        self.acceptance_history.push(ngram.acceptance_rate as f32);
        if self.acceptance_history.len() > 20 {
            self.acceptance_history.remove(0);
        }

        // Calculate decision
        let decision = self.calculate_decision(&ngram);
        self.last_decision = Some(decision.clone());

        decision
    }

    /// Calculate scheduling decision based on NGRAM metrics
    fn calculate_decision(
        &self,
        ngram: &crate::memory_engine::runtime_metrics::NgramMetrics,
    ) -> NgramSchedulingDecision {
        let acceptance_rate = ngram.acceptance_rate;
        let bytes_per_token = ngram.bytes_read_per_token;

        // Calculate trend (is acceptance improving or degrading?)
        let trend = self.calculate_acceptance_trend();

        // Decision logic
        let (adjustment, increase_prefetch, reduce_context, confidence) =
            if acceptance_rate > self.effectiveness_threshold {
                // High acceptance rate → NGRAM is effective
                // Can be more aggressive with memory offload
                if trend > 0.0 {
                    // Improving trend → be more aggressive
                    (
                        StrategyAdjustment::MoreAggressive,
                        true,  // Increase prefetch
                        false, // Keep context
                        0.8,
                    )
                } else {
                    // Stable high acceptance → maintain with slight aggression
                    (
                        StrategyAdjustment::Maintain,
                        true,  // Increase prefetch
                        false, // Keep context
                        0.7,
                    )
                }
            } else if acceptance_rate > 0.2 {
                // Medium acceptance rate → be conservative
                (
                    StrategyAdjustment::MoreConservative,
                    false, // Don't increase prefetch
                    false, // Keep context for now
                    0.6,
                )
            } else {
                // Low acceptance rate → NGRAM not effective
                // Must be very conservative with memory
                (
                    StrategyAdjustment::MoreConservative,
                    false, // Don't increase prefetch
                    true,  // Reduce context to save memory
                    0.9,   // High confidence
                )
            };

        // Samsung hypothesis validation: check if we're in storage-bound regime
        let _samsung_indicated = bytes_per_token < self.bytes_per_token_threshold;

        NgramSchedulingDecision {
            strategy_adjustment: adjustment,
            increase_prefetch,
            reduce_context,
            confidence,
        }
    }

    /// Calculate acceptance rate trend (positive = improving, negative = degrading)
    fn calculate_acceptance_trend(&self) -> f32 {
        if self.acceptance_history.len() < 5 {
            return 0.0;
        }

        let recent: f32 = self.acceptance_history.iter().rev().take(5).sum::<f32>() / 5.0;
        let older: f32 = self.acceptance_history.iter().take(5).sum::<f32>() / 5.0;

        recent - older
    }

    /// Apply NGRAM decision to AdaptiveScheduler
    pub fn apply_to_scheduler(
        &self,
        scheduler: &mut AdaptiveScheduler,
        decision: &NgramSchedulingDecision,
    ) {
        match decision.strategy_adjustment {
            StrategyAdjustment::MoreAggressive => {
                // NGRAM is working well → can offload more aggressively
                // This is achieved by simulating a quality drop to trigger aggressive scheduling
                // (the scheduler becomes more aggressive when quality drops, assuming we need RAM)
                scheduler.adjust_strategy(1.5); // Simulate moderate quality drop
            }
            StrategyAdjustment::MoreConservative => {
                // NGRAM not working → need more RAM for efficiency
                scheduler.adjust_strategy(0.0); // Simulate no quality drop → conservative
            }
            StrategyAdjustment::Maintain => {
                // Keep current strategy
            }
            StrategyAdjustment::None => {
                // No change
            }
        }
    }

    /// Check if Samsung hypothesis appears valid (low bytes per token with good acceptance)
    pub fn validate_samsung_hypothesis(&mut self) -> bool {
        let ngram = self.current_ngram_metrics();

        // Samsung hypothesis: high acceptance + low bytes per token = storage-bound amortization
        ngram.acceptance_rate > 0.5 && ngram.bytes_read_per_token < self.bytes_per_token_threshold
    }

    /// Get acceptance rate trend description
    pub fn acceptance_trend_description(&self) -> String {
        let trend = self.calculate_acceptance_trend();

        if trend > 0.1 {
            "Improving".to_string()
        } else if trend < -0.1 {
            "Degrading".to_string()
        } else {
            "Stable".to_string()
        }
    }

    /// Reset history (useful when changing models or context)
    pub fn reset(&mut self) {
        self.acceptance_history.clear();
        self.last_decision = None;
    }

    /// Get current effectiveness threshold
    pub fn effectiveness_threshold(&self) -> f64 {
        self.effectiveness_threshold
    }

    /// Set custom effectiveness threshold
    pub fn set_effectiveness_threshold(&mut self, threshold: f64) {
        self.effectiveness_threshold = threshold.clamp(0.0, 1.0);
    }
}

impl Default for NgramSchedulerIntegration {
    fn default() -> Self {
        Self::new(RuntimeMetricsCollector::new())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_integration_creation() {
        let metrics = RuntimeMetricsCollector::new();
        let integration = NgramSchedulerIntegration::new(metrics);

        assert_eq!(integration.effectiveness_threshold(), 0.4);
        assert!(integration.acceptance_history.is_empty());
    }

    #[test]
    fn test_ngram_metrics_retrieval() {
        let metrics = RuntimeMetricsCollector::new();
        let mut integration = NgramSchedulerIntegration::new(metrics);

        let ngram = integration.current_ngram_metrics();
        // Should return default metrics (all zeros)
        assert_eq!(ngram.total_attempts, 0);
        assert_eq!(ngram.acceptance_rate, 0.0);
    }

    #[test]
    fn test_decision_with_high_acceptance() {
        let mut metrics = RuntimeMetricsCollector::new();
        // Simulate high acceptance rate
        for _ in 0..10 {
            metrics.record_ngram_attempt(true, 1024);
        }

        let mut integration = NgramSchedulerIntegration::new(metrics);
        let decision = integration.analyze_and_recommend();

        // High acceptance should lead to aggressive strategy
        assert!(matches!(
            decision.strategy_adjustment,
            StrategyAdjustment::MoreAggressive | StrategyAdjustment::Maintain
        ));
        assert!(decision.increase_prefetch);
    }

    #[test]
    fn test_decision_with_low_acceptance() {
        let mut metrics = RuntimeMetricsCollector::new();
        // Simulate low acceptance rate
        for _ in 0..10 {
            metrics.record_ngram_attempt(false, 0);
        }

        let mut integration = NgramSchedulerIntegration::new(metrics);
        let decision = integration.analyze_and_recommend();

        // Low acceptance should lead to conservative strategy
        assert!(matches!(
            decision.strategy_adjustment,
            StrategyAdjustment::MoreConservative
        ));
        assert!(decision.reduce_context);
    }

    #[test]
    fn test_acceptance_trend() {
        let mut integration = NgramSchedulerIntegration::new(RuntimeMetricsCollector::new());

        // Add improving trend
        for i in 0..10 {
            integration.acceptance_history.push(0.3 + (i as f32 * 0.05));
        }

        let trend = integration.calculate_acceptance_trend();
        assert!(trend > 0.0);
    }

    #[test]
    fn test_samsung_hypothesis_validation() {
        let mut metrics = RuntimeMetricsCollector::new();
        // Simulate high acceptance with low bytes per token
        for _ in 0..10 {
            metrics.record_ngram_attempt(true, 1024); // 1KB per token
        }

        let mut integration = NgramSchedulerIntegration::new(metrics);
        let is_valid = integration.validate_samsung_hypothesis();

        // Should be valid with high acceptance and low bytes per token
        assert!(is_valid);
    }

    #[test]
    fn test_reset() {
        let mut metrics = RuntimeMetricsCollector::new();
        metrics.record_ngram_attempt(true, 1024);

        let mut integration = NgramSchedulerIntegration::new(metrics);
        integration.analyze_and_recommend();

        assert!(!integration.acceptance_history.is_empty());

        integration.reset();

        assert!(integration.acceptance_history.is_empty());
        assert!(integration.last_decision.is_none());
    }
}
