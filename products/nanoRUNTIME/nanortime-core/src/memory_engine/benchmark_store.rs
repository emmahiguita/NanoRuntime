//! BenchmarkStore — base de conocimiento local del dispositivo.
//!
//! Persiste mediciones de ejecución (threads × contexto × batch → tok/s,
//! faults, thermal) para que el planner NO vuelva a adivinar cada arranque:
//! el auto-benchmark mide una vez, guarda el ganador, y `resolve()` lo
//! reutiliza con la jerarquía exacto → mismo tier → heurística.
//!
//! Persistencia: JSON con write-tmp → fsync → rename atómico (misma
//! filosofía que el prefix cache). No SQLite: un puñado de perfiles.

use std::path::{Path, PathBuf};

use serde::{Deserialize, Serialize};

use super::gguf_layout::GgufMetadata;
use super::hardware_hal::DeviceProfile;

/// Versión del esquema del store. Si cambia la forma del JSON, subir el
/// número y los perfiles viejos se descartan (no se migran).
pub const BENCHMARK_SCHEMA_VERSION: u32 = 1;

/// Identificador estable del dispositivo, derivado del `DeviceProfile`
/// (tier + RAM + cores + big cores + storage). Basta para distinguir
/// dispositivos y para la heurística "mismo tier".
///
/// La revisión de llama.cpp/backend NO está aquí (a propósito): un cambio de
/// kernels puede alterar el ganador, así que la invalidación por revisión se
/// maneja aparte (subir `BENCHMARK_SCHEMA_VERSION` en cada bump de vendor).
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct DeviceFingerprint {
    pub tier: String,
    pub ram_total_mb: u64,
    pub cpu_cores: u32,
    pub big_cores: u32,
    pub storage_read_mbps: u64,
}

impl DeviceFingerprint {
    pub fn from_device(profile: &DeviceProfile) -> Self {
        Self {
            tier: format!("{}", profile.tier),
            ram_total_mb: profile.ram_total_mb,
            cpu_cores: profile.cpu_cores,
            big_cores: profile.big_cores,
            storage_read_mbps: profile.storage_read_mbps,
        }
    }

    /// Clave estable para el match exacto.
    pub fn key(&self) -> String {
        format!(
            "{}-{}mb-{}c{}b-{}r",
            self.tier, self.ram_total_mb, self.cpu_cores, self.big_cores, self.storage_read_mbps
        )
    }

    /// Heurística "mismo tier": mismo tier de device y mismo número de cores.
    /// Se usa para reutilizar un perfil medido en un device parecido (no el
    /// mismo exacto) cuando no hay dato exacto.
    pub fn same_tier(&self, other: &Self) -> bool {
        self.tier == other.tier && self.cpu_cores == other.cpu_cores
    }
}

/// Identificador del modelo, derivado de la metadata GGUF + tamaño de archivo.
/// El hash completo del archivo se computa una vez en import/download; aquí
/// se usa lo que ya da el parser (arquitectura + params + block_count) — lo
/// suficiente para distinguir modelos.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct ModelFingerprint {
    pub architecture: String,
    pub parameter_count: u64,
    pub block_count: u64,
    pub file_size_bytes: u64,
}

impl ModelFingerprint {
    pub fn from_metadata(metadata: &GgufMetadata, file_size_bytes: u64) -> Self {
        Self {
            architecture: metadata.architecture.clone().unwrap_or_default(),
            parameter_count: metadata.parameter_count.unwrap_or(0),
            block_count: metadata.block_count.unwrap_or(0),
            file_size_bytes,
        }
    }

    pub fn key(&self) -> String {
        format!(
            "{}-{}p-{}b-{}",
            self.architecture, self.parameter_count, self.block_count, self.file_size_bytes
        )
    }
}

/// Perfil de ejecución MEDIDO — lo que el auto-benchmark guarda para no
/// volver a adivinar. `decode_peak` vs `decode_sustained` separan la
/// velocidad en frío de la velocidad real tras el steady-state térmico.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MeasuredExecutionProfile {
    pub schema_version: u32,

    pub device: DeviceFingerprint,
    pub model: ModelFingerprint,
    pub backend: String,

    pub threads: u32,
    pub context_tokens: u32,
    pub batch_size: u32,

    pub ttft_ms: f64,
    pub prefill_tok_s: f64,

    pub decode_peak_tok_s: f64,
    pub decode_sustained_tok_s: f64,

    pub pss_peak_mb: f64,
    pub major_faults_per_second: f64,

    pub temperature_start_c: f64,
    pub temperature_peak_c: f64,
    pub thermal_decay_pct: f64,

    pub samples: u32,
    pub measured_at: String,
}

impl MeasuredExecutionProfile {
    /// Clave de deduplicación: mismo device + modelo + backend = reemplazar.
    pub fn key(&self) -> String {
        format!(
            "{}|{}|{}",
            self.device.key(),
            self.model.key(),
            self.backend
        )
    }
}

/// Nivel de resolución de un perfil encontrado por [BenchmarkStore::resolve].
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ResolutionLevel {
    /// Medido en este dispositivo exacto + modelo + backend.
    Exact,
    /// Medido en un device del mismo tier (heurística de reutilización).
    SameTier,
}

/// Store persistente de perfiles medidos. Claveado por device+modelo+backend.
/// Carga perezosa desde disco; guarda con rename atómico.
#[derive(Debug, Clone, Default)]
pub struct BenchmarkStore {
    path: PathBuf,
    profiles: Vec<MeasuredExecutionProfile>,
}

impl BenchmarkStore {
    /// Carga el store desde `path`. Si no existe o está corrupto, arranca
    /// vacío (degradación tolerante: el planner cae a heurística).
    pub fn load(path: impl AsRef<Path>) -> Self {
        let path = path.as_ref().to_path_buf();
        let profiles = std::fs::read_to_string(&path)
            .ok()
            .and_then(|s| serde_json::from_str::<Vec<MeasuredExecutionProfile>>(&s).ok())
            .unwrap_or_default();
        Self { path, profiles }
    }

    /// Store en memoria (sin persistencia). Para tests y el caso "aún no hay
    /// dir de datos".
    pub fn in_memory() -> Self {
        Self::default()
    }

    pub fn is_empty(&self) -> bool {
        self.profiles.is_empty()
    }

    pub fn len(&self) -> usize {
        self.profiles.len()
    }

    /// Inserta o reemplaza un perfil por su clave (device+modelo+backend).
    pub fn upsert(&mut self, profile: MeasuredExecutionProfile) {
        if let Some(existing) = self
            .profiles
            .iter_mut()
            .find(|p| p.key() == profile.key())
        {
            *existing = profile;
        } else {
            self.profiles.push(profile);
        }
    }

    /// Resuelve el mejor perfil para (device, model, backend):
    /// exacto → mismo tier → ninguno. Retorna el perfil + el nivel.
    pub fn resolve(
        &self,
        device: &DeviceFingerprint,
        model: &ModelFingerprint,
        backend: &str,
    ) -> Option<(MeasuredExecutionProfile, ResolutionLevel)> {
        // 1. Exacto: mismo device + modelo + backend.
        for p in &self.profiles {
            if p.device.key() == device.key()
                && p.model.key() == model.key()
                && p.backend == backend
            {
                return Some((p.clone(), ResolutionLevel::Exact));
            }
        }
        // 2. Mismo tier: device parecido, mismo modelo + backend.
        for p in &self.profiles {
            if p.device.same_tier(device) && p.model.key() == model.key() && p.backend == backend {
                return Some((p.clone(), ResolutionLevel::SameTier));
            }
        }
        None
    }

    /// Persiste con write-tmp → fsync → rename atómico.
    pub fn save(&self) -> std::io::Result<()> {
        if self.path.as_os_str().is_empty() {
            return Ok(()); // store en memoria: nada que guardar
        }
        let json = serde_json::to_string_pretty(&self.profiles)
            .map_err(|e| std::io::Error::new(std::io::ErrorKind::InvalidData, e))?;
        save_atomic(&self.path, &json)
    }
}

/// Escritura atómica: tmp + fsync + rename. Evita un JSON a medio escribir
/// si el proceso muere entre el open y el write (snapshot corrupto).
fn save_atomic(path: &Path, data: &str) -> std::io::Result<()> {
    if let Some(parent) = path.parent() {
        if !parent.as_os_str().is_empty() {
            std::fs::create_dir_all(parent)?;
        }
    }
    let tmp = path.with_extension("json.tmp");
    {
        use std::io::Write;
        let mut f = std::fs::File::create(&tmp)?;
        f.write_all(data.as_bytes())?;
        f.sync_all()?;
    }
    std::fs::rename(&tmp, path)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    fn device(tier: &str, ram: u64, cores: u32) -> DeviceFingerprint {
        DeviceFingerprint {
            tier: tier.to_string(),
            ram_total_mb: ram,
            cpu_cores: cores,
            big_cores: cores / 2,
            storage_read_mbps: 300,
        }
    }

    fn model(arch: &str, params: u64) -> ModelFingerprint {
        ModelFingerprint {
            architecture: arch.to_string(),
            parameter_count: params,
            block_count: 28,
            file_size_bytes: 1024 * 1024 * 1024,
        }
    }

    fn profile(device: &DeviceFingerprint, model: &ModelFingerprint, tok_s: f64) -> MeasuredExecutionProfile {
        MeasuredExecutionProfile {
            schema_version: BENCHMARK_SCHEMA_VERSION,
            device: device.clone(),
            model: model.clone(),
            backend: "cpu".to_string(),
            threads: 4,
            context_tokens: 4096,
            batch_size: 256,
            ttft_ms: 400.0,
            prefill_tok_s: 20.0,
            decode_peak_tok_s: tok_s,
            decode_sustained_tok_s: tok_s * 0.9,
            pss_peak_mb: 1500.0,
            major_faults_per_second: 2.0,
            temperature_start_c: 30.0,
            temperature_peak_c: 42.0,
            thermal_decay_pct: 0.1,
            samples: 50,
            measured_at: "2026-08-19T00:00:00Z".to_string(),
        }
    }

    #[test]
    fn resolve_exact_hits() {
        let d = device("MidRange", 8192, 8);
        let m = model("qwen2", 1_500_000_000);
        let mut store = BenchmarkStore::in_memory();
        store.upsert(profile(&d, &m, 4.2));

        let (p, level) = store.resolve(&d, &m, "cpu").unwrap();
        assert_eq!(level, ResolutionLevel::Exact);
        assert!((p.decode_peak_tok_s - 4.2).abs() < 0.001);
    }

    #[test]
    fn resolve_same_tier_fallback() {
        let d1 = device("MidRange", 8192, 8);
        let d2 = device("MidRange", 6144, 8); // mismo tier + cores, distinta RAM
        let m = model("qwen2", 1_500_000_000);
        let mut store = BenchmarkStore::in_memory();
        store.upsert(profile(&d1, &m, 4.2));

        let (p, level) = store.resolve(&d2, &m, "cpu").unwrap();
        assert_eq!(level, ResolutionLevel::SameTier);
        assert!((p.decode_peak_tok_s - 4.2).abs() < 0.001);
    }

    #[test]
    fn resolve_miss_returns_none() {
        let d = device("MidRange", 8192, 8);
        let m = model("qwen2", 1_500_000_000);
        let store = BenchmarkStore::in_memory();
        assert!(store.resolve(&d, &m, "cpu").is_none());
    }

    #[test]
    fn upsert_replaces_by_key() {
        let d = device("MidRange", 8192, 8);
        let m = model("qwen2", 1_500_000_000);
        let mut store = BenchmarkStore::in_memory();
        store.upsert(profile(&d, &m, 4.2));
        store.upsert(profile(&d, &m, 5.1)); // mismo key, distinto valor
        assert_eq!(store.len(), 1);
        let (p, _) = store.resolve(&d, &m, "cpu").unwrap();
        assert!((p.decode_peak_tok_s - 5.1).abs() < 0.001);
    }

    #[test]
    fn save_load_roundtrip() {
        let dir = std::env::temp_dir().join(format!("nano_bench_store_test_{}", std::process::id()));
        let path = dir.join("benchmark-store-v1.json");
        let d = device("MidRange", 8192, 8);
        let m = model("qwen2", 1_500_000_000);

        let mut store = BenchmarkStore::load(&path);
        store.upsert(profile(&d, &m, 4.2));
        store.save().unwrap();

        let reloaded = BenchmarkStore::load(&path);
        assert_eq!(reloaded.len(), 1);
        let (p, level) = reloaded.resolve(&d, &m, "cpu").unwrap();
        assert_eq!(level, ResolutionLevel::Exact);
        assert!((p.decode_peak_tok_s - 4.2).abs() < 0.001);

        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn corrupt_file_loads_empty() {
        let dir = std::env::temp_dir().join(format!("nano_bench_store_corrupt_{}", std::process::id()));
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("benchmark-store-v1.json");
        std::fs::write(&path, "not json").unwrap();

        let store = BenchmarkStore::load(&path);
        assert!(store.is_empty());

        let _ = std::fs::remove_dir_all(&dir);
    }
}
