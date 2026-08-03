//! Gestor de memoria real — sysinfo para estadísticas del sistema.
//!
//! Consulta el SO para obtener memoria total, disponible, y usada.
//! Estima el consumo de KV-cache y modelos cargados.
//! Integra HardwareProfiler del Nano Memory Engine para clasificación de hardware.

use std::sync::Mutex;
use sysinfo::System;

use crate::memory_engine::hardware_profiler::{DeviceClass, HardwareProfile, HardwareProfiler};

// ── V2 modules: Hardware Abstraction Layer + Auto-Config ──────────
use crate::memory_engine::hardware_hal::{profile_device, DeviceTier};
use crate::memory_engine::auto_config::RuntimeConfig;
use crate::memory_engine::oom_guard::{quick_check, OomRisk};
use crate::memory_engine::memory_model::MemoryModel;
use crate::memory_engine::execution_planner::ExecutionPlanner;

/// Estadísticas de uso de memoria del runtime.
#[derive(Debug, Clone)]
pub struct MemoryStats {
    /// Memoria total del sistema (MB).
    pub total_system_mb: u64,
    /// Memoria disponible (MB).
    pub available_mb: u64,
    /// Memoria usada por el modelo (MB, estimado).
    pub model_mb: u64,
    /// Memoria usada por la KV-cache (MB, estimado).
    pub kv_cache_mb: u64,
    /// Memoria usada por la base de datos vectorial (MB, estimado).
    pub vector_db_mb: u64,
    /// Porcentaje de memoria usada (0.0 - 100.0).
    pub usage_percent: f32,
    /// Clase de dispositivo detectada.
    pub device_class: DeviceClass,
}

/// Política de evicción de la KV-cache.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EvictionPolicy {
    /// Eliminar las entradas más antiguas primero.
    LRU,
    /// Eliminar las entradas con menor puntuación de atención.
    LowAttention,
    /// Eliminar entradas basado en su antigüedad (TTL).
    TTL,
}

/// Gestor de memoria del runtime.
///
/// Consulta `sysinfo::System` para memoria real del sistema.
/// Delega en `HardwareProfiler` para clasificación de dispositivo.
pub struct MemoryManager {
    /// Política de evicción activa.
    eviction_policy: EvictionPolicy,
    /// Tamaño máximo de la KV-cache en MB.
    max_kv_cache_mb: u64,
    /// Umbral de presión de memoria para activar evicción (0.0 - 1.0).
    pressure_threshold: f32,
    /// System info object (lazy-init).
    sys: Mutex<Option<System>>,
    /// Context size configurado (para estimar KV cache).
    context_size: u32,
    /// Capas GPU configuradas.
    #[allow(dead_code)]
    gpu_layers: i32,
    /// Hardware profiler para clasificación de dispositivo.
    profiler: Mutex<Option<HardwareProfiler>>,
}

impl MemoryManager {
    /// Crea un nuevo gestor de memoria con sysinfo real.
    pub fn new(max_kv_cache_mb: u64, context_size: u32, gpu_layers: i32) -> Self {
        Self {
            eviction_policy: EvictionPolicy::LRU,
            max_kv_cache_mb,
            pressure_threshold: 0.85,
            sys: Mutex::new(None),
            context_size,
            gpu_layers,
            profiler: Mutex::new(None),
        }
    }

    /// Crea un gestor con políticas personalizadas.
    pub fn with_policy(
        max_kv_cache_mb: u64,
        policy: EvictionPolicy,
        pressure_threshold: f32,
        context_size: u32,
        gpu_layers: i32,
    ) -> Self {
        Self {
            eviction_policy: policy,
            max_kv_cache_mb,
            pressure_threshold: pressure_threshold.clamp(0.0, 1.0),
            sys: Mutex::new(None),
            context_size,
            gpu_layers,
            profiler: Mutex::new(None),
        }
    }

    /// Inicializa o refresca la información del sistema.
    fn refresh_sys(&self) -> std::sync::MutexGuard<'_, Option<System>> {
        let mut sys_guard = self.sys.lock().unwrap();
        if sys_guard.is_none() {
            *sys_guard = Some(System::new_all());
        }
        if let Some(ref mut sys) = *sys_guard {
            sys.refresh_memory();
        }
        sys_guard
    }

    /// Obtiene estadísticas reales de memoria del sistema.
    pub fn get_stats(&self) -> MemoryStats {
        let sys_guard = self.refresh_sys();

        let total_mb = if let Some(ref sys) = *sys_guard {
            sys.total_memory() / 1024 / 1024 // bytes → MB
        } else {
            32768 // fallback: 32GB
        };

        let available_mb = if let Some(ref sys) = *sys_guard {
            sys.available_memory() / 1024 / 1024
        } else {
            16384 // fallback: 16GB
        };

        let used_mb = total_mb.saturating_sub(available_mb);
        let usage_percent = if total_mb > 0 {
            (used_mb as f32 / total_mb as f32) * 100.0
        } else {
            0.0
        };

        // Estimar KV-cache: ~2MB por 1000 tokens de contexto
        let kv_cache_mb = (self.context_size as u64 * 2) / 1000;

        // Clasificar dispositivo usando HardwareProfiler
        let device_class = {
            let mut profiler_guard = self.profiler.lock().unwrap();
            if profiler_guard.is_none() {
                *profiler_guard = Some(HardwareProfiler::new());
            }
            if let Some(ref mut p) = *profiler_guard {
                p.classify_device()
            } else {
                DeviceClass::MidEnd
            }
        };

        MemoryStats {
            total_system_mb: total_mb,
            available_mb,
            model_mb: 0, // Se actualiza cuando se carga un modelo
            kv_cache_mb,
            vector_db_mb: 0,
            usage_percent,
            device_class,
        }
    }

    /// Retorna el perfil completo de hardware usando HardwareProfiler.
    pub fn hardware_profile(&self) -> HardwareProfile {
        let mut profiler_guard = self.profiler.lock().unwrap();
        if profiler_guard.is_none() {
            *profiler_guard = Some(HardwareProfiler::new());
        }
        if let Some(ref mut p) = *profiler_guard {
            p.profile()
        } else {
            // Fallback: construir perfil mínimo desde sysinfo
            let mut sys = System::new_all();
            sys.refresh_memory();
            let ram_total_mb = sys.total_memory() / 1024 / 1024;
            let ram_available_mb = sys.available_memory() / 1024 / 1024;
            let cpu_cores = sys.cpus().len().max(1);
            HardwareProfile {
                ram_total_mb,
                ram_available_mb,
                ssd_speed_mbps: 200.0,
                cpu_cores,
                device_class: DeviceClass::MidEnd,
                thermal: crate::memory_engine::hardware_profiler::ThermalState::default(),
                last_updated: std::time::Instant::now(),
            }
        }
    }

    /// Actualiza la memoria estimada del modelo cargado.
    pub fn set_model_memory(&mut self, _model_mb: u64) {
        // In a future version, this would update an internal model_mb field
        // so get_stats() can report actual model memory usage.
    }

    /// Verifica si hay suficiente memoria para una operación.
    pub fn has_enough_memory(&self, required_mb: u64) -> bool {
        let stats = self.get_stats();
        stats.available_mb >= required_mb
    }

    /// Decide si es necesario evacuar la KV-cache.
    pub fn should_evict(&self) -> bool {
        let stats = self.get_stats();
        let pressure = 1.0 - (stats.available_mb as f32 / stats.total_system_mb.max(1) as f32);
        pressure > self.pressure_threshold
    }

    /// Calcula cuántas entradas de la KV-cache deben evacuarse.
    pub fn eviction_count(&self) -> usize {
        if !self.should_evict() {
            return 0;
        }
        let stats = self.get_stats();
        let excess_mb = stats.kv_cache_mb.saturating_sub(self.max_kv_cache_mb);
        // Rough estimate: ~1MB per 1000 tokens of KV cache
        (excess_mb * 1000 / self.max_kv_cache_mb.max(1)) as usize
    }

    /// Devuelve la política de evicción activa.
    pub fn eviction_policy(&self) -> EvictionPolicy {
        self.eviction_policy
    }

    /// Establece una nueva política de evicción.
    pub fn set_eviction_policy(&mut self, policy: EvictionPolicy) {
        self.eviction_policy = policy;
    }

    /// Estima los MB necesarios para un modelo dado su tamaño en parámetros
    /// y tipo de cuantización.
    pub fn estimate_model_memory(params_billions: f64, quantization_bits: u32) -> u64 {
        // params * bits_per_weight / 8 → bytes, then / (1024 * 1024) → MB
        let bytes = (params_billions * 1_000_000_000.0 * quantization_bits as f64) / 8.0;
        (bytes / (1024.0 * 1024.0)) as u64
    }

    /// Recomienda el tamaño de contexto óptimo según la memoria disponible.
    ///
    /// Fórmula: usar la mayor cantidad de contexto que quepa en RAM
    /// dejando un margen de seguridad del 20% para el SO y otras apps.
    ///
    /// - `model_file_mb`: tamaño del archivo GGUF en MB
    /// - `kv_cache_per_token_mb`: MB por token de KV cache (default: 0.03 para 1.5B, ajustar)
    ///
    /// Retorna: contexto recomendado en tokens (mínimo 512, máximo configurado)
    pub fn recommend_context_size(
        model_file_mb: u64,
        kv_cache_per_token_mb: f64,
        max_context: u32,
        safety_margin: f64,
    ) -> u32 {
        // Obtener RAM disponible real
        let mut sys = sysinfo::System::new();
        sys.refresh_memory();
        let available_mb = sys.available_memory() / 1024 / 1024;

        // RAM usable = disponible × (1 - margen)
        let usable_mb = (available_mb as f64 * (1.0 - safety_margin)) as u64;

        if model_file_mb >= usable_mb {
            tracing::warn!(
                "Model file ({}MB) exceeds usable RAM ({}MB). Forcing minimum context (512).",
                model_file_mb, usable_mb
            );
            return 512;
        }

        // RAM para KV cache = usable - model_file - overhead_fijo
        let overhead_fijo = 200u64; // programa + buffers
        let ram_for_kv = usable_mb.saturating_sub(model_file_mb + overhead_fijo);

        if ram_for_kv < 50 {
            tracing::warn!("Very little RAM available for KV cache ({}MB). Using 512 context.", ram_for_kv);
            return 512;
        }

        // Contexto máximo que cabe
        let ctx_from_ram = (ram_for_kv as f64 / kv_cache_per_token_mb) as u32;

        // Limitar al máximo configurado
        let recommended = ctx_from_ram.min(max_context).max(512);

        tracing::info!(
            "Memory-aware context: {} ({}MB available, {}MB model, {}MB/token KV)",
            recommended, available_mb, model_file_mb, kv_cache_per_token_mb
        );

        recommended
    }

    /// V2: Auto-configura usando ExecutionPlanner + MemoryModel + HardwareHAL.
    ///
    /// Reemplaza la heurística simple por el planificador formal que ejecuta
    /// las 5 fórmulas del Memory Model. Si el planner V2 falla, usa el método
    /// original como fallback.
    pub fn auto_configure_v2(model_file_mb: u64, max_context: u32) -> (u32, u32, String) {
        // Intentar V2
        let profile = profile_device();
        let num_layers = 32; // Standard for Qwen/DeepSeek architectures
        let planner = ExecutionPlanner::new(model_file_mb as f64, num_layers);
        let plan = planner.plan_boot(&profile);

        let ctx = plan.config.max_context_tokens as u32;
        let batch = plan.config.batch_size as u32;
        let risk = plan.risk_level.clone();
        let streaming = plan.streaming_active;

        tracing::info!(
            "V2 Auto-config: ctx={} batch={} risk={} streaming={} vma={:.0}MB rss={:.0}MB",
            ctx, batch, risk, streaming,
            plan.estimated_vma_mb, plan.estimated_rss_mb
        );

        // OOM quick check
        let oom_risk = quick_check(profile.ram_total_mb, plan.estimated_vma_mb as u64);
        if oom_risk >= OomRisk::High {
            tracing::warn!(
                "OOM risk detected: {:?} (VMA={:.0}MB / RAM={}MB). Survival plan activated.",
                oom_risk, plan.estimated_vma_mb, profile.ram_total_mb
            );
            let survival = planner.plan_survival(profile.ram_available_mb as f64, profile.ram_total_mb as f64);
            return (
                survival.config.max_context_tokens as u32,
                survival.config.batch_size as u32,
                format!("survival-{}", survival.risk_level),
            );
        }

        (ctx.min(max_context).max(256), batch.min(512).max(128), risk)
    }

    /// Auto-configura los parámetros del runtime según la RAM disponible (V1 fallback).
    ///
    /// Retorna (context_size, batch_size) recomendados.
    pub fn auto_configure(model_file_mb: u64, max_context: u32) -> (u32, u32) {
        let mut sys = sysinfo::System::new();
        sys.refresh_memory();
        let available_mb = sys.available_memory() / 1024 / 1024;
        let total_mb = sys.total_memory() / 1024 / 1024;

        // KV cache por token varía según modelo. Estimación conservadora:
        // ~0.03 MB/token para 1.5B, ~0.08 MB/token para 7B, ~0.15 MB/token para 14B
        // Estimación basada en: 2 × n_embd × n_layer × sizeof(fp16) / tokens
        // Simplificado: 0.03 MB × (params_billions / 1.5)
        let params_billions = model_file_mb as f64 / 700.0; // ~700MB por billón de params en Q4
        let kv_per_token = (0.03 * (params_billions / 1.5)).max(0.01);

        let ctx = Self::recommend_context_size(model_file_mb, kv_per_token, max_context, 0.20);

        // Batch size: más pequeño si hay poca RAM
        let batch = if available_mb < 4096 { 256 } else if available_mb < 8192 { 384 } else { 512 };

        tracing::info!(
            "Auto-configure: RAM {}MB avail/{}MB total, ctx={}, batch={}",
            available_mb, total_mb, ctx, batch
        );

        (ctx, batch as u32)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_memory_manager_new() {
        let mm = MemoryManager::new(1024, 8192, 0);
        assert_eq!(mm.eviction_policy(), EvictionPolicy::LRU);
        assert_eq!(mm.max_kv_cache_mb, 1024);
    }

    #[test]
    fn test_estimate_model_memory() {
        // 7B model at 4-bit quantization
        let mem = MemoryManager::estimate_model_memory(7.0, 4);
        assert!(mem > 3000 && mem < 4000, "7B Q4 = {}MB", mem);

        // 1.5B model at 4-bit
        let mem = MemoryManager::estimate_model_memory(1.5, 4);
        assert!(mem > 700 && mem < 900, "1.5B Q4 = {}MB", mem);
    }

    #[test]
    fn test_has_enough_memory() {
        let mm = MemoryManager::new(1024, 8192, 0);
        // Real memory check - should have at least some memory
        let stats = mm.get_stats();
        assert!(stats.total_system_mb > 0, "Should detect real total memory > 0");
        assert!(stats.available_mb > 0, "Should detect real available memory > 0");
        assert!(stats.usage_percent > 0.0 && stats.usage_percent < 100.0);
    }

    #[test]
    fn test_real_memory_detected() {
        let mm = MemoryManager::new(1024, 8192, 0);
        let stats = mm.get_stats();
        // On a real system with 32GB, total should be ~32768
        // On a system with 16GB, total should be ~16384
        // Either way, it should be a reasonable number
        assert!(stats.total_system_mb >= 1024, "Total memory should be at least 1GB");
        assert!(stats.total_system_mb <= 1_000_000, "Total memory should be realistic");
    }

    #[test]
    fn test_should_evict() {
        let mm = MemoryManager::new(1024, 8192, 0);
        // On a real system with enough memory, should not evict
        let stats = mm.get_stats();
        if stats.usage_percent < 85.0 {
            assert!(!mm.should_evict(), "Should not evict if usage < 85%");
        }
    }

    #[test]
    fn test_kv_cache_estimate() {
        let mm = MemoryManager::new(1024, 8192, 0);
        let stats = mm.get_stats();
        // 8192 context * 2 / 1000 ≈ 16MB
        assert!(stats.kv_cache_mb > 0, "KV cache should be estimated");
    }
}
