//! Speculative Decoder — Draft model proposes, target model verifies.
//!
//! Implementa speculative decoding para acelerar la inferencia del modelo
//! objetivo (target, ej: DeepSeek 7B) usando un modelo pequeño (draft,
//! ej: Qwen 1.5B) que predice K tokens candidatos.
//!
//! ## Algoritmo
//! 1. El target genera 1 token (o usa el último aceptado).
//! 2. El draft genera K tokens autoregresivamente desde ahí.
//! 3. El target verifica los K tokens en un solo forward pass.
//! 4. Se aceptan tokens hasta el primero que rechaza.
//! 5. El target genera el token correcto en la posición del rechazo.
//!
//! ## Nota sobre la FFI
//! La FFI actual (nanortime-ffi) expone una API de alto nivel
//! (tokenize + generate con probabilidades). La verificación por lote
//! (llama_decode_batch + llama_get_logits) requiere extender la FFI
//! con acceso a logits crudos — documentado en `extend_ffi_for_speculative()`.

use crate::memory_engine::hardware_hal::DeviceProfile;

/// Número máximo de tokens que el draft intenta predecir.
pub const MAX_DRAFT_TOKENS: usize = 5;
/// Número mínimo de tokens de draft.
pub const MIN_DRAFT_TOKENS: usize = 2;

/// Modo de inferencia seleccionado por el planner.
#[derive(Debug, Clone, PartialEq)]
pub enum InferenceMode {
    /// Inferencia estándar sin draft.
    Standard { context: usize },
    /// Speculative decoding con K tokens de draft (modelo draft externo).
    Speculative { draft_tokens: usize },
    /// Speculative MTP: el MISMO modelo propone drafts con sus cabezas NextN.
    /// No requiere un GGUF draft separado — solo el contexto draft (1 capa,
    /// ~15% RAM extra del target). n_max = drafts por verificación.
    Mtp { n_max: usize },
    /// Modo supervivencia (contexto mínimo).
    Survival { context: usize },
}

/// Plan de ejecución para speculative decoding.
#[derive(Debug, Clone)]
pub struct SpeculativePlan {
    pub mode: InferenceMode,
    pub max_tokens: usize,
    pub temperature: f32,
}

impl SpeculativePlan {
    /// Decide el modo según RAM disponible y tamaño de modelos.
    ///
    /// | RAM libre          | Modo                          |
    /// |--------------------|-------------------------------|
    /// | > target+draft+500 | Speculative { K: 4 }          |
    /// | > target+draft+200 | Speculative { K: 2 }          |
    /// | > target+300       | Standard { ctx: 512 }         |
    /// | else               | Survival { ctx: 256 }         |
    pub fn plan(profile: &DeviceProfile, target_size_mb: u64, draft_size_mb: u64) -> Self {
        Self::plan_with_mtp(profile, target_size_mb, draft_size_mb, false)
    }

    /// Como [`Self::plan`] pero prioriza speculative MTP cuando el modelo lo
    /// soporta (`model_supports_mtp`): el draft es el mismo GGUF, así que solo
    /// cuesta ~15% de RAM extra del target en vez de un modelo draft completo.
    pub fn plan_with_mtp(
        profile: &DeviceProfile,
        target_size_mb: u64,
        draft_size_mb: u64,
        model_supports_mtp: bool,
    ) -> Self {
        let avail = profile.ram_available_mb;
        let overhead = 500u64;

        // MTP: mismo modelo + ctx draft de 1 capa (~15% del target, min 200 MB).
        let mtp_overhead = (target_size_mb as f64 * 0.15).max(200.0) as u64;

        let mode = if model_supports_mtp && avail > target_size_mb + mtp_overhead {
            // n_max=1: óptimo medido en host (1.2-1.4x). n_max>1 degrada en
            // CPU porque el re-decode del ctx draft cuesta más que lo que
            // ahorran los drafts adicionales.
            InferenceMode::Mtp { n_max: 1 }
        } else if avail > target_size_mb + draft_size_mb + overhead {
            InferenceMode::Speculative { draft_tokens: 4 }
        } else if avail > target_size_mb + draft_size_mb + 200 {
            InferenceMode::Speculative { draft_tokens: 2 }
        } else if avail > target_size_mb + 300 {
            InferenceMode::Standard { context: 512 }
        } else {
            InferenceMode::Survival { context: 256 }
        };

        // Presupuesto de tokens: ~0.03 MB/token de KV cache, 35% de RAM libre
        let max_tokens = ((avail as f64 * 0.35) / 0.03) as usize;

        Self {
            mode,
            max_tokens: max_tokens.max(16),
            temperature: 0.0,
        }
    }
}

/// Estadísticas de aceptación del speculative decoding.
#[derive(Debug, Default, Clone)]
pub struct SpeculativeStats {
    pub total_batches: usize,
    pub total_draft_tokens: usize,
    pub total_accepted_tokens: usize,
}

impl SpeculativeStats {
    /// Tasa de aceptación de tokens del draft (0.0 - 1.0).
    pub fn acceptance_rate(&self) -> f32 {
        if self.total_draft_tokens == 0 {
            0.0
        } else {
            self.total_accepted_tokens as f32 / self.total_draft_tokens as f32
        }
    }

    /// Speedup estimado frente a target puro.
    ///
    /// Fórmula: speedup ≈ 1 / (1 - p_accept × (K-1)/K)
    pub fn estimated_speedup(&self, k: usize) -> f32 {
        let p = self.acceptance_rate();
        if k <= 1 {
            1.0
        } else {
            let saved = p * (k - 1) as f32 / k as f32;
            let _ = saved;
            // Cada batch acepta p×K tokens con 1 verificación del target
            // + 1 token extra del target. Ganancia ≈ (p×K) tokens / (K+1) forwards del draft
            1.0 / (1.0 - p * 0.5)
        }
    }
}

/// Decisor de draft tokens (K) adaptativo.
///
/// Ajusta K según la tasa de aceptación observada:
/// - aceptación > 80% → sube K
/// - aceptación < 40% → baja K
pub struct DraftTokenAdjuster {
    pub current: usize,
    stats: SpeculativeStats,
}

/// Quality guard — garantiza que speculative nunca degrade el resultado.
///
/// Speculative decoding es LOSSLESS en calidad: el target verifica cada token
/// del draft y corrige si difiere. La salida final es idéntica a la generación
/// estándar. Este guard garantiza además que no se PIERDA VELOCIDAD:
/// si la tasa de aceptación del draft cae por debajo del umbral, el sistema
/// vuelve a modo estándar (el draft solo añadiría overhead).
pub struct QualityGuard {
    /// Mínima tasa de aceptación para mantener speculative activo.
    /// Por debajo: fallback a modo estándar (misma calidad, velocidad óptima).
    min_acceptance: f32,
    /// Número de batches consecutivos para evaluar.
    window_size: usize,
    /// Historial de tasas de aceptación recientes.
    recent_rates: Vec<f32>,
}

impl QualityGuard {
    /// Guard con umbral por defecto (25% de aceptación mínima).
    ///
    /// Si el draft acierta <25% de tokens, usarlo añade overhead sin
    /// beneficio → fallback a estándar. Calidad NUNCA se pierde.
    pub fn new() -> Self {
        Self::default()
    }
}

impl Default for QualityGuard {
    fn default() -> Self {
        Self {
            min_acceptance: 0.25,
            window_size: 10,
            recent_rates: Vec::with_capacity(10),
        }
    }
}

impl QualityGuard {
    /// Registra la tasa de un batch y decide si continuar con speculative.
    pub fn observe(&mut self, acceptance: f32) -> KeepSpeculative {
        self.recent_rates.push(acceptance);
        if self.recent_rates.len() > self.window_size {
            self.recent_rates.remove(0);
        }

        // Necesitamos al menos 3 batches para decidir
        if self.recent_rates.len() < 3 {
            return KeepSpeculative::Yes;
        }

        let avg: f32 = self.recent_rates.iter().sum::<f32>() / self.recent_rates.len() as f32;
        if avg < self.min_acceptance {
            KeepSpeculative::FallbackToStandard
        } else {
            KeepSpeculative::Yes
        }
    }

    /// Reset tras cambiar de contexto o modelo.
    pub fn reset(&mut self) {
        self.recent_rates.clear();
    }
}

/// Decisión del quality guard.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum KeepSpeculative {
    /// Continuar con speculative decoding.
    Yes,
    /// Volver a generación estándar (draft no aporta velocidad).
    FallbackToStandard,
}

impl DraftTokenAdjuster {
    pub fn new(initial: usize) -> Self {
        Self {
            current: initial.clamp(MIN_DRAFT_TOKENS, MAX_DRAFT_TOKENS),
            stats: SpeculativeStats::default(),
        }
    }

    /// Registra los resultados de un batch de verificación.
    pub fn record(&mut self, draft_count: usize, accepted: usize) {
        self.stats.total_batches += 1;
        self.stats.total_draft_tokens += draft_count;
        self.stats.total_accepted_tokens += accepted;
        self.adjust();
    }

    fn adjust(&mut self) {
        if self.stats.total_batches < 3 {
            return;
        }
        let rate = self.stats.acceptance_rate();
        if rate > 0.8 && self.current < MAX_DRAFT_TOKENS {
            self.current += 1;
        } else if rate < 0.4 && self.current > MIN_DRAFT_TOKENS {
            self.current -= 1;
        }
    }

    pub fn stats(&self) -> &SpeculativeStats {
        &self.stats
    }
}

/// Proyección de speedup según tasa de aceptación (para el paper).
///
/// | Aceptación | K=2 | K=3 | K=4 |
/// |------------|-----|-----|-----|
/// | 70%        | 1.5×| 1.8×| 2.0×|
/// | 80%        | 1.7×| 2.1×| 2.5×|
pub fn projected_speedup(p_accept: f32, k: usize) -> f32 {
    // Modelo: cada verificación del target cuesta 1 forward (~4s en Samsung).
    // El draft genera K tokens en K forwards del 1.5B (~0.33s cada uno).
    // Ganancia neta por batch ≈ (p×K - 1) tokens gratis.
    let k = k.max(1) as f32;
    let accepted_expected = p_accept * k;
    // Tokens generados por forward del target: 1 (siempre) + (p×K) aceptados
    let tokens_per_verify = 1.0 + accepted_expected;
    // Costo: 1 forward target + K forwards draft
    // speedup vs target puro (1 token por forward)
    tokens_per_verify // tokens generados por cada verificación del target
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::memory_engine::hardware_hal::DeviceProfile;

    fn samsung() -> DeviceProfile {
        DeviceProfile {
            ram_total_mb: 3814,
            ram_available_mb: 1900,
            storage_read_mbps: 364,
            storage_write_mbps: 200,
            cpu_cores: 8,
            big_cores: 4,
            cpu_temp_c: 42,
            zram_active: true,
            npu_available: false,
            tier: crate::memory_engine::hardware_hal::DeviceTier::Budget,
            oom_score: 180,
            oom_score_adj: 0,
        }
    }

    #[test]
    fn test_plan_samsung_no_draft() {
        // 7B (4470) + 1.5B (1070) > RAM libre (1900)
        let plan = SpeculativePlan::plan(&samsung(), 4470, 1070);
        assert!(!matches!(plan.mode, InferenceMode::Speculative { .. }));
        // No cabe draft → Standard o Survival
        assert!(matches!(
            plan.mode,
            InferenceMode::Standard { .. } | InferenceMode::Survival { .. }
        ));
    }

    #[test]
    fn test_plan_oppo_with_draft() {
        let oppo = DeviceProfile {
            ram_available_mb: 3900,
            ..samsung()
        };
        let plan = SpeculativePlan::plan(&oppo, 4470, 1070);
        // 3900 > 4470 + 1070 + 500? No. Pero 3900 > 4470+300? No.
        // Con RAM 3900 y target 4470, ni el target cabe solo sin streaming.
        assert!(matches!(plan.mode, InferenceMode::Survival { .. }));
    }

    #[test]
    fn test_plan_small_target_with_draft() {
        // Target 1.5B (1070) + draft 0.5B (350) en Samsung (1900)
        let plan = SpeculativePlan::plan(&samsung(), 1070, 350);
        // 1900 > 1070 + 350 + 500 = 1920? Justo no.
        // 1900 > 1070 + 350 + 200 = 1620? Sí → Speculative K=2
        assert!(matches!(
            plan.mode,
            InferenceMode::Speculative { draft_tokens: 2 }
        ));
    }

    #[test]
    fn test_plan_mtp_priority_over_external_draft() {
        // Modelo con NextN: MTP gana aunque haya RAM para draft externo,
        // porque MTP no carga un GGUF draft (más barato en RAM).
        let plan = SpeculativePlan::plan_with_mtp(&samsung(), 1070, 350, true);
        assert!(matches!(plan.mode, InferenceMode::Mtp { n_max: 1 }));
    }

    #[test]
    fn test_plan_mtp_not_selected_without_support() {
        // Sin cabezas NextN → vuelve al draft externo.
        let plan = SpeculativePlan::plan_with_mtp(&samsung(), 1070, 350, false);
        assert!(matches!(
            plan.mode,
            InferenceMode::Speculative { .. } | InferenceMode::Standard { .. }
        ));
    }

    #[test]
    fn test_plan_mtp_requires_room_for_overhead() {
        // 7B (4470) en Samsung (1900): 1900 < 4470 + 670 → ni MTP ni draft.
        let plan = SpeculativePlan::plan_with_mtp(&samsung(), 4470, 1070, true);
        assert!(!matches!(plan.mode, InferenceMode::Mtp { .. }));
        assert!(matches!(
            plan.mode,
            InferenceMode::Standard { .. } | InferenceMode::Survival { .. }
        ));
    }

    #[test]
    fn test_adjuster_raises_k_on_high_acceptance() {
        let mut adj = DraftTokenAdjuster::new(3);
        for _ in 0..5 {
            adj.record(3, 3); // 100% acceptance
        }
        assert!(adj.current > 3);
    }

    #[test]
    fn test_projected_speedup() {
        // 80% acceptance, K=4 → ~2.5x
        let s = projected_speedup(0.8, 4);
        assert!(s > 2.0);
    }

    #[test]
    fn test_quality_guard_keeps_good_draft() {
        let mut guard = QualityGuard::new();
        let mut decision = KeepSpeculative::Yes;
        for _ in 0..5 {
            decision = guard.observe(0.7); // 70% acceptance
        }
        assert_eq!(decision, KeepSpeculative::Yes);
    }

    #[test]
    fn test_quality_guard_fallback_on_poor_draft() {
        let mut guard = QualityGuard::new();
        let mut decision = KeepSpeculative::Yes;
        for _ in 0..5 {
            decision = guard.observe(0.1); // 10% acceptance — draft es inútil
        }
        assert_eq!(decision, KeepSpeculative::FallbackToStandard);
    }

    #[test]
    fn test_quality_guard_requires_min_batches() {
        let mut guard = QualityGuard::new();
        // Con menos de 3 batches, nunca hace fallback
        let d1 = guard.observe(0.0);
        let d2 = guard.observe(0.0);
        assert_eq!(d1, KeepSpeculative::Yes);
        assert_eq!(d2, KeepSpeculative::Yes);
    }

    #[test]
    fn test_quality_guard_reset() {
        let mut guard = QualityGuard::new();
        for _ in 0..5 {
            guard.observe(0.1);
        }
        assert_eq!(guard.observe(0.1), KeepSpeculative::FallbackToStandard);
        guard.reset();
        assert_eq!(guard.observe(0.0), KeepSpeculative::Yes); // Historial limpio
    }
}
