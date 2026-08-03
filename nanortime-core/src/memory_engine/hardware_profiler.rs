//! Hardware Profiler — detección de capacidades del sistema en tiempo real.
//!
//! Detecta RAM, velocidad de SSD (benchmark), núcleos CPU y estado térmico.
//! Reemplaza la detección simple de sysinfo con un perfil completo del hardware.

use std::time::Instant;
use sysinfo::System;

use super::model_profile::ModelProfile;

/// Clase de dispositivo según capacidad de hardware.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum DeviceClass {
    /// Dispositivo de gama baja: <8GB RAM o SSD lento (<200 MB/s).
    LowEnd,
    /// Dispositivo de gama media: 8-16GB RAM, SSD estándar.
    MidEnd,
    /// Dispositivo de gama alta: >16GB RAM, SSD NVMe rápido.
    HighEnd,
}

/// Estado térmico del sistema.
#[derive(Debug, Clone)]
pub struct ThermalState {
    /// Si el sistema está en thermal throttling.
    pub throttling: bool,
    /// Temperatura estimada en Celsius (-1.0 = desconocida).
    pub temp_celsius: f32,
}

impl Default for ThermalState {
    fn default() -> Self {
        Self { throttling: false, temp_celsius: -1.0 }
    }
}

/// Perfil completo del hardware detectado.
#[derive(Debug, Clone)]
pub struct HardwareProfile {
    /// RAM total del sistema en MB.
    pub ram_total_mb: u64,
    /// RAM disponible actualmente en MB (dinámico).
    pub ram_available_mb: u64,
    /// Velocidad del SSD medida en MB/s (benchmark al inicio).
    pub ssd_speed_mbps: f64,
    /// Número de núcleos lógicos del CPU.
    pub cpu_cores: usize,
    /// Clase de dispositivo clasificado.
    pub device_class: DeviceClass,
    /// Estado térmico actual.
    pub thermal: ThermalState,
    /// Marca de tiempo de la última actualización.
    pub last_updated: Instant,
}

/// Profiler de hardware — detecta y monitoriza capacidades del sistema.
pub struct HardwareProfiler {
    sys: System,
    cached_profile: Option<HardwareProfile>,
    ssd_speed_cache: Option<f64>,
}

impl HardwareProfiler {
    /// Crea un nuevo profiler y realiza detección inicial.
    pub fn new() -> Self {
        let mut sys = System::new_all();
        sys.refresh_all();
        Self { sys, cached_profile: None, ssd_speed_cache: None }
    }

    /// Genera un perfil completo del hardware.
    pub fn profile(&mut self) -> HardwareProfile {
        self.sys.refresh_memory();

        let ram_total_mb = self.sys.total_memory() / 1024 / 1024;
        let ram_available_mb = self.sys.available_memory() / 1024 / 1024;
        let cpu_cores = self.sys.cpus().len().max(1);

        // SSD speed: use cached value or benchmark once
        let ssd_speed_mbps = self.ssd_speed_cache.unwrap_or_else(|| {
            let speed = self.benchmark_ssd();
            self.ssd_speed_cache = Some(speed);
            speed
        });

        let device_class = Self::classify(ram_total_mb, ssd_speed_mbps, cpu_cores);
        let thermal = self.monitor_thermal();

        let profile = HardwareProfile {
            ram_total_mb,
            ram_available_mb,
            ssd_speed_mbps,
            cpu_cores,
            device_class,
            thermal,
            last_updated: Instant::now(),
        };

        self.cached_profile = Some(profile.clone());
        profile
    }

    /// Clasifica el dispositivo según sus capacidades.
    pub fn classify_device(&self) -> DeviceClass {
        if let Some(ref p) = self.cached_profile {
            return p.device_class;
        }
        DeviceClass::MidEnd
    }

    /// Retorna la velocidad SSD medida (puede usar cache).
    pub fn get_ssd_speed(&mut self) -> f64 {
        if let Some(speed) = self.ssd_speed_cache {
            return speed;
        }
        let speed = self.benchmark_ssd();
        self.ssd_speed_cache = Some(speed);
        speed
    }

    /// Monitoriza el estado térmico del sistema.
    pub fn monitor_thermal(&self) -> ThermalState {
        // En Windows usaríamos WMI; aquí hacemos una estimación
        // basada en la carga del CPU como proxy de temperatura.
        #[cfg(any(target_os = "linux", target_os = "android"))]
        {
            // Linux/Android: leer /sys/class/thermal/thermal_zone0/temp
            for zone in 0..5 {
                let path = format!("/sys/class/thermal/thermal_zone{}/temp", zone);
                if let Ok(content) = std::fs::read_to_string(&path) {
                    if let Ok(val) = content.trim().parse::<i64>() {
                        let celsius = if val > 1000 { val as f32 / 1000.0 } else { val as f32 };
                        if celsius > 0.0 && celsius < 120.0 {
                            let throttling = celsius > 80.0;
                            return ThermalState { throttling, temp_celsius: celsius };
                        }
                    }
                }
            }
        }

        #[cfg(target_os = "macos")]
        {
            // macOS: fallback a sysctl o estimación por presión
            return ThermalState { throttling: false, temp_celsius: -1.0 };
        }

        // Windows / fallback: estimación por presión de CPU
        ThermalState { throttling: false, temp_celsius: -1.0 }
    }

    /// Obtiene RAM disponible en tiempo real (refresca sysinfo).
    pub fn get_available_ram(&mut self) -> u64 {
        self.sys.refresh_memory();
        self.sys.available_memory() / 1024 / 1024
    }

    /// Estima cuántas capas del modelo caben en RAM.
    ///
    /// Utiliza el `ModelProfile` para entender si es MoE o Denso.
    pub fn estimate_model_layers_in_ram(&mut self, profile: &ModelProfile) -> usize {
        let available_mb = self.get_available_ram();
        // Dejar 20% de margen para SO y otros procesos
        let budget_mb = (available_mb as f64 * 0.80) as u64;

        if profile.active_size_mb == 0 || profile.n_layers == 0 {
            return profile.n_layers;
        }

        let mb_per_layer = profile.mb_per_active_layer();
        let layers_fitting = (budget_mb as f64 / mb_per_layer) as usize;
        layers_fitting.min(profile.n_layers)
    }

    /// Benchmark de escritura/lectura en SSD usando archivo temporal.
    fn benchmark_ssd(&self) -> f64 {
        let tmpdir = std::env::temp_dir();
        let path = tmpdir.join("nanoai_ssd_bench.tmp");
        let data_size = 16 * 1024 * 1024usize; // 16 MB
        let data = vec![0xABu8; data_size];

        // Write benchmark
        let t0 = Instant::now();
        let write_ok = std::fs::write(&path, &data).is_ok();
        let write_dur = t0.elapsed();

        // Read benchmark
        let t1 = Instant::now();
        let read_ok = std::fs::read(&path).is_ok();
        let read_dur = t1.elapsed();

        // Cleanup
        let _ = std::fs::remove_file(&path);

        if !write_ok || !read_ok {
            tracing::warn!("SSD benchmark failed — assuming 200 MB/s");
            return 200.0;
        }

        let write_speed = data_size as f64 / write_dur.as_secs_f64() / 1_048_576.0;
        let read_speed = data_size as f64 / read_dur.as_secs_f64() / 1_048_576.0;
        let avg = (write_speed + read_speed) / 2.0;

        tracing::info!(
            "SSD benchmark: write={:.0} MB/s read={:.0} MB/s avg={:.0} MB/s",
            write_speed, read_speed, avg
        );

        avg.max(10.0) // Mínimo razonable
    }

    /// Clasifica el dispositivo según RAM, velocidad SSD y núcleos.
    fn classify(ram_total_mb: u64, ssd_speed_mbps: f64, cpu_cores: usize) -> DeviceClass {
        if ram_total_mb >= 16_384 && ssd_speed_mbps >= 400.0 && cpu_cores >= 8 {
            DeviceClass::HighEnd
        } else if ram_total_mb >= 8_192 || (ssd_speed_mbps >= 200.0 && cpu_cores >= 4) {
            DeviceClass::MidEnd
        } else {
            DeviceClass::LowEnd
        }
    }
}

impl Default for HardwareProfiler {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_classify_low_end() {
        assert_eq!(HardwareProfiler::classify(4096, 100.0, 2), DeviceClass::LowEnd);
    }

    #[test]
    fn test_classify_mid_end() {
        assert_eq!(HardwareProfiler::classify(8192, 250.0, 4), DeviceClass::MidEnd);
    }

    #[test]
    fn test_classify_high_end() {
        assert_eq!(HardwareProfiler::classify(32768, 1000.0, 16), DeviceClass::HighEnd);
    }

    #[test]
    fn test_profiler_new() {
        let profiler = HardwareProfiler::new();
        assert!(profiler.cached_profile.is_none());
    }

    #[test]
    fn test_profile_detects_real_memory() {
        let mut profiler = HardwareProfiler::new();
        let profile = profiler.profile();
        assert!(profile.ram_total_mb >= 1024, "Should detect at least 1GB RAM");
        assert!(profile.ram_available_mb > 0, "Should detect available RAM");
        assert!(profile.cpu_cores >= 1);
        assert!(profile.ssd_speed_mbps > 0.0);
    }

    #[test]
    fn test_estimate_layers_no_overflow() {
        let mut profiler = HardwareProfiler::new();
        // 7B model: ~4000MB, 32 layers
        let profile = ModelProfile::new_dense(4000, 32);
        let layers = profiler.estimate_model_layers_in_ram(&profile);
        assert!(layers <= 32, "Cannot exceed total layers");
    }

    #[test]
    fn test_estimate_layers_zero_model() {
        let mut profiler = HardwareProfiler::new();
        let profile = ModelProfile::new_dense(0, 32);
        let layers = profiler.estimate_model_layers_in_ram(&profile);
        assert_eq!(layers, 32); // Zero size → all layers fit
    }

    #[test]
    fn test_estimate_layers_moe() {
        let mut profiler = HardwareProfiler::new();
        // MoE model: 16B total (8000MB), 2.4B active (1200MB)
        let profile = ModelProfile::new_moe(8000, 1200, 32);
        let layers = profiler.estimate_model_layers_in_ram(&profile);
        // It should fit much more than dense, using the 1200MB size
        let dense_profile = ModelProfile::new_dense(8000, 32);
        let layers_dense = profiler.estimate_model_layers_in_ram(&dense_profile);
        assert!(layers > layers_dense || layers == 32, "MoE should fit more layers than dense");
    }

    #[test]
    fn test_thermal_state_default() {
        let ts = ThermalState::default();
        assert!(!ts.throttling);
        assert_eq!(ts.temp_celsius, -1.0);
    }
}
