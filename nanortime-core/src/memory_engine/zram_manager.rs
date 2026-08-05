//! Zram & Zswap Manager — gestión de swap comprimido en RAM para Linux/Android.
//!
//! Configura `/dev/zram0` con compresión `lz4` o `zstd` para comprimir el KV cache
//! en memoria RAM con un ratio de compresión estimado de 3-4x (2GB KV cache -> ~500MB RAM).

use std::path::Path;

/// Estado de zram / zswap en el sistema.
#[derive(Debug, Clone)]
pub struct ZramStatus {
    pub is_supported: bool,
    pub is_active: bool,
    pub device: String,
    pub disksize_bytes: u64,
    pub algorithm: String,
}

pub struct ZramManager {
    device: String,
}

impl Default for ZramManager {
    fn default() -> Self {
        Self::new("/dev/zram0")
    }
}

impl ZramManager {
    pub fn new(device: &str) -> Self {
        Self {
            device: device.to_string(),
        }
    }

    /// Comprueba si el kernel tiene soporte para zram.
    pub fn check_status(&self) -> ZramStatus {
        let path = Path::new(&self.device);
        let sys_path = Path::new("/sys/block/zram0");
        let is_supported = sys_path.exists() || Path::new("/sys/module/zswap").exists();
        let is_active = path.exists();

        let mut disksize_bytes = 0;
        let mut algorithm = "lz4".to_string();

        if is_active {
            if let Ok(content) = std::fs::read_to_string("/sys/block/zram0/disksize") {
                disksize_bytes = content.trim().parse::<u64>().unwrap_or(0);
            }
            if let Ok(content) = std::fs::read_to_string("/sys/block/zram0/comp_algorithm") {
                // Algoritmo activo viene entre corchetes, e.g. "lzo [lz4] zstd"
                if let Some(caps) = content.split_whitespace().find(|s| s.starts_with('[') && s.ends_with(']')) {
                    algorithm = caps.trim_matches(&['[', ']'][..]).to_string();
                }
            }
        }

        ZramStatus {
            is_supported,
            is_active,
            device: self.device.clone(),
            disksize_bytes,
            algorithm,
        }
    }

    /// Configura y activa zram específicamente para comprimir el KV Cache del modelo LLM.
    ///
    /// `size_mb`: tamaño deseado del swap en MB (e.g. 2048 para 2GB).
    pub fn setup_kv_cache_swap(&self, size_mb: usize) -> Result<(), String> {
        #[cfg(not(target_os = "linux"))]
        {
            let _ = size_mb;
            return Err("zram/zswap solo es soportado en sistemas Linux/Android".to_string());
        }

        #[cfg(target_os = "linux")]
        {
            let zram_size_bytes = (size_mb as u64) * 1024 * 1024;

            // 1. Cargar módulo zram si no existe
            let _ = Command::new("modprobe")
                .arg("zram")
                .arg("num_devices=1")
                .status();

            // 2. Definir algoritmo de compresión (preferir lz4 por baja latencia de CPU)
            let _ = std::fs::write("/sys/block/zram0/comp_algorithm", "lz4");

            // 3. Establecer el tamaño del disco zram
            if let Err(e) = std::fs::write("/sys/block/zram0/disksize", format!("{}", zram_size_bytes)) {
                tracing::warn!("No se pudo escribir disksize en /sys/block/zram0: {}", e);
            }

            // 4. Crear espacio swap
            let mkswap_res = Command::new("mkswap")
                .arg(&self.device)
                .status();

            if let Err(e) = mkswap_res {
                return Err(format!("Error al ejecutar mkswap {}: {}", self.device, e));
            }

            // 5. Activar swapon con prioridad alta (-p 100)
            let swapon_res = Command::new("swapon")
                .arg("-p")
                .arg("100")
                .arg(&self.device)
                .status();

            match swapon_res {
                Ok(status) if status.success() => {
                    tracing::info!("ZRAM swap activado en {} con {} MB", self.device, size_mb);
                    Ok(())
                }
                Ok(status) => Err(format!("swapon devolvió código de salida no cero: {}", status)),
                Err(e) => Err(format!("Error al ejecutar swapon: {}", e)),
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_zram_manager_init() {
        let mgr = ZramManager::default();
        let status = mgr.check_status();
        assert_eq!(status.device, "/dev/zram0");
    }
}
