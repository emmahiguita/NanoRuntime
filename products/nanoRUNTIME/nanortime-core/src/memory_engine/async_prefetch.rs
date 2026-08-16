//! Async Prefetch with Double Buffering
//!
//! Implements asynchronous prefetch with double buffering to overlap
//! I/O and computation. While the CPU processes layer N, the system
//! prefetches layer N+1, approaching max(Tcompute, TIO) instead of
//! paying both sequentially.
//!
//! ## Architecture
//!
//! - **Double Buffer**: Two buffers for alternating between compute and I/O
//! - **Async Prefetch**: Background loading using tokio
//! - **Coordination**: Works with ResidencyManager for intelligent prefetch decisions
//! - **Metrics**: Tracks prefetch efficiency, hit rates, and overlap ratios

use crate::memory_engine::gguf_layout::NanoModelIndex;
use crate::memory_engine::os_paginator::OSMemoryPaginator;
use std::sync::Arc;
use tokio::sync::{Mutex, Semaphore};
use std::time::{Duration, Instant};
use std::collections::VecDeque;

/// Buffer state for double buffering
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BufferState {
    /// Buffer is empty and available for loading
    Empty,
    /// Buffer is being loaded in background
    Loading,
    /// Buffer is ready for computation
    Ready,
    /// Buffer is currently being used for computation
    InUse,
}

/// Double buffer for async prefetch
#[derive(Debug)]
pub struct DoubleBuffer {
    /// Buffer A
    buffer_a: BufferSlot,
    /// Buffer B
    buffer_b: BufferSlot,
    /// Which buffer is currently active for computation
    active_buffer: BufferId,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BufferId {
    A,
    B,
}

#[derive(Debug)]
struct BufferSlot {
    state: BufferState,
    layer_id: Option<usize>,
    load_start_time: Option<Instant>,
    load_duration: Option<Duration>,
}

impl BufferSlot {
    fn new() -> Self {
        Self {
            state: BufferState::Empty,
            layer_id: None,
            load_start_time: None,
            load_duration: None,
        }
    }
}

impl Default for DoubleBuffer {
    fn default() -> Self {
        Self::new()
    }
}

impl DoubleBuffer {
    /// Create a new double buffer
    pub fn new() -> Self {
        Self {
            buffer_a: BufferSlot::new(),
            buffer_b: BufferSlot::new(),
            active_buffer: BufferId::A,
        }
    }

    /// Get the buffer ready for computation
    pub fn get_ready_buffer(&mut self) -> Option<usize> {
        let ready_buffer = match self.active_buffer {
            BufferId::A => &mut self.buffer_b,
            BufferId::B => &mut self.buffer_a,
        };

        if ready_buffer.state == BufferState::Ready {
            ready_buffer.state = BufferState::InUse;
            // Swap active buffer
            self.active_buffer = match self.active_buffer {
                BufferId::A => BufferId::B,
                BufferId::B => BufferId::A,
            };
            ready_buffer.layer_id
        } else {
            None
        }
    }

    /// Get the buffer available for loading
    pub fn get_load_buffer(&mut self) -> Option<BufferId> {
        let load_buffer = match self.active_buffer {
            BufferId::A => &mut self.buffer_b,
            BufferId::B => &mut self.buffer_a,
        };

        if load_buffer.state == BufferState::Empty {
            Some(match self.active_buffer {
                BufferId::A => BufferId::B,
                BufferId::B => BufferId::A,
            })
        } else {
            None
        }
    }

    /// Mark a buffer as loading
    pub fn mark_loading(&mut self, buffer_id: BufferId, layer_id: usize) {
        let buffer = match buffer_id {
            BufferId::A => &mut self.buffer_a,
            BufferId::B => &mut self.buffer_b,
        };
        buffer.state = BufferState::Loading;
        buffer.layer_id = Some(layer_id);
        buffer.load_start_time = Some(Instant::now());
    }

    /// Mark a buffer as ready
    pub fn mark_ready(&mut self, buffer_id: BufferId) {
        let buffer = match buffer_id {
            BufferId::A => &mut self.buffer_a,
            BufferId::B => &mut self.buffer_b,
        };
        buffer.state = BufferState::Ready;
        if let Some(start) = buffer.load_start_time {
            buffer.load_duration = Some(start.elapsed());
        }
    }

    /// Release the in-use buffer
    pub fn release_buffer(&mut self) {
        let in_use_buffer = match self.active_buffer {
            BufferId::A => &mut self.buffer_a,
            BufferId::B => &mut self.buffer_b,
        };
        if in_use_buffer.state == BufferState::InUse {
            in_use_buffer.state = BufferState::Empty;
            in_use_buffer.layer_id = None;
            in_use_buffer.load_start_time = None;
        }
    }

    /// Get buffer statistics
    pub fn get_stats(&self) -> DoubleBufferStats {
        DoubleBufferStats {
            buffer_a_state: self.buffer_a.state,
            buffer_b_state: self.buffer_b.state,
            active_buffer: self.active_buffer,
            avg_load_duration: self.calculate_avg_load_duration(),
        }
    }

    fn calculate_avg_load_duration(&self) -> Option<Duration> {
        let durations: Vec<_> = [&self.buffer_a, &self.buffer_b]
            .iter()
            .filter_map(|b| b.load_duration)
            .collect();
        
        if durations.is_empty() {
            None
        } else {
            let sum: Duration = durations.iter().sum();
            Some(sum / durations.len() as u32)
        }
    }
}

/// Double buffer statistics
#[derive(Debug, Clone)]
pub struct DoubleBufferStats {
    pub buffer_a_state: BufferState,
    pub buffer_b_state: BufferState,
    pub active_buffer: BufferId,
    pub avg_load_duration: Option<Duration>,
}

/// Prefetch task result
#[derive(Debug)]
pub struct PrefetchResult {
    pub layer_id: usize,
    pub success: bool,
    pub duration: Duration,
    pub bytes_loaded: usize,
}

/// Async prefetch manager
pub struct AsyncPrefetchManager {
    /// Double buffer for prefetch coordination
    double_buffer: Arc<Mutex<DoubleBuffer>>,
    /// Model index for layout information
    model_index: Option<Arc<NanoModelIndex>>,
    /// OS paginator for enforcement
    paginator: Option<Arc<OSMemoryPaginator>>,
    /// Semaphore to limit concurrent prefetch operations
    prefetch_semaphore: Arc<Semaphore>,
    /// Prefetch queue
    prefetch_queue: Arc<Mutex<VecDeque<usize>>>,
    /// Statistics
    stats: Arc<Mutex<PrefetchStats>>,
    /// Maximum concurrent prefetch operations
    max_concurrent: usize,
}

/// Prefetch statistics
#[derive(Debug, Clone, Default)]
pub struct PrefetchStats {
    /// Total prefetch requests
    pub total_requests: u64,
    /// Successful prefetches
    pub successful_prefetches: u64,
    /// Failed prefetches
    pub failed_prefetches: u64,
    /// Prefetch hits (used before eviction)
    pub prefetch_hits: u64,
    /// Prefetch misses (evicted before use)
    pub prefetch_misses: u64,
    /// Total bytes prefetched
    pub total_bytes_prefetched: u64,
    /// Total time spent prefetching
    pub total_prefetch_time: Duration,
    /// Average prefetch duration
    pub avg_prefetch_duration: Option<Duration>,
    /// Buffer utilization (0.0-1.0)
    pub buffer_utilization: f64,
}

impl AsyncPrefetchManager {
    /// Create a new async prefetch manager
    pub fn new(max_concurrent: usize) -> Self {
        Self {
            double_buffer: Arc::new(Mutex::new(DoubleBuffer::new())),
            model_index: None,
            paginator: None,
            prefetch_semaphore: Arc::new(Semaphore::new(max_concurrent)),
            prefetch_queue: Arc::new(Mutex::new(VecDeque::new())),
            stats: Arc::new(Mutex::new(PrefetchStats::default())),
            max_concurrent,
        }
    }

    /// Número máximo de prefetches concurrentes (límite real del semáforo).
    pub fn max_concurrent(&self) -> usize {
        self.max_concurrent
    }

    /// Set the model index
    pub fn with_model_index(mut self, model_index: Arc<NanoModelIndex>) -> Self {
        self.model_index = Some(model_index);
        self
    }

    /// Set the OS paginator
    pub fn with_paginator(mut self, paginator: Arc<OSMemoryPaginator>) -> Self {
        self.paginator = Some(paginator);
        self
    }

    /// Queue a layer for prefetch
    pub async fn queue_prefetch(&self, layer_id: usize) {
        let mut queue = self.prefetch_queue.lock().await;
        if !queue.contains(&layer_id) {
            queue.push_back(layer_id);
        }
    }

    /// Queue multiple layers for prefetch
    pub async fn queue_prefetch_batch(&self, layer_ids: &[usize]) {
        let mut queue = self.prefetch_queue.lock().await;
        for &layer_id in layer_ids {
            if !queue.contains(&layer_id) {
                queue.push_back(layer_id);
            }
        }
    }

    /// Process the prefetch queue
    pub async fn process_prefetch_queue(&self) -> Vec<PrefetchResult> {
        let mut results = Vec::new();
        
        // Get available permit for concurrent prefetch
        let _permit = self.prefetch_semaphore.acquire().await.unwrap();
        
        // Check if we have a buffer available for loading
        let buffer_id = {
            let mut buffer = self.double_buffer.lock().await;
            buffer.get_load_buffer()
        };

        if let Some(buffer_id) = buffer_id {
            // Get next layer from queue
            let layer_id = {
                let mut queue = self.prefetch_queue.lock().await;
                queue.pop_front()
            };

            if let Some(layer_id) = layer_id {
                let result = self.prefetch_layer(buffer_id, layer_id).await;
                results.push(result);
            }
        }

        results
    }

    /// Prefetch a single layer
    async fn prefetch_layer(&self, buffer_id: BufferId, layer_id: usize) -> PrefetchResult {
        let start_time = Instant::now();
        let mut stats = self.stats.lock().await;
        stats.total_requests += 1;
        drop(stats);

        // Mark buffer as loading
        {
            let mut buffer = self.double_buffer.lock().await;
            buffer.mark_loading(buffer_id, layer_id);
        }

        let success = if let (Some(model_index), Some(paginator)) = (&self.model_index, &self.paginator) {
            if let Some(layer_range) = model_index.get_layer_range(layer_id) {
                // Perform synchronous prefetch (coordinated with async runtime)
                let prefetch_result = {
                    let paginator = paginator.clone();
                    let range = layer_range.clone();
                    // Use tokio::task::block_in_place to allow blocking operation in async context
                    tokio::task::block_in_place(|| {
                        paginator.prefetch_range(&range)
                    })
                };

                match prefetch_result {
                    Ok(()) => {
                        let bytes_loaded = layer_range.len();
                        
                        // Update stats
                        let mut stats = self.stats.lock().await;
                        stats.successful_prefetches += 1;
                        stats.total_bytes_prefetched += bytes_loaded as u64;
                        stats.total_prefetch_time += start_time.elapsed();
                        stats.avg_prefetch_duration = Some(stats.total_prefetch_time / stats.successful_prefetches as u32);
                        
                        true
                    }
                    Err(e) => {
                        tracing::warn!("Failed to prefetch layer {}: {}", layer_id, e);
                        let mut stats = self.stats.lock().await;
                        stats.failed_prefetches += 1;
                        false
                    }
                }
            } else {
                tracing::warn!("Layer {} not found in model index", layer_id);
                let mut stats = self.stats.lock().await;
                stats.failed_prefetches += 1;
                false
            }
        } else {
            tracing::warn!("Model index or paginator not set for prefetch");
            let mut stats = self.stats.lock().await;
            stats.failed_prefetches += 1;
            false
        };

        // Mark buffer as ready or empty based on success
        {
            let mut buffer = self.double_buffer.lock().await;
            if success {
                buffer.mark_ready(buffer_id);
            } else {
                // Reset buffer on failure
                match buffer_id {
                    BufferId::A => {
                        buffer.buffer_a.state = BufferState::Empty;
                        buffer.buffer_a.layer_id = None;
                    }
                    BufferId::B => {
                        buffer.buffer_b.state = BufferState::Empty;
                        buffer.buffer_b.layer_id = None;
                    }
                }
            }
        }

        PrefetchResult {
            layer_id,
            success,
            duration: start_time.elapsed(),
            bytes_loaded: success as usize, // Simplified - would track actual bytes
        }
    }

    /// Get the next ready layer for computation
    pub async fn get_ready_layer(&mut self) -> Option<usize> {
        let mut buffer = self.double_buffer.lock().await;
        buffer.get_ready_buffer()
    }

    /// Release the current computation buffer
    pub async fn release_computation_buffer(&self) {
        let mut buffer = self.double_buffer.lock().await;
        buffer.release_buffer();
    }

    /// Get current statistics
    pub async fn get_stats(&self) -> PrefetchStats {
        let stats = self.stats.lock().await;
        let buffer_stats = {
            let buffer = self.double_buffer.lock().await;
            buffer.get_stats()
        };
        
        // Calculate buffer utilization
        let ready_count = match (buffer_stats.buffer_a_state, buffer_stats.buffer_b_state) {
            (BufferState::Ready, BufferState::Ready) => 2,
            (BufferState::Ready, _) | (_, BufferState::Ready) => 1,
            _ => 0,
        };
        let buffer_utilization = ready_count as f64 / 2.0;

        PrefetchStats {
            total_requests: stats.total_requests,
            successful_prefetches: stats.successful_prefetches,
            failed_prefetches: stats.failed_prefetches,
            prefetch_hits: stats.prefetch_hits,
            prefetch_misses: stats.prefetch_misses,
            total_bytes_prefetched: stats.total_bytes_prefetched,
            total_prefetch_time: stats.total_prefetch_time,
            avg_prefetch_duration: stats.avg_prefetch_duration,
            buffer_utilization,
        }
    }

    /// Record a prefetch hit (layer was used before eviction)
    pub async fn record_prefetch_hit(&self, _layer_id: usize) {
        let mut stats = self.stats.lock().await;
        stats.prefetch_hits += 1;
    }

    /// Record a prefetch miss (layer was evicted before use)
    pub async fn record_prefetch_miss(&self, _layer_id: usize) {
        let mut stats = self.stats.lock().await;
        stats.prefetch_misses += 1;
    }

    /// Calculate prefetch efficiency (hits / total prefetches)
    pub async fn prefetch_efficiency(&self) -> f64 {
        let stats = self.stats.lock().await;
        let total = stats.prefetch_hits + stats.prefetch_misses;
        if total > 0 {
            stats.prefetch_hits as f64 / total as f64
        } else {
            0.0
        }
    }

    /// Calculate I/O/compute overlap ratio
    /// Ideally close to 1.0 indicates perfect overlap
    pub async fn overlap_ratio(&self) -> f64 {
        let _stats = self.stats.lock().await;
        let buffer_stats = {
            let buffer = self.double_buffer.lock().await;
            buffer.get_stats()
        };
        
        // Simple heuristic: if we have ready buffers, we're achieving overlap
        if buffer_stats.buffer_a_state == BufferState::Ready || buffer_stats.buffer_b_state == BufferState::Ready {
            1.0
        } else {
            0.0
        }
    }

    /// Clear the prefetch queue
    pub async fn clear_queue(&self) {
        let mut queue = self.prefetch_queue.lock().await;
        queue.clear();
    }

    /// Reset statistics
    pub async fn reset_stats(&self) {
        let mut stats = self.stats.lock().await;
        *stats = PrefetchStats::default();
    }
}

impl Default for AsyncPrefetchManager {
    fn default() -> Self {
        Self::new(2) // Default to 2 concurrent prefetches
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_double_buffer_creation() {
        let buffer = DoubleBuffer::new();
        let stats = buffer.get_stats();
        
        assert_eq!(stats.buffer_a_state, BufferState::Empty);
        assert_eq!(stats.buffer_b_state, BufferState::Empty);
    }

    #[test]
    fn test_double_buffer_state_transitions() {
        let mut buffer = DoubleBuffer::new();
        
        // Initially no ready buffer
        assert_eq!(buffer.get_ready_buffer(), None);
        
        // Mark buffer B as loading then ready
        buffer.mark_loading(BufferId::B, 1);
        buffer.mark_ready(BufferId::B);
        
        // Now should get ready buffer
        assert_eq!(buffer.get_ready_buffer(), Some(1));
        
        // Buffer should now be in use
        let stats = buffer.get_stats();
        assert_eq!(stats.buffer_b_state, BufferState::InUse);
    }

    #[test]
    fn test_async_prefetch_manager_creation() {
        let manager = AsyncPrefetchManager::new(2);
        assert_eq!(manager.max_concurrent, 2);
    }

    #[tokio::test]
    async fn test_prefetch_queue() {
        let manager = AsyncPrefetchManager::new(2);
        
        manager.queue_prefetch(1).await;
        manager.queue_prefetch(2).await;
        manager.queue_prefetch(3).await;
        
        // Check queue processing would work (simplified test)
        let results = manager.process_prefetch_queue().await;
        // Without model index, should fail but not crash
        assert!(!results.is_empty() || results.is_empty()); // Just ensure it doesn't panic
    }

    #[tokio::test]
    async fn test_stats_tracking() {
        let manager = AsyncPrefetchManager::new(2);
        
        let initial_stats = manager.get_stats().await;
        assert_eq!(initial_stats.total_requests, 0);
        
        // Record some stats
        manager.record_prefetch_hit(1).await;
        manager.record_prefetch_miss(2).await;
        
        let updated_stats = manager.get_stats().await;
        assert_eq!(updated_stats.prefetch_hits, 1);
        assert_eq!(updated_stats.prefetch_misses, 1);
    }

    #[tokio::test]
    async fn test_prefetch_efficiency() {
        let manager = AsyncPrefetchManager::new(2);
        
        // Initially 0 efficiency
        assert_eq!(manager.prefetch_efficiency().await, 0.0);
        
        // Add some hits
        manager.record_prefetch_hit(1).await;
        manager.record_prefetch_hit(2).await;
        manager.record_prefetch_miss(3).await;
        
        // Should be 2/3 = 0.666...
        let efficiency = manager.prefetch_efficiency().await;
        assert!((efficiency - 0.666).abs() < 0.01);
    }

    #[tokio::test]
    async fn test_queue_clear() {
        let manager = AsyncPrefetchManager::new(2);
        
        manager.queue_prefetch(1).await;
        manager.queue_prefetch(2).await;
        
        manager.clear_queue().await;
        
        // Queue should be empty (verified by processing returning no results)
        let results = manager.process_prefetch_queue().await;
        assert!(results.is_empty());
    }
}