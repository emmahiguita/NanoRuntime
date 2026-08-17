//! Adaptive KV Policy — KIVI + H2O inspired token importance-based KV management
//!
//! Extends the existing hierarchical KV cache with token importance scoring
//! inspired by KIVI (critical token identification) and H2O (heavy-hitter optimization).
//!
//! This is NOT a replacement for hierarchical_kv.rs — it's an ENHANCEMENT that adds:
//! - Token importance scoring (not just position-based)
//! - Heavy-hitter identification (tokens accessed frequently)
//! - Adaptive tier assignment based on both position AND importance
//! - Dynamic compression adjustment based on quality metrics
//!
//! ## KIVI + H2O Concepts Applied
//!
//! - **KIVI**: Identify critical tokens that cannot be quantized aggressively
//! - **H2O**: Identify heavy-hitter tokens that are accessed repeatedly
//! - **Hybrid**: Combine position-based hierarchy with importance-based exceptions

use crate::memory_engine::hierarchical_kv::{HierarchicalKvCache, KvTier};
use crate::memory_engine::runtime_metrics::RuntimeMetricsCollector;
use std::collections::HashMap;

/// Token importance level (inspired by KIVI)
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum TokenImportance {
    /// Critical token (cannot compress without quality loss)
    Critical,
    /// High importance (heavy-hitter, accessed frequently)
    High,
    /// Normal importance (standard position-based)
    Normal,
    /// Low importance (can be compressed aggressively)
    Low,
}

/// Token access pattern for heavy-hitter detection
#[derive(Debug, Clone)]
pub struct TokenAccessPattern {
    /// Number of times this token was accessed
    pub access_count: u64,
    /// Last access time (position in sequence)
    pub last_access_position: usize,
    /// Access frequency (accesses per 1000 tokens)
    pub access_frequency: f64,
}

/// Enhanced KV tier with importance context
#[derive(Debug, Clone)]
pub struct AdaptiveKvTier {
    /// Base tier from hierarchical KV
    pub base_tier: KvTier,
    /// Token importance override
    pub importance: TokenImportance,
    /// Final assigned tier (combination of base + importance)
    pub final_tier: KvTier,
}

/// Adaptive KV policy configuration
#[derive(Debug, Clone)]
pub struct AdaptiveKvConfig {
    /// KIVI threshold: percentage of most important tokens to mark as critical
    pub critical_percentage: f32,
    /// H2O threshold: access frequency to mark as heavy-hitter
    pub heavy_hitter_threshold: f64,
    /// Minimum RAM (MB) to enable adaptive KV
    pub enable_threshold_mb: u64,
    /// Quality sensitivity (0.0 = aggressive, 1.0 = conservative)
    pub quality_sensitivity: f32,
}

impl Default for AdaptiveKvConfig {
    fn default() -> Self {
        Self {
            critical_percentage: 0.1,    // Top 10% of tokens are critical
            heavy_hitter_threshold: 5.0, // 5+ accesses per 1000 tokens = heavy-hitter
            enable_threshold_mb: 2000,   // Enable adaptive with 2GB+ RAM
            quality_sensitivity: 0.5,    // Balanced quality/performance
        }
    }
}

/// Adaptive KV policy manager
pub struct AdaptiveKvPolicy {
    /// Base hierarchical KV cache
    hierarchical_kv: HierarchicalKvCache,
    /// Token importance scores
    token_importance: HashMap<usize, TokenImportance>,
    /// Token access patterns
    access_patterns: HashMap<usize, TokenAccessPattern>,
    /// Configuration
    config: AdaptiveKvConfig,
    /// Total tokens processed
    total_tokens: usize,
    /// Runtime metrics for quality feedback
    metrics: RuntimeMetricsCollector,
}

impl AdaptiveKvPolicy {
    /// Create new adaptive KV policy
    pub fn new(hierarchical_kv: HierarchicalKvCache, config: AdaptiveKvConfig) -> Self {
        Self {
            hierarchical_kv,
            token_importance: HashMap::new(),
            access_patterns: HashMap::new(),
            config,
            total_tokens: 0,
            metrics: RuntimeMetricsCollector::new(),
        }
    }

    /// Create with default config
    pub fn with_defaults(hierarchical_kv: HierarchicalKvCache) -> Self {
        Self::new(hierarchical_kv, AdaptiveKvConfig::default())
    }

    /// Record token access (for heavy-hitter detection)
    pub fn record_access(&mut self, token_position: usize) {
        let pattern = self
            .access_patterns
            .entry(token_position)
            .or_insert_with(|| TokenAccessPattern {
                access_count: 0,
                last_access_position: token_position,
                access_frequency: 0.0,
            });

        pattern.access_count += 1;
        pattern.last_access_position = token_position;

        // Update frequency (exponential moving average)
        let new_freq = if self.total_tokens > 0 {
            (pattern.access_count as f64 / self.total_tokens as f64) * 1000.0
        } else {
            0.0
        };
        pattern.access_frequency = pattern.access_frequency * 0.9 + new_freq * 0.1;

        // Clone pattern for importance calculation to avoid borrow issues
        let pattern_clone = pattern.clone();

        // Update importance based on access pattern
        let importance = self.calculate_importance(token_position, &pattern_clone);
        self.token_importance.insert(token_position, importance);
    }

    /// Calculate token importance (KIVI-inspired)
    fn calculate_importance(
        &self,
        position: usize,
        pattern: &TokenAccessPattern,
    ) -> TokenImportance {
        // Base importance from position (recent tokens are more important)
        let position_importance = if position < 256 {
            TokenImportance::Normal
        } else {
            TokenImportance::Low
        };

        // Heavy-hitter bonus (H2O-inspired)
        let heavy_hitter_bonus = if pattern.access_frequency > self.config.heavy_hitter_threshold {
            1 // Upgrade importance by 1 level
        } else {
            0
        };

        // Combine position + access pattern
        let base_level = match position_importance {
            TokenImportance::Critical => 3,
            TokenImportance::High => 2,
            TokenImportance::Normal => 1,
            TokenImportance::Low => 0,
        };

        let adjusted_level = (base_level + heavy_hitter_bonus).min(3);

        match adjusted_level {
            3 => TokenImportance::Critical,
            2 => TokenImportance::High,
            1 => TokenImportance::Normal,
            _ => TokenImportance::Low,
        }
    }

    /// Get adaptive tier for a token (combines hierarchy + importance)
    pub fn get_adaptive_tier(
        &self,
        token_position: usize,
        available_ram_mb: u64,
    ) -> AdaptiveKvTier {
        let base_tier = self
            .hierarchical_kv
            .tier_for_position(token_position, available_ram_mb);
        let importance = self
            .token_importance
            .get(&token_position)
            .copied()
            .unwrap_or(TokenImportance::Normal);

        // Adaptive adjustment: critical tokens stay higher tier
        let final_tier = match (base_tier, importance) {
            (KvTier::Int2, TokenImportance::Critical) => KvTier::Int4, // Critical: upgrade from Int2 to Int4
            (KvTier::Int2, TokenImportance::High) => KvTier::Int4, // High: upgrade from Int2 to Int4
            (KvTier::Evicted, TokenImportance::Critical) => KvTier::Int4, // Critical: don't evict
            (KvTier::Evicted, TokenImportance::High) => KvTier::Int2, // High: downgrade eviction to Int2
            (KvTier::Fp16, TokenImportance::Low) => KvTier::Int4, // Low: downgrade Fp16 to Int4 to save RAM
            _ => base_tier,                                       // Otherwise keep base tier
        };

        AdaptiveKvTier {
            base_tier,
            importance,
            final_tier,
        }
    }

    /// Calculate critical tokens (KIVI-inspired)
    pub fn calculate_critical_tokens(&self) -> Vec<usize> {
        let critical_count = (self.total_tokens as f32 * self.config.critical_percentage) as usize;

        let mut importance_scores: Vec<(usize, i32)> = self
            .token_importance
            .iter()
            .map(|(&pos, &imp)| {
                (
                    pos,
                    match imp {
                        TokenImportance::Critical => 3,
                        TokenImportance::High => 2,
                        TokenImportance::Normal => 1,
                        TokenImportance::Low => 0,
                    },
                )
            })
            .collect();

        importance_scores.sort_by_key(|&(_, score)| std::cmp::Reverse(score)); // Sort descending

        importance_scores
            .iter()
            .take(critical_count)
            .map(|(pos, _)| *pos)
            .collect()
    }

    /// Calculate heavy-hitter tokens (H2O-inspired)
    pub fn calculate_heavy_hitters(&self) -> Vec<usize> {
        self.access_patterns
            .iter()
            .filter(|(_, pattern)| pattern.access_frequency > self.config.heavy_hitter_threshold)
            .map(|(pos, _)| *pos)
            .collect()
    }

    /// Update policy based on quality metrics
    pub fn update_quality_sensitivity(&mut self, quality_drop_pct: f32) {
        // If quality is degrading, become more conservative
        if quality_drop_pct > 1.0 {
            self.config.quality_sensitivity = (self.config.quality_sensitivity + 0.2).min(1.0);
        } else if quality_drop_pct < 0.5 {
            self.config.quality_sensitivity = (self.config.quality_sensitivity - 0.1).max(0.0);
        }
    }

    /// Get adaptive KV statistics
    pub fn get_stats(&self) -> AdaptiveKvStats {
        let critical_count = self.calculate_critical_tokens().len();
        let heavy_hitter_count = self.calculate_heavy_hitters().len();

        AdaptiveKvStats {
            total_tokens: self.total_tokens,
            critical_tokens: critical_count,
            heavy_hitters: heavy_hitter_count,
            quality_sensitivity: self.config.quality_sensitivity,
        }
    }

    /// Check if adaptive KV is enabled based on RAM
    pub fn is_enabled(&self, available_ram_mb: u64) -> bool {
        // Presión REAL del sistema > 0.9: aunque haya RAM nominal, el
        // sistema está paginando — desactivar KV adaptativo evita sumar
        // presión a un kernel que ya está thrashing.
        available_ram_mb >= self.config.enable_threshold_mb && self.metrics.memory_pressure() < 0.9
    }

    /// Get configuration
    pub fn config(&self) -> &AdaptiveKvConfig {
        &self.config
    }

    /// Update configuration
    pub fn set_config(&mut self, config: AdaptiveKvConfig) {
        self.config = config;
    }

    /// Get base hierarchical KV reference
    pub fn hierarchical_kv(&self) -> &HierarchicalKvCache {
        &self.hierarchical_kv
    }
}

/// Adaptive KV statistics
#[derive(Debug, Clone)]
pub struct AdaptiveKvStats {
    pub total_tokens: usize,
    pub critical_tokens: usize,
    pub heavy_hitters: usize,
    pub quality_sensitivity: f32,
}

impl Default for AdaptiveKvPolicy {
    fn default() -> Self {
        Self::with_defaults(HierarchicalKvCache::new(32, 128))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_adaptive_kv_creation() {
        let hierarchical_kv = HierarchicalKvCache::new(32, 128);
        let policy = AdaptiveKvPolicy::with_defaults(hierarchical_kv);

        assert_eq!(policy.total_tokens, 0);
        assert_eq!(policy.config().critical_percentage, 0.1);
    }

    #[test]
    fn test_token_importance_calculation() {
        let hierarchical_kv = HierarchicalKvCache::new(32, 128);
        let policy = AdaptiveKvPolicy::with_defaults(hierarchical_kv);

        // Recent token with high access frequency
        let pattern = TokenAccessPattern {
            access_count: 100,
            last_access_position: 10,
            access_frequency: 10.0, // High frequency
        };

        let importance = policy.calculate_importance(10, &pattern);

        // Should be High due to heavy-hitter bonus
        assert_eq!(importance, TokenImportance::High);
    }

    #[test]
    fn test_adaptive_tier_upgrade() {
        let hierarchical_kv = HierarchicalKvCache::new(32, 128);
        let mut policy = AdaptiveKvPolicy::with_defaults(hierarchical_kv);

        // Set critical importance for a position
        policy
            .token_importance
            .insert(1000, TokenImportance::Critical);

        let adaptive_tier = policy.get_adaptive_tier(1000, 4000);

        // Critical token should be upgraded from Int2 to Int4
        assert_eq!(adaptive_tier.base_tier, KvTier::Int2);
        assert_eq!(adaptive_tier.importance, TokenImportance::Critical);
        assert_eq!(adaptive_tier.final_tier, KvTier::Int4);
    }

    #[test]
    fn test_critical_tokens_calculation() {
        let hierarchical_kv = HierarchicalKvCache::new(32, 128);
        let mut policy = AdaptiveKvPolicy::with_defaults(hierarchical_kv);

        // Add some importance scores
        for i in 0..100 {
            let importance = if i < 10 {
                TokenImportance::Critical
            } else {
                TokenImportance::Normal
            };
            policy.token_importance.insert(i, importance);
        }

        policy.total_tokens = 100;

        let critical = policy.calculate_critical_tokens();

        // Should get top 10% = 10 tokens
        assert_eq!(critical.len(), 10);
    }

    #[test]
    fn test_heavy_hitter_detection() {
        let hierarchical_kv = HierarchicalKvCache::new(32, 128);
        let mut policy = AdaptiveKvPolicy::with_defaults(hierarchical_kv);

        // Add heavy-hitter pattern
        policy.access_patterns.insert(
            50,
            TokenAccessPattern {
                access_count: 100,
                last_access_position: 50,
                access_frequency: 10.0,
            },
        );

        let heavy_hitters = policy.calculate_heavy_hitters();

        assert!(heavy_hitters.contains(&50));
    }

    #[test]
    fn test_quality_sensitivity_adjustment() {
        let hierarchical_kv = HierarchicalKvCache::new(32, 128);
        let mut policy = AdaptiveKvPolicy::with_defaults(hierarchical_kv);

        assert_eq!(policy.config().quality_sensitivity, 0.5);

        policy.update_quality_sensitivity(2.0); // Quality dropping

        assert!(policy.config().quality_sensitivity > 0.5);
    }
}
