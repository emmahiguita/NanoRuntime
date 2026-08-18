//! PrefixCache — V1.1 P0: cachear el KV del prefix estático.
//!
//! El prefix estático es la parte del prompt que NO cambia entre turnos ni
//! entre conversaciones: system prompt + tools schema + reglas estáticas.
//! Cachear su KV evita re-prefillearlo en cada conversación nueva — el mayor
//! ataque a TTFT sin tocar modelo ni añadir GPU.
//!
//! SEPARACIÓN ESTRICTA (no mezclar):
//! - PrefixCache = parte estática, reutilizable ENTRE sesiones.
//! - SessionKV   = conversación concreta del usuario (NanoSession).
//!
//! El snapshot se guarda/restaura con `InferenceBackend::save_state/load_state`
//! (ya existen) y se nombra por el hash del [PrefixKey], de modo que un prefix
//! idéntico cae en el mismo archivo y uno distinto en otro.

use std::path::{Path, PathBuf};

/// Versión del formato de estado del runtime. Cambiar (incrementar) al migrar
/// el formato del snapshot — invalida todos los snapshots antiguos.
pub const STATE_VERSION: u32 = 1;

/// Clave de identidad del prefix. Cualquier cambio en estos campos invalida
/// el snapshot: restaurar un KV semánticamente incompatible es el peor bug.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PrefixKey {
    /// Hash del modelo GGUF (o ruta). Cambio de modelo/quant → inválido.
    pub model_hash: String,
    /// Hash del chat-template (cambio de template → inválido).
    pub template_hash: u64,
    /// Hash del CONTENIDO del prefix (system + tools + reglas).
    pub prefix_hash: u64,
    /// Tamaño de contexto (n_ctx). Cambio de contexto → inválido.
    pub n_ctx: usize,
    /// Versión del formato de estado (STATE_VERSION).
    pub state_version: u32,
}

impl PrefixKey {
    pub fn new(
        model_hash: String,
        template_hash: u64,
        prefix_hash: u64,
        n_ctx: usize,
    ) -> Self {
        Self {
            model_hash,
            template_hash,
            prefix_hash,
            n_ctx,
            state_version: STATE_VERSION,
        }
    }
}

/// Estado de un lookup de prefix cache.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PrefixLookup {
    /// El snapshot existe y es válido para este key.
    Hit,
    /// No hay snapshot (prefill completo necesario).
    Miss,
    /// Cache deshabilitada por configuración.
    Disabled,
}

/// Gestor de snapshots del prefix estático (solo identidad + paths + invalidación).
/// El save/restore real del KV vive en `ModelManager`, que posee el contexto.
#[derive(Clone)]
pub struct PrefixCache {
    dir: PathBuf,
    enabled: bool,
}

impl PrefixCache {
    pub fn new(dir: PathBuf, enabled: bool) -> Self {
        Self { dir, enabled }
    }

    /// Ruta del snapshot para un key. Determinista: key idéntico → mismo path.
    pub fn snapshot_path(&self, key: &PrefixKey) -> PathBuf {
        let model = sanitize_filename(&key.model_hash);
        let name = format!(
            "{}-{:016x}-{:016x}-nctx{}-v{}.kv",
            model, key.template_hash, key.prefix_hash, key.n_ctx, key.state_version
        );
        self.dir.join(name)
    }

    /// ¿Existe un snapshot válido para este key?
    pub fn lookup(&self, key: &PrefixKey) -> PrefixLookup {
        if !self.enabled {
            return PrefixLookup::Disabled;
        }
        if self.snapshot_path(key).exists() {
            PrefixLookup::Hit
        } else {
            PrefixLookup::Miss
        }
    }

    /// Elimina el snapshot del key. Devuelve true si existía.
    pub fn invalidate(&self, key: &PrefixKey) -> bool {
        let path = self.snapshot_path(key);
        if path.exists() {
            let _ = std::fs::remove_file(&path);
            true
        } else {
            false
        }
    }

    /// Elimina TODOS los snapshots (cambio de versión de estado, limpieza).
    pub fn clear(&self) {
        if let Ok(entries) = std::fs::read_dir(&self.dir) {
            for entry in entries.flatten() {
                if entry.path().extension().and_then(|e| e.to_str()) == Some("kv") {
                    let _ = std::fs::remove_file(entry.path());
                }
            }
        }
    }

    pub fn enabled(&self) -> bool {
        self.enabled
    }
}

/// Sanitiza un identificador para usarlo como nombre de archivo.
fn sanitize_filename(s: &str) -> String {
    s.chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() || c == '-' || c == '_' || c == '.' {
                c
            } else {
                '_'
            }
        })
        .take(64)
        .collect()
}

/// FNV-1a 64 sobre múltiples partes, con separador entre partes para evitar
/// colisión ("ab"+"c" vs "a"+"bc"). Mismo algoritmo que
/// `session::template_hash` (hash de identidad, NO criptográfico).
pub fn content_hash(parts: &[&str]) -> u64 {
    let mut h: u64 = 0xcbf2_9ce4_8422_2325;
    for part in parts {
        for b in part.bytes() {
            h ^= b as u64;
            h = h.wrapping_mul(0x100_0000_01b3);
        }
        h ^= 0xff;
        h = h.wrapping_mul(0x100_0000_01b3);
    }
    h
}

/// Comprueba que el directorio de snapshots existe, creándolo si hace falta.
pub fn ensure_dir(dir: &Path) -> std::io::Result<()> {
    std::fs::create_dir_all(dir)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn content_hash_discriminates_order_and_content() {
        assert_eq!(content_hash(&["a", "b"]), content_hash(&["a", "b"]));
        // El separador evita colisión entre concatenaciones distintas.
        assert_ne!(content_hash(&["ab", "c"]), content_hash(&["a", "bc"]));
        assert_ne!(content_hash(&["a"]), content_hash(&["b"]));
    }

    #[test]
    fn key_snapshot_path_is_deterministic() {
        let cache = PrefixCache::new(PathBuf::from("/tmp/nano-prefix"), true);
        let a = PrefixKey::new("m.gguf".into(), 1, 2, 4096);
        let b = PrefixKey::new("m.gguf".into(), 1, 2, 4096);
        assert_eq!(cache.snapshot_path(&a), cache.snapshot_path(&b));
        let c = PrefixKey::new("m.gguf".into(), 1, 3, 4096); // distinto prefix
        assert_ne!(cache.snapshot_path(&a), cache.snapshot_path(&c));
    }

    #[test]
    fn lookup_disabled_when_off() {
        let cache = PrefixCache::new(PathBuf::from("/tmp/nope"), false);
        let key = PrefixKey::new("m".into(), 1, 2, 4096);
        assert_eq!(cache.lookup(&key), PrefixLookup::Disabled);
    }

    #[test]
    fn state_version_invalidates_old_snapshot() {
        let a = PrefixKey::new("m".into(), 1, 2, 4096);
        let mut b = a.clone();
        b.state_version = 2;
        let cache = PrefixCache::new(PathBuf::from("/tmp/nano-prefix"), true);
        assert_ne!(cache.snapshot_path(&a), cache.snapshot_path(&b));
    }
}
