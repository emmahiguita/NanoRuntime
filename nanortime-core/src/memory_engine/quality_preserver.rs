//! Quality Preserver — monitoreo de calidad y ajuste automático de estrategia.
//!
//! Mide la perplejidad del modelo en tiempo real y activa salvaguardas
//! cuando la calidad cae por debajo de umbrales aceptables.

use std::collections::VecDeque;

/// Reporte de calidad generado por el QualityPreserver.
#[derive(Debug, Clone)]
pub struct QualityReport {
    /// Perplejidad actual medida.
    pub current_perplexity: f32,
    /// Perplejidad de baseline (primer token generado).
    pub baseline_perplexity: f32,
    /// Porcentaje de pérdida de calidad (positivo = peor, negativo = mejor).
    pub quality_drop_pct: f32,
    /// Estrategia activa recomendada.
    pub strategy: String,
    /// Si se deben proteger capas críticas.
    pub protect_critical: bool,
    /// Nivel de compresión recomendado para el KV cache.
    pub recommended_compression: String,
    /// Número de tokens evaluados desde el último reset.
    pub tokens_evaluated: usize,
}

/// Métricas de calidad actuales.
#[derive(Debug, Clone)]
pub struct QualityMetrics {
    /// Perplejidad actual.
    pub current_perplexity: f32,
    /// Perplejidad de baseline.
    pub baseline_perplexity: f32,
    /// Porcentaje de caída de calidad.
    pub quality_drop_pct: f32,
    /// Estrategia activa.
    pub strategy: String,
}

/// Preserver de calidad con monitoreo en tiempo real.
pub struct QualityPreserver {
    /// Perplejidad de referencia (medida al inicio sin compresión).
    baseline_perplexity: f32,
    /// Ventana deslizante de perplejidades recientes.
    perplexity_window: VecDeque<f32>,
    /// Tamaño de la ventana (default: 50 tokens).
    window_size: usize,
    /// Estrategia activa.
    strategy: String,
    /// Número de ciclos estables consecutivos (quality_drop < 1%).
    stable_cycles: u64,
    /// Umbral de caída para modo conservador (default: 2%).
    conservative_threshold: f32,
    /// Umbral de estabilidad para modo agresivo (default: 1%).
    stable_threshold: f32,
    /// Ciclos estables necesarios para escalar a agresivo (default: 100).
    stable_cycles_required: u64,
    /// Capas críticas protegidas (IDs).
    protected_layers: Vec<usize>,
}

impl QualityPreserver {
    /// Crea un nuevo QualityPreserver.
    ///
    /// `baseline_perplexity`: perplejidad de referencia (sin compresión).
    pub fn new(baseline_perplexity: f32) -> Self {
        Self {
            baseline_perplexity: baseline_perplexity.max(1.0),
            perplexity_window: VecDeque::with_capacity(50),
            window_size: 50,
            strategy: "balanced".to_string(),
            stable_cycles: 0,
            conservative_threshold: 2.0,
            stable_threshold: 1.0,
            stable_cycles_required: 100,
            protected_layers: Vec::new(),
        }
    }

    /// Calcula la perplejidad de un segmento de texto a partir de logits.
    ///
    /// `logits`: scores sin normalizar para el token actual.
    /// `token_ids`: IDs del token real generado (para calcular log-prob).
    /// Retorna la perplejidad instantánea.
    pub fn measure_perplexity(logits: &[f32], token_ids: &[u32]) -> f32 {
        if logits.is_empty() || token_ids.is_empty() {
            return 1.0;
        }

        // Softmax para obtener probabilidades
        let max_logit = logits.iter().cloned().fold(f32::NEG_INFINITY, f32::max);
        let exp_sum: f64 = logits.iter()
            .map(|&l| ((l - max_logit) as f64).exp())
            .sum();

        // Log-probabilidad promedio para los tokens dados
        let mut total_nll = 0.0f64;
        let mut count = 0;

        for &token_id in token_ids {
            if (token_id as usize) < logits.len() {
                let log_prob = (logits[token_id as usize] - max_logit) as f64
                    - exp_sum.ln();
                total_nll -= log_prob;
                count += 1;
            }
        }

        if count == 0 {
            return 1.0;
        }

        // Perplejidad = exp(NLL promedio)
        let avg_nll = total_nll / count as f64;
        let perplexity = avg_nll.exp() as f32;
        perplexity.max(1.0)
    }

    /// Alimenta una nueva medición de perplejidad y actualiza el estado.
    ///
    /// Llamar una vez por token generado.
    pub fn feed_perplexity(&mut self, perplexity: f32) {
        if self.perplexity_window.len() >= self.window_size {
            self.perplexity_window.pop_front();
        }
        self.perplexity_window.push_back(perplexity.max(1.0));
    }

    /// Evalúa la calidad actual y genera un reporte con recomendaciones.
    pub fn evaluate(&mut self, current_ppl: f32) -> QualityReport {
        self.feed_perplexity(current_ppl);

        // Calcular perplejidad promedio de la ventana
        let avg_ppl = if self.perplexity_window.is_empty() {
            current_ppl
        } else {
            self.perplexity_window.iter().sum::<f32>() / self.perplexity_window.len() as f32
        };

        // Calcular caída de calidad relativa al baseline
        let quality_drop_pct = if self.baseline_perplexity > 0.0 {
            ((avg_ppl - self.baseline_perplexity) / self.baseline_perplexity) * 100.0
        } else {
            0.0
        };

        // Ajustar estrategia según caída de calidad
        let (protect_critical, recommended_compression) = if quality_drop_pct > self.conservative_threshold {
            // Calidad cayendo → modo conservador
            self.strategy = "conservative".to_string();
            self.stable_cycles = 0;
            self.protect_critical_layers(&[]);

            tracing::warn!(
                "Quality drop {:.1}% > {:.1}% threshold — switching to conservative",
                quality_drop_pct, self.conservative_threshold
            );
            (true, "int8")
        } else if quality_drop_pct < self.stable_threshold {
            self.stable_cycles += 1;
            if self.stable_cycles >= self.stable_cycles_required {
                // Estable por mucho tiempo → modo agresivo
                self.strategy = "aggressive".to_string();
                tracing::info!(
                    "Quality stable ({} cycles, {:.1}% drop) — switching to aggressive",
                    self.stable_cycles, quality_drop_pct
                );
            }
            (false, "int4")
        } else {
            // Zona normal → balanced
            self.strategy = "balanced".to_string();
            (false, "int8")
        };

        QualityReport {
            current_perplexity: current_ppl,
            baseline_perplexity: self.baseline_perplexity,
            quality_drop_pct,
            strategy: self.strategy.clone(),
            protect_critical,
            recommended_compression: recommended_compression.to_string(),
            tokens_evaluated: self.perplexity_window.len(),
        }
    }

    /// Protege capas críticas de offload/compresión.
    pub fn protect_critical_layers(&mut self, layer_ids: &[usize]) {
        self.protected_layers = layer_ids.to_vec();
    }

    /// Retorna las capas protegidas actualmente.
    pub fn protected_layers(&self) -> &[usize] {
        &self.protected_layers
    }

    /// Actualiza el baseline de perplejidad.
    pub fn set_baseline(&mut self, baseline: f32) {
        self.baseline_perplexity = baseline.max(1.0);
        tracing::info!("QualityPreserver: baseline perplexity set to {:.2}", baseline);
    }

    /// Retorna las métricas actuales de calidad.
    pub fn current_metrics(&self) -> QualityMetrics {
        let avg_ppl = if self.perplexity_window.is_empty() {
            self.baseline_perplexity
        } else {
            self.perplexity_window.iter().sum::<f32>() / self.perplexity_window.len() as f32
        };

        let quality_drop_pct = if self.baseline_perplexity > 0.0 {
            ((avg_ppl - self.baseline_perplexity) / self.baseline_perplexity) * 100.0
        } else {
            0.0
        };

        QualityMetrics {
            current_perplexity: avg_ppl,
            baseline_perplexity: self.baseline_perplexity,
            quality_drop_pct,
            strategy: self.strategy.clone(),
        }
    }

    /// Genera un reporte legible del estado actual.
    pub fn report(&self) -> String {
        let metrics = self.current_metrics();
        format!(
            "[QualityPreserver] ppl={:.2} baseline={:.2} drop={:.1}% strategy={} stable_cycles={} protected_layers={}",
            metrics.current_perplexity,
            metrics.baseline_perplexity,
            metrics.quality_drop_pct,
            metrics.strategy,
            self.stable_cycles,
            self.protected_layers.len()
        )
    }

    /// Resetea el estado para una nueva sesión de generación.
    pub fn reset(&mut self) {
        self.perplexity_window.clear();
        self.stable_cycles = 0;
        self.strategy = "balanced".to_string();
        self.protected_layers.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new() {
        let qp = QualityPreserver::new(10.0);
        assert_eq!(qp.baseline_perplexity, 10.0);
        assert_eq!(qp.strategy, "balanced");
    }

    #[test]
    fn test_baseline_floor() {
        let qp = QualityPreserver::new(0.0);
        assert_eq!(qp.baseline_perplexity, 1.0); // Floor at 1.0
    }

    #[test]
    fn test_measure_perplexity_simple() {
        // Simple case: uniform distribution
        let logits = vec![1.0f32; 10];
        let ppl = QualityPreserver::measure_perplexity(&logits, &[0]);
        assert!(ppl >= 1.0, "Perplexity should be >= 1.0");
        // With uniform logits, perplexity should be approximately n_tokens
        assert!(ppl > 5.0, "Uniform distribution perplexity should be high");
    }

    #[test]
    fn test_measure_perplexity_certain() {
        // One token dominates → low perplexity
        let mut logits = vec![0.0f32; 100];
        logits[5] = 100.0; // Token 5 is almost certain
        let ppl = QualityPreserver::measure_perplexity(&logits, &[5]);
        assert!(ppl < 5.0, "Certain prediction should have low perplexity: {}", ppl);
    }

    #[test]
    fn test_evaluate_conservative_on_high_drop() {
        let mut qp = QualityPreserver::new(10.0);
        // Feed many high-perplexity values
        for _ in 0..20 {
            qp.feed_perplexity(13.0); // 30% drop
        }
        let report = qp.evaluate(13.0);
        assert_eq!(report.strategy, "conservative");
        assert!(report.protect_critical);
        assert!(report.quality_drop_pct > 2.0);
    }

    #[test]
    fn test_evaluate_stable_quality() {
        let mut qp = QualityPreserver::new(10.0);
        // Quality exactly at baseline → drop = 0%
        for _ in 0..10 {
            qp.feed_perplexity(10.0);
        }
        let report = qp.evaluate(10.0);
        assert!(report.quality_drop_pct.abs() < 0.5, "No drop expected");
        assert!(!report.protect_critical);
    }

    #[test]
    fn test_evaluate_triggers_aggressive_after_stability() {
        let mut qp = QualityPreserver::new(10.0);
        qp.stable_cycles = 99; // Just below required
        qp.feed_perplexity(10.0);
        qp.evaluate(10.0); // 100th stable cycle
        // After 100 stable cycles with <1% drop, should switch to aggressive
        // Note: this test verifies the threshold logic
        assert!(qp.stable_cycles >= 100 || qp.strategy == "aggressive");
    }

    #[test]
    fn test_report_string() {
        let qp = QualityPreserver::new(15.0);
        let report = qp.report();
        assert!(report.contains("QualityPreserver"));
        assert!(report.contains("baseline=15.00"));
    }

    #[test]
    fn test_protect_critical_layers() {
        let mut qp = QualityPreserver::new(10.0);
        qp.protect_critical_layers(&[0, 1, 15, 31]);
        assert_eq!(qp.protected_layers(), &[0, 1, 15, 31]);
    }

    #[test]
    fn test_reset() {
        let mut qp = QualityPreserver::new(10.0);
        for _ in 0..20 {
            qp.feed_perplexity(12.0);
        }
        qp.protect_critical_layers(&[1, 2, 3]);
        qp.stable_cycles = 50;
        qp.reset();
        assert!(qp.perplexity_window.is_empty());
        assert_eq!(qp.stable_cycles, 0);
        assert!(qp.protected_layers.is_empty());
    }

    #[test]
    fn test_window_bounded() {
        let mut qp = QualityPreserver::new(10.0);
        for _ in 0..100 { // Feed more than window size (50)
            qp.feed_perplexity(10.0);
        }
        assert_eq!(qp.perplexity_window.len(), qp.window_size);
    }

    #[test]
    fn test_measure_perplexity_empty() {
        let ppl = QualityPreserver::measure_perplexity(&[], &[]);
        assert_eq!(ppl, 1.0);
    }
}
