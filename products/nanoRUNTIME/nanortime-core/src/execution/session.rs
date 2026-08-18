//! NanoSession — supervisor de sesión de chat (Gate R5).
//!
//! Una sesión por `session_id`. Guarda el estado del KV cache y los gates de
//! invalidación: si cambia el modelo, el template o la generación falló, el
//! KV se invalida y el siguiente turno reconstruye el contexto. Nada supuesto:
//! cada transición refleja evidencia real del backend o del ciclo de vida.

/// Estado del ciclo de vida de una sesión.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SessionState {
    /// Sin tokens en el KV cache.
    Empty,
    /// Prefill en curso (primer token aún no emitido).
    Prefilling,
    /// KV válido y listo para el siguiente turno.
    Ready,
    /// Generando tokens.
    Generating,
    /// Cancelada: KV dudoso, reconstruir en el siguiente turno.
    Cancelled,
    /// Fallo durante la generación: KV inválido.
    Invalid,
}

/// Supervisor de sesión de chat — Gate R5. Una sesión por session_id.
#[derive(Debug, Clone)]
pub struct NanoSession {
    /// Clave de la sesión (el `session_id` del cliente).
    pub session_id: String,
    /// Identificador del modelo cargado (ruta del GGUF).
    pub model_id: String,
    /// Hash del modelo cargado (cambio de modelo → KV inválido).
    pub model_hash: String,
    /// Hash del nombre de chat-template usado (cambio de template → KV inválido).
    pub template_hash: u64,
    /// Tamaño de contexto del modelo (n_ctx).
    pub n_ctx: usize,
    /// Tokens acumulados en el KV (aproximación honesta del conteo emitido).
    pub token_count: usize,
    /// True si el KV representa de forma fiable el historial de la sesión.
    pub kv_valid: bool,
    /// Última actividad (para limpieza futura / diagnóstico).
    pub last_access: std::time::SystemTime,
    /// Estado del ciclo de vida.
    pub state: SessionState,
}

impl NanoSession {
    pub fn new(
        session_id: String,
        model_id: String,
        model_hash: String,
        template_hash: u64,
        n_ctx: usize,
    ) -> Self {
        Self {
            session_id,
            model_id,
            model_hash,
            template_hash,
            n_ctx,
            token_count: 0,
            kv_valid: false,
            last_access: std::time::SystemTime::now(),
            state: SessionState::Empty,
        }
    }
}

/// Hash estable (FNV-1a 64 bits, NO criptográfico) de un nombre de template.
/// Sirve únicamente para detectar si el template cambió entre turnos.
pub fn template_hash(name: &str) -> u64 {
    let mut h: u64 = 0xcbf2_9ce4_8422_2325;
    for b in name.bytes() {
        h ^= b as u64;
        h = h.wrapping_mul(0x100_0000_01b3);
    }
    h
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn template_hash_is_stable_and_discriminates() {
        assert_eq!(template_hash("qwen"), template_hash("qwen"));
        assert_ne!(template_hash("qwen"), template_hash("deepseek"));
    }

    #[test]
    fn session_starts_empty_and_invalid_kv() {
        let s = NanoSession::new(
            "chat-1".into(),
            "m.gguf".into(),
            "hash".into(),
            template_hash("qwen"),
            4096,
        );
        assert_eq!(s.state, SessionState::Empty);
        assert!(!s.kv_valid);
        assert_eq!(s.token_count, 0);
    }
}
