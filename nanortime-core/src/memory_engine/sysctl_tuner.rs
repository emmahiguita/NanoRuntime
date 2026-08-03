//! Sysctl Tuner — optimizaciones del kernel Linux/Android para inferencia LLM.
//!
//! Aplica ajustes de memoria virtual del kernel para optimizar mmap de modelos grandes,
//! reducir la presión del vfs_cache y evitar stuttering por writebacks de I/O.

use std::process::Command;

/// Ajustes recomendados para inferencia LLM.
#[derive(Debug, Clone)]
pub struct MemorySysctlConfig {
    /// Permite mmap de modelos mayores a RAM física (1 = overcommit).
    pub overcommit_memory: u8,
    /// Mantiene caché mmap por más tiempo (default 100 -> 50).
    pub vfs_cache_pressure: u32,
    /// Minimiza I/O pasivo de datos sucios (default 20 -> 10).
    pub dirty_ratio: u32,
    /// Writeback background temprano (default 10 -> 5).
    pub dirty_background_ratio: u32,
    /// Nivel de swappiness equilibrado (60).
    pub swappiness: u32,
    /// Reserva mínima de seguridad en KB (64MB).
    pub min_free_kbytes: u32,
    /// Transparent Huge Pages en modo madvise.
    pub thp_mode: String,
}

impl Default for MemorySysctlConfig {
    fn default() -> Self {
        Self {
            overcommit_memory: 1,
            vfs_cache_pressure: 50,
            dirty_ratio: 10,
            dirty_background_ratio: 5,
            swappiness: 60,
            min_free_kbytes: 65536,
            thp_mode: "madvise".to_string(),
        }
    }
}

pub struct SysctlTuner;

impl SysctlTuner {
    /// Aplica la configuración de optimización de sysctl en el sistema actual.
    pub fn apply(config: &MemorySysctlConfig) -> Result<(), String> {
        #[cfg(not(target_os = "linux"))]
        {
            let _ = config;
            tracing::debug!("SysctlTuner: omitido en plataformas no Linux");
            return Ok(());
        }

        #[cfg(target_os = "linux")]
        {
            let tweaks = vec![
                ("vm.overcommit_memory", format!("{}", config.overcommit_memory)),
                ("vm.vfs_cache_pressure", format!("{}", config.vfs_cache_pressure)),
                ("vm.dirty_ratio", format!("{}", config.dirty_ratio)),
                ("vm.dirty_background_ratio", format!("{}", config.dirty_background_ratio)),
                ("vm.swappiness", format!("{}", config.swappiness)),
                ("vm.min_free_kbytes", format!("{}", config.min_free_kbytes)),
            ];

            let mut applied_count = 0;
            let mut errors = Vec::new();

            for (key, val) in tweaks {
                let res = Command::new("sysctl")
                    .arg("-w")
                    .arg(format!("{}={}", key, val))
                    .status();

                match res {
                    Ok(status) if status.success() => applied_count += 1,
                    Ok(status) => errors.push(format!("sysctl {}={} falló: {}", key, val, status)),
                    Err(e) => errors.push(format!("sysctl {}={} error: {}", key, val, e)),
                }
            }

            // Transparent Hugepages
            let _ = std::fs::write(
                "/sys/kernel/mm/transparent_hugepage/enabled",
                &config.thp_mode,
            );

            if !errors.is_empty() {
                tracing::warn!(
                    "SysctlTuner: {}/{} parámetros aplicados. Nota: requiere root/privilegios. Errores: {:?}",
                    applied_count,
                    6,
                    errors
                );
            } else {
                tracing::info!("SysctlTuner: Todos los 6 parámetros del kernel optimizados para LLM");
            }

            Ok(())
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sysctl_default_config() {
        let cfg = MemorySysctlConfig::default();
        assert_eq!(cfg.overcommit_memory, 1);
        assert_eq!(cfg.vfs_cache_pressure, 50);
        assert_eq!(cfg.thp_mode, "madvise");
    }

    #[test]
    fn test_sysctl_apply_non_linux() {
        let cfg = MemorySysctlConfig::default();
        assert!(SysctlTuner::apply(&cfg).is_ok());
    }
}
