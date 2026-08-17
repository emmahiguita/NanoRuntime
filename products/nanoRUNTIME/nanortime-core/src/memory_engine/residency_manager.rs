//! Residency Manager — Control plane for page residency decisions
//!
//! Replaces simple MADV_DONTNEED with a state machine for precise control
//! over which pages to keep, cool, reclaim, or prefetch. This is the heart
//! of the control plane philosophy: observe the system and adapt workload
//! before thrashing occurs.
//!
//! ## States
//!
//! - **KEEP**: Pages are hot and should remain in RAM (high access frequency)
//! - **COLD**: Pages are cooling down but may be accessed again soon (transitional)
//! - **RECLAIM**: Pages are candidates for eviction (low access frequency, safe to reclaim)
//! - **PREFETCH**: Pages not in RAM but predicted to be needed soon (proactive loading)
//!
//! ## Policy
//!
//! The residency manager uses access patterns, working set estimates, and
//! hardware constraints to make decisions. It works with the OS paginator
//! to enforce these decisions at the kernel level.

use crate::memory_engine::gguf_layout::{ByteRange, NanoModelIndex};
use crate::memory_engine::os_paginator::OSMemoryPaginator;
use std::collections::HashMap;
use std::time::{Duration, Instant};

/// Residency state for a page or layer
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ResidencyState {
    /// Pages are hot and should remain in RAM
    Keep,
    /// Pages are cooling down but may be accessed again
    Cold,
    /// Pages are candidates for eviction
    Reclaim,
    /// Pages not in RAM but predicted to be needed
    Prefetch,
}

impl ResidencyState {
    /// Returns whether the state indicates pages should be in RAM
    pub fn should_be_resident(&self) -> bool {
        matches!(self, ResidencyState::Keep | ResidencyState::Cold)
    }

    /// Returns whether the state indicates pages should be prefetched
    pub fn should_prefetch(&self) -> bool {
        matches!(self, ResidencyState::Prefetch)
    }

    /// Returns whether the state indicates pages can be reclaimed
    pub fn can_reclaim(&self) -> bool {
        matches!(self, ResidencyState::Reclaim)
    }
}

/// Access pattern tracking for residency decisions
#[derive(Debug, Clone)]
pub struct AccessPattern {
    /// Last access time
    pub last_access: Instant,
    /// Access frequency (accesses per second)
    pub frequency: f64,
    /// Total access count
    pub access_count: u64,
    /// Whether the pattern is sequential
    pub is_sequential: bool,
}

impl Default for AccessPattern {
    fn default() -> Self {
        Self {
            last_access: Instant::now(),
            frequency: 0.0,
            access_count: 0,
            is_sequential: false,
        }
    }
}

/// Residency information for a layer
#[derive(Debug, Clone)]
pub struct ResidencyInfo {
    /// Current residency state
    pub state: ResidencyState,
    /// Access pattern tracking
    pub access_pattern: AccessPattern,
    /// Priority score (higher = more important to keep)
    pub priority: f64,
    /// Memory pressure threshold for this layer
    pub pressure_threshold: f64,
    /// Time in current state
    pub state_duration: Duration,
}

/// Residency policy configuration
#[derive(Debug, Clone)]
pub struct ResidencyPolicy {
    /// Cooling period before marking as RECLAIM (seconds)
    pub cooling_period_secs: f64,
    /// Minimum access frequency to keep as HOT (accesses/sec)
    pub hot_threshold: f64,
    /// Memory pressure threshold to start aggressive reclamation (0.0-1.0)
    pub pressure_threshold: f64,
    /// Prefetch lookahead (number of layers)
    pub prefetch_lookahead: usize,
    /// Whether to use sequential access hints
    pub use_sequential_hints: bool,
}

impl Default for ResidencyPolicy {
    fn default() -> Self {
        Self {
            cooling_period_secs: 5.0,
            hot_threshold: 0.1,       // 0.1 accesses/sec minimum
            pressure_threshold: 0.75, // Start reclaiming at 75% RAM pressure
            prefetch_lookahead: 2,
            use_sequential_hints: true,
        }
    }
}

/// Residency Manager — control plane for page residency
pub struct ResidencyManager {
    /// Layer residency information indexed by layer ID
    layer_residency: HashMap<usize, ResidencyInfo>,
    /// Model index for layout information
    model_index: Option<NanoModelIndex>,
    /// OS paginator for enforcing decisions
    paginator: Option<OSMemoryPaginator>,
    /// Residency policy
    policy: ResidencyPolicy,
    /// Global memory pressure (0.0-1.0)
    memory_pressure: f64,
    /// Statistics
    stats: ResidencyStats,
}

/// Residency statistics for monitoring
#[derive(Debug, Clone, Default)]
pub struct ResidencyStats {
    /// Number of layers in KEEP state
    pub keep_count: usize,
    /// Number of layers in COLD state
    pub cold_count: usize,
    /// Number of layers in RECLAIM state
    pub reclaim_count: usize,
    /// Number of layers in PREFETCH state
    pub prefetch_count: usize,
    /// Total state transitions
    pub total_transitions: u64,
    /// Prefetch hits
    pub prefetch_hits: u64,
    /// Prefetch misses
    pub prefetch_misses: u64,
}

impl ResidencyManager {
    /// Create a new residency manager
    pub fn new(policy: ResidencyPolicy) -> Self {
        Self {
            layer_residency: HashMap::new(),
            model_index: None,
            paginator: None,
            policy,
            memory_pressure: 0.0,
            stats: ResidencyStats::default(),
        }
    }

    /// Create with default policy
    pub fn with_defaults() -> Self {
        Self::new(ResidencyPolicy::default())
    }

    /// Initialize with model index
    pub fn with_model_index(mut self, model_index: NanoModelIndex) -> Self {
        self.model_index = Some(model_index);
        self
    }

    /// Initialize with OS paginator
    pub fn with_paginator(mut self, paginator: OSMemoryPaginator) -> Self {
        self.paginator = Some(paginator);
        self
    }

    /// Register a layer for residency management
    pub fn register_layer(&mut self, layer_id: usize, initial_priority: f64) {
        let residency_info = ResidencyInfo {
            state: ResidencyState::Prefetch, // Start as prefetch
            access_pattern: AccessPattern::default(),
            priority: initial_priority,
            pressure_threshold: self.policy.pressure_threshold,
            state_duration: Duration::ZERO,
        };
        self.layer_residency.insert(layer_id, residency_info);
    }

    /// Record access to a layer
    pub fn record_access(&mut self, layer_id: usize, is_sequential: bool) {
        if let Some(info) = self.layer_residency.get_mut(&layer_id) {
            let now = Instant::now();
            let time_since_last = now.duration_since(info.access_pattern.last_access);

            // Update access pattern
            info.access_pattern.last_access = now;
            info.access_pattern.access_count += 1;
            info.access_pattern.is_sequential = is_sequential;

            // Calculate frequency (exponential moving average)
            if time_since_last.as_secs_f64() > 0.0 {
                let instant_freq = 1.0 / time_since_last.as_secs_f64();
                info.access_pattern.frequency =
                    info.access_pattern.frequency * 0.9 + instant_freq * 0.1;
            }

            // Check if this was a prefetch hit
            if info.state == ResidencyState::Prefetch {
                self.stats.prefetch_hits += 1;
                self.transition_state(layer_id, ResidencyState::Keep);
            }
        }
    }

    /// Update residency states based on current conditions
    pub fn update_states(&mut self) {
        let now = Instant::now();
        let mut transitions = Vec::new();

        // First, collect all potential transitions with the data needed for calculation
        let mut layer_data = Vec::new();
        for (&layer_id, info) in self.layer_residency.iter() {
            // Update state duration
            let state_duration = now.duration_since(info.access_pattern.last_access);

            layer_data.push((
                layer_id,
                info.state,
                state_duration,
                info.access_pattern.frequency,
                info.access_pattern.is_sequential,
                info.priority,
            ));
        }

        // Calculate new states based on collected data
        for (layer_id, current_state, state_duration, frequency, is_sequential, priority) in
            layer_data
        {
            let time_since_access = state_duration.as_secs_f64();
            let new_state = self.calculate_next_state_with_data(
                current_state,
                time_since_access,
                frequency,
                is_sequential,
                priority,
            );

            if new_state != current_state {
                transitions.push((layer_id, new_state));
            }
        }

        // Apply transitions and update durations
        for (layer_id, new_state) in transitions {
            if let Some(info) = self.layer_residency.get_mut(&layer_id) {
                info.state = new_state;
                info.state_duration = Duration::ZERO;
                self.stats.total_transitions += 1;

                // Enforce state at OS level if paginator is available
                if let (Some(paginator), Some(model_index)) = (&self.paginator, &self.model_index) {
                    if let Some(layer_range) = model_index.get_layer_range(layer_id) {
                        self.enforce_state(paginator, layer_range, new_state);
                    }
                }
            }
        }

        // Update statistics
        self.update_stats();
    }

    /// Calculate the next state for a layer based on current conditions
    fn calculate_next_state_with_data(
        &self,
        current_state: ResidencyState,
        time_since_access: f64,
        frequency: f64,
        is_sequential: bool,
        priority: f64,
    ) -> ResidencyState {
        // High memory pressure → aggressive reclamation.
        // Bajo presión severa la transición Keep→Cold es INMEDIATA: en
        // móvil el OOM killer actúa en segundos, no hay cooling period
        // de cortesía. Cold→Reclaim conserva la ventana de verificación.
        if self.memory_pressure > self.policy.pressure_threshold {
            if current_state == ResidencyState::Keep {
                return ResidencyState::Cold;
            }
            if current_state == ResidencyState::Cold
                && time_since_access > self.policy.cooling_period_secs * 2.0
            {
                return ResidencyState::Reclaim;
            }
        }

        // Normal operation based on access patterns
        match current_state {
            ResidencyState::Keep => {
                // Keep → Cold if not accessed recently and frequency is low
                if time_since_access > self.policy.cooling_period_secs
                    && frequency < self.policy.hot_threshold
                {
                    ResidencyState::Cold
                } else {
                    ResidencyState::Keep
                }
            }
            ResidencyState::Cold => {
                // Cold → Reclaim if cooling period exceeded
                if time_since_access > self.policy.cooling_period_secs * 2.0 {
                    ResidencyState::Reclaim
                }
                // Cold → Keep if accessed again
                else if time_since_access < 1.0 {
                    ResidencyState::Keep
                } else {
                    ResidencyState::Cold
                }
            }
            ResidencyState::Reclaim => {
                // Reclaim → Prefetch if high priority or predicted access
                if priority > 0.8 || self.is_predicted_access(priority, is_sequential) {
                    ResidencyState::Prefetch
                } else {
                    ResidencyState::Reclaim
                }
            }
            ResidencyState::Prefetch => {
                // Prefetch → Keep once loaded (handled in record_access)
                ResidencyState::Prefetch
            }
        }
    }

    /// Check if a layer is predicted to be accessed based on patterns
    fn is_predicted_access(&self, priority: f64, is_sequential: bool) -> bool {
        // Simple prediction: high priority + sequential pattern
        priority > 0.7 && is_sequential
    }

    /// Transition a layer to a new state
    fn transition_state(&mut self, layer_id: usize, new_state: ResidencyState) {
        if let Some(info) = self.layer_residency.get_mut(&layer_id) {
            info.state = new_state;
            info.state_duration = Duration::ZERO;
            self.stats.total_transitions += 1;

            // Enforce state at OS level if paginator is available
            if let (Some(paginator), Some(model_index)) = (&self.paginator, &self.model_index) {
                if let Some(layer_range) = model_index.get_layer_range(layer_id) {
                    self.enforce_state(paginator, layer_range, new_state);
                }
            }
        }
    }

    /// Enforce a residency state at the OS level
    fn enforce_state(
        &self,
        paginator: &OSMemoryPaginator,
        range: &ByteRange,
        state: ResidencyState,
    ) {
        match state {
            ResidencyState::Keep => {
                // Ensure pages are resident and marked as sequential if applicable
                let _ = paginator.prefetch_range(range);
                if self.policy.use_sequential_hints {
                    let _ = paginator.set_access_pattern(
                        range,
                        crate::memory_engine::os_paginator::AccessPattern::Sequential,
                    );
                }
            }
            ResidencyState::Cold => {
                // Mark as free but don't force eviction
                let _ = paginator.mark_as_free(range);
            }
            ResidencyState::Reclaim => {
                // Force eviction
                let _ = paginator.evict_range(range);
            }
            ResidencyState::Prefetch => {
                // Prefetch for future access
                let _ = paginator.prefetch_range(range);
            }
        }
    }

    /// Get layers that should be prefetched
    pub fn get_prefetch_layers(&self) -> Vec<usize> {
        self.layer_residency
            .iter()
            .filter(|(_, info)| info.state == ResidencyState::Prefetch)
            .map(|(&id, _)| id)
            .collect()
    }

    /// Get layers that can be reclaimed
    pub fn get_reclaimable_layers(&self) -> Vec<usize> {
        self.layer_residency
            .iter()
            .filter(|(_, info)| info.state == ResidencyState::Reclaim)
            .map(|(&id, _)| id)
            .collect()
    }

    /// Get layers that should be kept in RAM
    pub fn get_keep_layers(&self) -> Vec<usize> {
        self.layer_residency
            .iter()
            .filter(|(_, info)| info.state == ResidencyState::Keep)
            .map(|(&id, _)| id)
            .collect()
    }

    /// Set global memory pressure (0.0-1.0)
    pub fn set_memory_pressure(&mut self, pressure: f64) {
        self.memory_pressure = pressure.clamp(0.0, 1.0);
    }

    /// Update residency policy
    pub fn set_policy(&mut self, policy: ResidencyPolicy) {
        self.policy = policy;
    }

    /// Get current statistics
    pub fn get_stats(&self) -> &ResidencyStats {
        &self.stats
    }

    /// Update statistics counters
    fn update_stats(&mut self) {
        self.stats.keep_count = 0;
        self.stats.cold_count = 0;
        self.stats.reclaim_count = 0;
        self.stats.prefetch_count = 0;

        for info in self.layer_residency.values() {
            match info.state {
                ResidencyState::Keep => self.stats.keep_count += 1,
                ResidencyState::Cold => self.stats.cold_count += 1,
                ResidencyState::Reclaim => self.stats.reclaim_count += 1,
                ResidencyState::Prefetch => self.stats.prefetch_count += 1,
            }
        }
    }

    /// Get residency info for a specific layer
    pub fn get_layer_info(&self, layer_id: usize) -> Option<&ResidencyInfo> {
        self.layer_residency.get(&layer_id)
    }

    /// Force a layer into a specific state (for manual override)
    pub fn force_state(&mut self, layer_id: usize, state: ResidencyState) {
        self.transition_state(layer_id, state);
        // transition_state no refresca los contadores por capa; recomputar
        // para que get_stats() refleje el estado real tras cada override.
        self.update_stats();
    }

    /// Aplica una ventana residente W: capas [0..window) en Keep, el resto en
    /// Cold. Devuelve el nº de capas. Lo usa el lazo ADAPT para aplicar el W
    /// adaptado en vivo sin recargar el modelo.
    pub fn apply_window(&mut self, window: usize) -> usize {
        let n = self.layer_residency.len();
        let w = window.min(n).max(1);
        let keys: Vec<usize> = self.layer_residency.keys().copied().collect();
        for layer_id in keys {
            let state = if layer_id < w {
                ResidencyState::Keep
            } else {
                ResidencyState::Cold
            };
            self.transition_state(layer_id, state);
        }
        self.update_stats();
        n
    }

    /// Clear all residency information
    pub fn clear(&mut self) {
        self.layer_residency.clear();
        self.stats = ResidencyStats::default();
    }

    /// Libera la residencia de TODAS las capas de golpe (unload del modelo).
    ///
    /// `MADV_DONTNEED` sobre el rango mapeado completo vía el paginator,
    /// luego limpia el registro de capas. El resultado del hint se devuelve
    /// para telemetría — `clear()` corre siempre, pase lo que pase con el
    /// syscall (la liberación es un hint, no una garantía).
    pub fn release_all(&mut self) -> Result<(), std::io::Error> {
        let result = match &self.paginator {
            Some(p) => p.release_all(),
            None => Ok(()),
        };
        self.clear();
        result
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::memory_engine::os_paginator::OSMemoryPaginator;

    #[test]
    fn test_residency_state_properties() {
        assert!(ResidencyState::Keep.should_be_resident());
        assert!(ResidencyState::Cold.should_be_resident());
        assert!(!ResidencyState::Reclaim.should_be_resident());
        assert!(!ResidencyState::Prefetch.should_be_resident());

        assert!(ResidencyState::Prefetch.should_prefetch());
        assert!(!ResidencyState::Keep.should_prefetch());

        assert!(ResidencyState::Reclaim.can_reclaim());
        assert!(!ResidencyState::Keep.can_reclaim());
    }

    #[test]
    fn test_residency_manager_creation() {
        let manager = ResidencyManager::with_defaults();
        assert_eq!(manager.get_stats().keep_count, 0);
        assert_eq!(manager.get_stats().total_transitions, 0);
    }

    #[test]
    fn test_layer_registration() {
        let mut manager = ResidencyManager::with_defaults();
        manager.register_layer(0, 0.5);

        let info = manager.get_layer_info(0);
        assert!(info.is_some());
        assert_eq!(info.unwrap().state, ResidencyState::Prefetch);
    }

    #[test]
    fn test_access_recording() {
        let mut manager = ResidencyManager::with_defaults();
        manager.register_layer(0, 0.5);

        manager.record_access(0, true);

        let info = manager.get_layer_info(0).unwrap();
        assert_eq!(info.access_pattern.access_count, 1);
        assert!(info.access_pattern.is_sequential);
        assert_eq!(info.state, ResidencyState::Keep); // Should transition from Prefetch
    }

    #[test]
    fn test_memory_pressure_effect() {
        let mut manager = ResidencyManager::with_defaults();
        manager.register_layer(0, 0.5);
        manager.record_access(0, true);

        // Set high memory pressure
        manager.set_memory_pressure(0.9);

        // After some time, should transition to Cold then Reclaim
        std::thread::sleep(std::time::Duration::from_millis(100));
        manager.update_states();

        let info = manager.get_layer_info(0).unwrap();
        // With high pressure and time passed, should transition away from Keep
        assert_ne!(info.state, ResidencyState::Keep);
    }

    #[test]
    fn test_state_filtering() {
        let mut manager = ResidencyManager::with_defaults();
        manager.register_layer(0, 0.9);
        manager.register_layer(1, 0.3);
        manager.register_layer(2, 0.1);

        manager.record_access(0, true); // High priority -> Keep
        manager.record_access(1, false); // Medium priority -> Keep initially

        manager.update_states();

        let keep_layers = manager.get_keep_layers();
        assert!(keep_layers.contains(&0));
    }

    #[test]
    fn test_force_state_override() {
        let mut manager = ResidencyManager::with_defaults();
        manager.register_layer(0, 0.5);

        manager.force_state(0, ResidencyState::Reclaim);

        let info = manager.get_layer_info(0).unwrap();
        assert_eq!(info.state, ResidencyState::Reclaim);
    }

    #[test]
    fn test_release_all_clears_layers() {
        // Puntero dummy: el syscall de release es un hint y puede fallar
        // (EFAULT/ERROR_NOT_LOCKED) — lo que se verifica aquí es que el
        // registro de capas queda limpio PASE lo que pase con el hint.
        let paginator = OSMemoryPaginator::new(8192 as *mut std::ffi::c_void, 65536);
        let mut manager = ResidencyManager::with_defaults().with_paginator(paginator);
        manager.register_layer(0, 0.5);
        manager.register_layer(1, 0.8);
        manager.force_state(0, ResidencyState::Keep);

        let _ = manager.release_all();

        assert_eq!(manager.layer_residency.len(), 0);
        assert_eq!(manager.get_stats().keep_count, 0);
        assert_eq!(manager.get_stats().reclaim_count, 0);
        assert_eq!(manager.get_stats().prefetch_count, 0);
    }
}
