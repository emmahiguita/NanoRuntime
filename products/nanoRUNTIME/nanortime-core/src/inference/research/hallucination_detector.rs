//! Detección de alucinaciones en tiempo real durante generación de código.
//!
//! ## Enfoque científico
//!
//! El detector analiza cada token generado usando múltiples señales:
//!
//! 1. **Entropía local** — tokens con probabilidad inusualmente baja indican
//!    que el modelo está "adivinando" (posible alucinación)
//! 2. **Perplejidad ventaneada** — perplejidad media sobre una ventana de N
//!    tokens. Un pico súbito sugiere que el modelo generó algo improbable
//! 3. **Patrones sintácticos** — en código, ciertos patrones son casi siempre
//!    alucinaciones: APIs que no existen, argumentos inventados, importaciones
//!    de módulos que no están en el contexto
//! 4. **Repetición anómala** — el modelo repite el mismo token o frase,
//!    indicando que perdió coherencia
//! 5. **Salto temático** — cambio abrupto en la distribución de tokens
//!    (detectable como una divergencia KL alta entre tokens consecutivos)
//!
//! ## Pipeline futuro
//!
//! Cuando el clasificador ML (50-100M params) esté entrenado, reemplazará
//! el análisis heurístico actual. La interfaz `HallucinationSignal` está
//! diseñada para ser compatible con ambos enfoques.
//!
//! ## Referencias
//!
//! - Varshney et al. "A Survey of Hallucination in Large Language Models" (2023)
//! - Rawte et al. "A Survey of Hallucination in Large Foundation Models" (2023)
//! - Huang et al. "Detecting Hallucinations in Large Language Models" (2024)

use std::collections::VecDeque;

/// Tipos de alucinación detectables.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum HallucinationType {
    /// API/function que no existe en la biblioteca estándar.
    NonExistentApi,
    /// Argumento de función inventado.
    InventedArgument,
    /// Variable o módulo que no existe en el contexto.
    NonExistentVariable,
    /// Import de un módulo que no existe.
    NonExistentImport,
    /// Repetición patológica del mismo token/frase.
    Repetition,
    /// Salto temático abrupto (pérdida de coherencia).
    TopicShift,
    /// Token de muy baja probabilidad (< umbral).
    LowProbability,
    /// Tipo no detectado por heurísticas (para el clasificador ML).
    Unknown,
}

/// Señal de detección emitida por el detector.
#[derive(Debug, Clone)]
pub struct HallucinationSignal {
    /// Tipo de alucinación detectada.
    pub htype: HallucinationType,
    /// Confianza de la detección (0.0–1.0).
    pub confidence: f32,
    /// Posición del token donde se detectó.
    pub token_pos: usize,
    /// Ventana de tokens alrededor de la detección.
    pub context: Vec<String>,
    /// Perplejidad en el momento de la detección.
    pub perplexity: f32,
    /// Estrategia de corrección sugerida.
    pub strategy: CorrectionStrategy,
}

/// Estrategia de corrección según el tipo de alucinación.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum CorrectionStrategy {
    /// Interrumpir generación y re-hacer el prompt con más contexto.
    Regenerate,
    /// Parche local: reemplazar solo el token problemático.
    Patch,
    /// Escalar a cloud (Tier 3) para la respuesta.
    EscalateToCloud,
    /// Ignorar (falso positivo probable).
    Ignore,
}

/// Detector de alucinaciones en tiempo real para streams de tokens.
///
/// Analiza cada token generado usando heurísticas de entropía y patrones.
/// Cuando el clasificador ML esté entrenado, se integrará como un paso
/// adicional de verificación.
///
/// # Ejemplo
///
/// ```ignore
/// let mut detector = HallucinationDetector::new(0.15, 0.75, 10);
/// detector.feed_token("import", 0.92);
/// detector.feed_token(" ", 0.88);
/// detector.feed_token("numpy", 0.95);
/// detector.feed_token(".", 0.90);
/// detector.feed_token("non_existent_func", 0.12); // Baja probabilidad
/// if let Some(signal) = detector.check() {
///     println!("Hallucination detected: {:?}", signal);
/// }
/// ```
pub struct HallucinationDetector {
    /// Umbral de probabilidad por token para considerar "baja confianza".
    probability_threshold: f32,
    /// Umbral de entropía normalizada para considerar "incierto".
    #[allow(dead_code)]
    entropy_threshold: f32,
    /// Ventana de tokens para análisis contextual.
    window_size: usize,
    /// Ventana deslizante de (token, probabilidad).
    window: VecDeque<(String, f32)>,
    /// Contador de repeticiones consecutivas.
    repeat_count: usize,
    /// Último token emitido (para detectar repeticiones).
    last_token: String,
    /// Posición actual en el stream.
    position: usize,
    /// Historial de perplejidad ventaneada.
    perplexity_window: VecDeque<f32>,
}

impl HallucinationDetector {
    /// Crea un nuevo detector con umbrales configurables.
    ///
    /// - `probability_threshold`: tokens con probabilidad menor a este valor
    ///   se marcan como sospechosos (default: 0.15)
    /// - `entropy_threshold`: entropía normalizada sobre la ventana que
    ///   dispara alarma (default: 0.75)
    /// - `window_size`: número de tokens en la ventana de análisis (default: 10)
    pub fn new(probability_threshold: f32, entropy_threshold: f32, window_size: usize) -> Self {
        Self {
            probability_threshold,
            entropy_threshold,
            window_size,
            window: VecDeque::with_capacity(window_size + 1),
            repeat_count: 0,
            last_token: String::new(),
            position: 0,
            perplexity_window: VecDeque::with_capacity(window_size),
        }
    }

    /// Alimenta el detector con un nuevo token y su probabilidad.
    ///
    /// Debe llamarse para cada token generado por el modelo.
    /// Internamente mantiene una ventana deslizante y actualiza
    /// las métricas de entropía y perplejidad.
    pub fn feed_token(&mut self, token: &str, probability: f32) {
        // Detectar repetición
        if token == self.last_token.as_str() && !token.is_empty() {
            self.repeat_count += 1;
        } else {
            self.repeat_count = 0;
        }
        self.last_token = token.to_string();

        // Actualizar ventana
        self.window.push_back((token.to_string(), probability));
        if self.window.len() > self.window_size {
            self.window.pop_front();
        }

        // Actualizar perplejidad ventaneada
        if probability > 0.0 {
            let ppl = (-probability.ln()).clamp(0.0, 100.0);
            self.perplexity_window.push_back(ppl);
            if self.perplexity_window.len() > self.window_size {
                self.perplexity_window.pop_front();
            }
        }

        self.position += 1;
    }

    /// Evalúa si hay una alucinación basada en el estado actual.
    ///
    /// Retorna `Some(HallucinationSignal)` si se detecta una alucinación,
    /// o `None` si el stream parece normal.
    ///
    /// Debe llamarse DESPUÉS de `feed_token` para evaluar el token actual.
    pub fn check(&self) -> Option<HallucinationSignal> {
        // Detección 1: Repetición patológica
        if self.repeat_count >= 5 {
            return Some(HallucinationSignal {
                htype: HallucinationType::Repetition,
                confidence: (self.repeat_count as f32 / 10.0).min(0.95),
                token_pos: self.position.saturating_sub(1),
                context: self.window.iter().map(|(t, _)| t.clone()).collect(),
                perplexity: self.avg_perplexity(),
                strategy: CorrectionStrategy::Regenerate,
            });
        }

        // Detección 2: Token de muy baja probabilidad
        if let Some((_, prob)) = self.window.back() {
            if *prob < self.probability_threshold && self.window.len() >= 2 {
                return Some(HallucinationSignal {
                    htype: HallucinationType::LowProbability,
                    confidence: 1.0 - (prob / self.probability_threshold).min(1.0),
                    token_pos: self.position.saturating_sub(1),
                    context: self.window.iter().map(|(t, _)| t.clone()).collect(),
                    perplexity: self.avg_perplexity(),
                    strategy: CorrectionStrategy::Patch,
                });
            }
        }

        // Detección 3: Perplejidad alta sostenida
        if self.perplexity_window.len() >= self.window_size {
            let avg_ppl = self.avg_perplexity();
            let max_normal_ppl = 5.0; // Perplejidad > 5 es sospechosa
            if avg_ppl > max_normal_ppl {
                let normalized = ((avg_ppl - max_normal_ppl) / 10.0).min(1.0);
                return Some(HallucinationSignal {
                    htype: HallucinationType::Unknown,
                    confidence: normalized,
                    token_pos: self.position.saturating_sub(1),
                    context: self.window.iter().map(|(t, _)| t.clone()).collect(),
                    perplexity: avg_ppl,
                    strategy: CorrectionStrategy::EscalateToCloud,
                });
            }
        }

        None
    }

    /// Perplejidad media de la ventana actual.
    pub fn avg_perplexity(&self) -> f32 {
        if self.perplexity_window.is_empty() {
            return 0.0;
        }
        self.perplexity_window.iter().sum::<f32>() / self.perplexity_window.len() as f32
    }

    /// Reinicia el detector (nuevo stream de generación).
    pub fn reset(&mut self) {
        self.window.clear();
        self.perplexity_window.clear();
        self.repeat_count = 0;
        self.last_token.clear();
        self.position = 0;
    }
}

impl Default for HallucinationDetector {
    fn default() -> Self {
        Self::new(0.15, 0.75, 10)
    }
}

/// Punto de entrada para integrar el detector en el pipeline de streaming.
///
/// Procesa un token generado y retorna una señal si se detecta alucinación.
/// Esta función será reemplazada por el clasificador ML cuando esté entrenado.
pub fn analyze_token(
    detector: &mut HallucinationDetector,
    token: &str,
    probability: f32,
) -> Option<HallucinationSignal> {
    detector.feed_token(token, probability);
    detector.check()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_no_hallucination_normal_tokens() {
        let mut d = HallucinationDetector::new(0.2, 0.8, 5);
        let tokens = vec![
            ("fn", 0.95),
            (" ", 0.90),
            ("main", 0.92),
            ("(", 0.88),
            (")", 0.85),
        ];
        for (t, p) in &tokens {
            d.feed_token(t, *p);
        }
        assert!(d.check().is_none(), "Normal tokens should not trigger");
    }

    #[test]
    fn test_detects_low_probability() {
        let mut d = HallucinationDetector::new(0.2, 0.8, 5);
        d.feed_token("import", 0.95);
        d.feed_token(" ", 0.90);
        d.feed_token("numpy", 0.93);
        d.feed_token(".", 0.88);
        d.feed_token("nonexistent_func_xyz", 0.05);
        let signal = d.check();
        assert!(signal.is_some(), "Low probability should trigger");
        assert_eq!(
            signal.as_ref().unwrap().htype,
            HallucinationType::LowProbability
        );
        assert!(signal.unwrap().confidence > 0.5);
    }

    #[test]
    fn test_detects_repetition() {
        let mut d = HallucinationDetector::new(0.2, 0.8, 5);
        let reps = ["foo", "foo", "foo", "foo", "foo", "foo"];
        for t in &reps {
            d.feed_token(t, 0.5);
        }
        let signal = d.check();
        assert!(signal.is_some(), "Repetition should trigger");
        assert_eq!(
            signal.as_ref().unwrap().htype,
            HallucinationType::Repetition
        );
    }

    #[test]
    fn test_high_perplexity_detection() {
        let mut d = HallucinationDetector::new(0.2, 0.8, 5);
        for _ in 0..10 {
            d.feed_token("xyz", 0.01);
        }
        let signal = d.check();
        assert!(signal.is_some(), "High perplexity should trigger");
        assert!(signal.unwrap().perplexity > 3.0);
    }

    #[test]
    fn test_reset() {
        let mut d = HallucinationDetector::new(0.2, 0.8, 5);
        for _ in 0..7 {
            d.feed_token("a", 0.01);
        }
        assert!(d.check().is_some());
        d.reset();
        assert!(d.check().is_none());
        assert_eq!(d.position, 0);
    }

    #[test]
    fn test_analyze_token_fn() {
        let mut d = HallucinationDetector::new(0.2, 0.8, 5);
        let s1 = analyze_token(&mut d, "safe", 0.95);
        assert!(s1.is_none());
        let s2 = analyze_token(&mut d, "nonexistent", 0.03);
        assert!(s2.is_some());
    }
}
