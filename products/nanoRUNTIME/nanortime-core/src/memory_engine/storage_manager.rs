//! Storage Manager — gestión de mmap y offload de capas a SSD.
//!
//! Decide cuándo y cómo mover capas del modelo entre RAM y SSD
//! basándose en la velocidad medida del SSD y la presión de memoria.

use std::path::{Path, PathBuf};
use std::time::Duration;

use crate::memory_engine::adaptive_scheduler::MemorySchedule;
use crate::memory_engine::gguf_layout::NanoModelIndex;
use crate::memory_engine::hardware_profiler::HardwareProfile;
use crate::memory_engine::os_paginator::OSMemoryPaginator;

/// Nivel de compresión para layers offloaded a SSD.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OffloadCompression {
    /// Sin compresión — máxima velocidad de carga.
    None,
    /// Compresión ligera LZ4.
    Fast,
    /// Compresión máxima Zstd.
    Best,
}

/// Configuración de acceso a disco para el modelo.
#[derive(Debug, Clone)]
pub struct MmapConfig {
    /// Habilitar memory-mapped I/O.
    pub use_mmap: bool,
    /// Prefetch de capas en SSD rápido.
    pub prefetch: bool,
    /// Tamaño de página en bytes.
    pub page_size: usize,
}

impl Default for MmapConfig {
    fn default() -> Self {
        Self {
            use_mmap: true,
            prefetch: true,
            page_size: 4096,
        }
    }
}

/// Gestor de almacenamiento que configura mmap y decide offload a SSD.
pub struct StorageManager {
    /// Si mmap está habilitado.
    pub mmap_enabled: bool,
    /// Velocidad del SSD en MB/s.
    pub ssd_speed: f64,
    /// Directorio para swap/offload de capas.
    pub swap_path: PathBuf,
    /// Tamaño de página en bytes.
    pub page_size: usize,
    /// Nivel de compresión para layers offloaded.
    pub compression: OffloadCompression,
    /// Layers actualmente offloaded (layer_id → ruta de archivo).
    offloaded: std::collections::HashMap<usize, PathBuf>,
    /// NanoModelIndex para layout del archivo GGUF (para paginación OS).
    pub model_index: Option<NanoModelIndex>,
    /// Paginador a nivel de SO (madvise).
    pub paginator: Option<OSMemoryPaginator>,
}

impl StorageManager {
    /// Crea un nuevo StorageManager basado en el perfil de hardware.
    pub fn new(profile: &HardwareProfile) -> Self {
        // Elegir compresión según velocidad SSD:
        // NVMe rápido (>1000 MB/s) → sin compresión (velocidad prioritaria)
        // SSD estándar → compresión ligera
        // SSD lento → compresión máxima
        let compression = if profile.ssd_speed_mbps > 1000.0 {
            OffloadCompression::None
        } else if profile.ssd_speed_mbps > 300.0 {
            OffloadCompression::Fast
        } else {
            OffloadCompression::Best
        };

        // Usar mmap si el SSD es suficientemente rápido (>100 MB/s)
        let mmap_enabled = profile.ssd_speed_mbps > 100.0;

        let swap_path = std::env::temp_dir().join("nanoai_swap");
        let _ = std::fs::create_dir_all(&swap_path);

        Self {
            mmap_enabled,
            ssd_speed: profile.ssd_speed_mbps,
            swap_path,
            page_size: 4096,
            compression,
            offloaded: std::collections::HashMap::new(),
            model_index: None,
            paginator: None,
        }
    }

    /// Genera configuración mmap óptima para el modelo dado.
    pub fn configure_mmap(&self, model_path: &Path) -> MmapConfig {
        // Prefetch si el SSD es rápido y el modelo existe
        let prefetch = model_path.exists() && self.ssd_speed > 300.0;
        MmapConfig {
            use_mmap: self.mmap_enabled,
            prefetch,
            page_size: self.page_size,
        }
    }

    /// Estima el tiempo de penalización por leer `bytes` desde SSD.
    pub fn estimate_swap_penalty(&self, bytes: u64) -> Duration {
        if self.ssd_speed <= 0.0 {
            return Duration::from_secs(60); // Timeout conservador
        }
        let secs = bytes as f64 / (self.ssd_speed * 1_048_576.0);
        Duration::from_secs_f64(secs.max(0.001))
    }

    /// Decide si una capa debe moverse a SSD basado en presión de RAM.
    ///
    /// `layer_size_mb`: tamaño de la capa en MB
    /// `ram_pressure`: presión de RAM actual (0.0 - 1.0)
    pub fn should_offload(&self, layer_size_mb: u64, ram_pressure: f32) -> bool {
        // Solo offload si el SSD es suficientemente rápido para recuperar la capa
        if self.ssd_speed < 50.0 {
            return false; // SSD demasiado lento — no vale la pena
        }

        // Alta presión de RAM → offload agresivo
        if ram_pressure > 0.90 {
            return true;
        }

        // Presión media + capa grande → offload
        if ram_pressure > 0.75 && layer_size_mb > 100 {
            return true;
        }

        // Presión baja → no offload
        false
    }

    /// Mueve una capa a SSD (escritura serializada).
    pub fn offload_layer(
        &mut self,
        layer_data: &[u8],
        layer_id: usize,
    ) -> crate::error::Result<()> {
        let layer_path = self.swap_path.join(format!("layer_{:04}.bin", layer_id));

        // Compresión simple: en producción usaríamos lz4/zstd
        // Aquí hacemos escritura directa para mantener dependencias mínimas
        let data_to_write = match self.compression {
            OffloadCompression::None => layer_data.to_vec(),
            OffloadCompression::Fast | OffloadCompression::Best => {
                // Compresión trivial: RLE para secuencias de ceros (datos de modelo cuantizados)
                Self::compress_rle(layer_data)
            }
        };

        std::fs::write(&layer_path, &data_to_write).map_err(|e| {
            crate::error::NanoError::Internal {
                message: format!("Failed to offload layer {}: {}", layer_id, e),
            }
        })?;

        tracing::debug!(
            "Offloaded layer {} ({} KB → {} KB) to {:?}",
            layer_id,
            layer_data.len() / 1024,
            data_to_write.len() / 1024,
            layer_path
        );

        self.offloaded.insert(layer_id, layer_path);
        Ok(())
    }

    /// Carga una capa desde SSD de vuelta a RAM.
    pub fn load_layer(&self, layer_id: usize) -> crate::error::Result<Vec<u8>> {
        let layer_path =
            self.offloaded
                .get(&layer_id)
                .ok_or_else(|| crate::error::NanoError::Internal {
                    message: format!("Layer {} is not offloaded", layer_id),
                })?;

        let raw = std::fs::read(layer_path).map_err(|e| crate::error::NanoError::Internal {
            message: format!("Failed to load layer {}: {}", layer_id, e),
        })?;

        // Descomprimir si fue comprimido
        let data = match self.compression {
            OffloadCompression::None => raw,
            OffloadCompression::Fast | OffloadCompression::Best => Self::decompress_rle(&raw)
                .map_err(|e| crate::error::NanoError::Internal {
                    message: format!("Failed to decompress layer {}: {}", layer_id, e),
                })?,
        };

        tracing::debug!(
            "Loaded layer {} ({} KB) from SSD",
            layer_id,
            data.len() / 1024
        );
        Ok(data)
    }

    /// Elimina capas offloaded del disco (limpieza).
    pub fn clear_offloaded(&mut self) {
        for (id, path) in self.offloaded.drain() {
            if let Err(e) = std::fs::remove_file(&path) {
                tracing::warn!(
                    "Failed to remove offloaded layer {} at {:?}: {}",
                    id,
                    path,
                    e
                );
            }
        }
    }

    /// Retorna cuántas capas están actualmente offloaded.
    pub fn offloaded_count(&self) -> usize {
        self.offloaded.len()
    }

    /// RLE muy simple para comprimir datos de modelo (secuencias de bytes repetidos).
    fn compress_rle(data: &[u8]) -> Vec<u8> {
        if data.is_empty() {
            return Vec::new();
        }
        let mut out = Vec::with_capacity(data.len());
        let mut i = 0;
        while i < data.len() {
            let byte = data[i];
            let mut count = 1usize;
            while i + count < data.len() && data[i + count] == byte && count < 255 {
                count += 1;
            }
            out.push(count as u8);
            out.push(byte);
            i += count;
        }
        // Prepend format flag: 0x01=RLE compressed, 0x00=raw
        if out.len() < data.len() {
            let mut compressed = vec![0x01u8];
            compressed.extend_from_slice(&out);
            compressed
        } else {
            let mut raw = vec![0x00u8];
            raw.extend_from_slice(data);
            raw
        }
    }

    /// Descomprime datos RLE.
    /// Format: first byte is 0x01=RLE compressed, 0x00=raw.
    /// RLE payload: pairs of (count: u8, byte: u8), count in 1..=255.
    /// Unknown flags treated as raw for forward compatibility.
    ///
    /// Returns `Err` on unrecoverable corruption (truncated stream, invalid count=0,
    /// output exceeds sanity cap). Returning partial data silently would mask data
    /// integrity violations — model layer storage cannot tolerate silent corruption.
    fn decompress_rle(data: &[u8]) -> Result<Vec<u8>, String> {
        if data.len() < 2 {
            return Ok(data.to_vec()); // Too short to be valid format
        }
        match data[0] {
            0x00 => Ok(data[1..].to_vec()),
            0x01 => {
                let payload = &data[1..];
                if payload.is_empty() {
                    return Ok(Vec::new());
                }
                if !payload.len().is_multiple_of(2) {
                    return Err(format!(
                        "RLE stream truncated: {} payload bytes (must be even for (count,byte) pairs)",
                        payload.len()
                    ));
                }
                // Pre-allocate: estimate worst case size from the pairs.
                let max_output: usize = payload.chunks(2).map(|chunk| chunk[0] as usize).sum();
                if max_output > 512 * 1024 * 1024 {
                    return Err(format!(
                        "RLE decompress: output would exceed 512 MB cap (claimed {}). Corrupted data?",
                        max_output
                    ));
                }
                let mut out = Vec::with_capacity(max_output);
                for chunk in payload.chunks(2) {
                    let count = chunk[0] as usize;
                    let byte = chunk[1];
                    if count == 0 {
                        return Err(format!(
                            "RLE stream corrupted: count=0 byte=0x{byte:02x} — zero-length runs are invalid"
                        ));
                    }
                    for _ in 0..count {
                        out.push(byte);
                    }
                }
                Ok(out)
            }
            other => {
                // Unknown format flag — strip flag byte, return payload as raw
                // for forward compatibility.
                tracing::warn!("Unknown RLE format flag 0x{:02x} — returning payload as raw data (flag stripped)", other);
                Ok(data[1..].to_vec())
            }
        }
    }

    /// Initializes the model index from a GGUF model file.
    /// Must be called after a model is loaded so that `apply_schedule`
    /// can compute contiguous layer ranges for eviction/prefetch.
    pub fn init_layout(&mut self, gguf_path: &Path, expected_layers: usize) {
        match NanoModelIndex::analyze(gguf_path, expected_layers) {
            Ok(index) => {
                tracing::info!(
                    "StorageManager: model index initialized from {} ({} layers, data_offset={}, page_size={})",
                    gguf_path.display(),
                    index.layers.len(),
                    index.data_offset,
                    index.page_size(),
                );
                self.model_index = Some(index);
            }
            Err(e) => {
                tracing::warn!(
                    "StorageManager: failed to parse GGUF layout from {}: {:?} — OS-level pagination disabled",
                    gguf_path.display(),
                    e,
                );
            }
        }
    }

    /// Initializes the OS memory paginator with a pointer to mapped model data.
    /// Requires the raw memory address and length of the model's mmap region.
    /// On Android/Linux this enables MADV_FREE and prefetch; on other platforms
    /// it falls back to evict_range (MADV_DONTNEED).
    pub fn init_paginator(&mut self, memory_ptr: *mut std::ffi::c_void, len: usize) {
        if memory_ptr.is_null() || len == 0 {
            tracing::warn!(
                "StorageManager: null/empty ptr passed to init_paginator — OS enforcement disabled"
            );
            return;
        }
        let paginator = OSMemoryPaginator::new(memory_ptr, len);
        tracing::info!(
            "StorageManager: paginator initialized ({} bytes at {:?})",
            len,
            memory_ptr,
        );
        self.paginator = Some(paginator);
    }

    /// Applies a memory schedule using OS-level pagination (madvise, eviction, prefetch).
    ///
    /// Gracefully degrades when components are not yet initialized:
    /// - Layout grouping always runs if `model_index` is set.
    /// - Eviction/prefetch runs only if `paginator` is also set.
    /// - Logs diagnostic info when either component is missing.
    pub fn apply_schedule(&self, schedule: &MemorySchedule) -> crate::error::Result<()> {
        // ── Layout-based contiguous grouping ──────────────────────
        // Works independently of the paginator — groups layers into
        // contiguous byte ranges for efficient OS operations.
        let (evict_ranges, prefetch_ranges) = if let Some(index) = &self.model_index {
            (
                index.group_contiguous_layers(&schedule.layers_to_offload),
                index.group_contiguous_layers(&schedule.layers_to_prefetch),
            )
        } else {
            tracing::debug!(
                "Schedule not applied: model_index not initialized. \
                 strategy={:?} offload={} prefetch={} layers_in_ram={}",
                schedule.strategy,
                schedule.layers_to_offload.len(),
                schedule.layers_to_prefetch.len(),
                schedule.layers_in_ram.len(),
            );
            return Ok(());
        };

        // ── OS-level enforcement (requires paginator) ─────────────
        if let Some(paginator) = &self.paginator {
            for range in evict_ranges {
                if let Err(e) = paginator.evict_range(&range) {
                    tracing::warn!("Failed to evict range {:?}: {}", range, e);
                }
            }
            for range in prefetch_ranges {
                if let Err(e) = paginator.prefetch_range(&range) {
                    tracing::warn!("Failed to prefetch range {:?}: {}", range, e);
                }
            }
        } else {
            tracing::debug!(
                "Schedule layout computed but paginator not initialized. \
                 evict_ranges={} prefetch_ranges={} — OS enforcement skipped",
                evict_ranges.len(),
                prefetch_ranges.len(),
            );
        }

        Ok(())
    }

    /// Evict inmediato de múltiples capas (útil para Early Exiting)
    pub fn evict_layers_batch(&self, layer_indices: &[usize]) -> crate::error::Result<()> {
        if let (Some(index), Some(paginator)) = (&self.model_index, &self.paginator) {
            let evict_ranges = index.group_contiguous_layers(layer_indices);
            for range in evict_ranges {
                if let Err(e) = paginator.evict_range(&range) {
                    tracing::warn!("Failed to evict range {:?}: {}", range, e);
                }
            }
        }
        Ok(())
    }
}

impl Drop for StorageManager {
    fn drop(&mut self) {
        self.clear_offloaded();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::memory_engine::hardware_profiler::{DeviceClass, HardwareProfile, ThermalState};
    use std::time::Instant;

    fn test_profile(ssd_speed: f64) -> HardwareProfile {
        HardwareProfile {
            ram_total_mb: 16384,
            ram_available_mb: 8192,
            ssd_speed_mbps: ssd_speed,
            cpu_cores: 8,
            device_class: DeviceClass::MidEnd,
            thermal: ThermalState::default(),
            last_updated: Instant::now(),
        }
    }

    #[test]
    fn test_new_fast_ssd() {
        let profile = test_profile(1500.0);
        let sm = StorageManager::new(&profile);
        assert!(sm.mmap_enabled);
        assert_eq!(sm.compression, OffloadCompression::None);
    }

    #[test]
    fn test_new_slow_ssd() {
        // 80 MB/s is below the 100 MB/s mmap threshold → mmap disabled
        let profile = test_profile(80.0);
        let sm = StorageManager::new(&profile);
        assert!(
            !sm.mmap_enabled,
            "SSD at 80 MB/s should disable mmap (threshold is >100 MB/s)"
        );
        assert_eq!(sm.compression, OffloadCompression::Best);
    }

    #[test]
    fn test_should_offload_high_pressure() {
        let profile = test_profile(500.0);
        let sm = StorageManager::new(&profile);
        assert!(sm.should_offload(50, 0.95));
    }

    #[test]
    fn test_should_not_offload_low_pressure() {
        let profile = test_profile(500.0);
        let sm = StorageManager::new(&profile);
        assert!(!sm.should_offload(50, 0.30));
    }

    #[test]
    fn test_should_not_offload_slow_ssd() {
        let profile = test_profile(30.0);
        let sm = StorageManager::new(&profile);
        assert!(!sm.should_offload(50, 0.95));
    }

    #[test]
    fn test_estimate_swap_penalty() {
        let profile = test_profile(1000.0);
        let sm = StorageManager::new(&profile);
        let penalty = sm.estimate_swap_penalty(1024 * 1024 * 100); // 100MB
                                                                   // 100MB / 1000 MB/s = 0.1s
        assert!(penalty.as_millis() > 50 && penalty.as_millis() < 200);
    }

    #[test]
    fn test_rle_roundtrip() {
        let data = vec![0u8; 1000]; // 1000 zeros
        let compressed = StorageManager::compress_rle(&data);
        let decompressed =
            StorageManager::decompress_rle(&compressed).expect("RLE roundtrip should succeed");
        assert_eq!(decompressed, data);
        assert!(
            compressed.len() < data.len(),
            "RLE should compress repetitive data"
        );

        // Non-repetitive data: should fall back to raw (0x00 prefix)
        let unique: Vec<u8> = (0..=255).collect();
        let comp_unique = StorageManager::compress_rle(&unique);
        let decomp_unique = StorageManager::decompress_rle(&comp_unique)
            .expect("Raw fallback decompress should succeed");
        assert_eq!(decomp_unique, unique);
        assert_eq!(
            comp_unique[0], 0x00,
            "Non-repetitive data uses raw format flag"
        );
    }

    #[test]
    fn test_rle_detects_corruption_count_zero() {
        // Manually craft corrupted RLE: (count=0, byte=0x42)
        let corrupted = vec![0x01, 0x00, 0x42];
        let result = StorageManager::decompress_rle(&corrupted);
        assert!(result.is_err(), "count=0 should be rejected as corruption");
    }

    #[test]
    fn test_rle_detects_corruption_truncated() {
        // Odd payload length after flag
        let truncated = vec![0x01, 0x05];
        let result = StorageManager::decompress_rle(&truncated);
        assert!(result.is_err(), "Truncated RLE should be rejected");
    }

    #[test]
    fn test_offload_and_load() {
        let profile = test_profile(500.0);
        let mut sm = StorageManager::new(&profile);
        let data = vec![0xFFu8; 1024]; // 1KB of data

        sm.offload_layer(&data, 0).unwrap();
        assert_eq!(sm.offloaded_count(), 1);

        let loaded = sm.load_layer(0).unwrap();
        assert_eq!(loaded, data);
    }

    #[test]
    fn test_configure_mmap() {
        let profile = test_profile(500.0);
        let sm = StorageManager::new(&profile);
        let cfg = sm.configure_mmap(Path::new("/nonexistent"));
        assert!(cfg.use_mmap);
        assert!(!cfg.prefetch); // nonexistent path → no prefetch
    }
}
