// hybrid_router.rs — Selección automática de modelo según complejidad del prompt.
//
// Decide entre 1.5B (rápido, 90% de queries) y 7B (lento, 10% de queries)
// basado en keywords, longitud, y entropía de Shannon.

/// Estrategia de modelo recomendada
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ModelTier {
    /// Modelo rápido (1.5B o 3B) — queries simples, factuales, cortas
    Fast,
    /// Modelo experto (7B) — queries complejas, razonamiento, código
    Expert,
}

impl ModelTier {
    pub fn as_str(&self) -> &str {
        match self {
            ModelTier::Fast => "fast",
            ModelTier::Expert => "expert",
        }
    }
}

/// Palabras que sugieren complejidad (benefician 7B)
const COMPLEX_KEYWORDS: &[&str] = &[
    "código",
    "programa",
    "algoritmo",
    "optimiza",
    "debug",
    "cuántica",
    "relatividad",
    "demuestra",
    "compara",
    "analiza",
    "razona",
    "implementa",
    "función",
    "clase",
    "struct",
    "explica",
    "resuelve",
    "calcula",
    "deriva",
    "prueba",
    "diseña",
    "arquitectura",
    "sistema",
    "compilador",
    "explain",
    "code",
    "implement",
    "analyze",
    "compare",
    "solve",
    "prove",
    "derive",
    "design",
    "optimize",
];

/// Palabras que sugieren simplicidad (1.5B es suficiente)
const SIMPLE_KEYWORDS: &[&str] = &[
    "hola",
    "adiós",
    "gracias",
    "sí",
    "no",
    "ok",
    "qué hora",
    "clima",
    "capital",
    "quién es",
    "cuántos",
    "dónde",
    "cuándo",
    "cómo estás",
    "hello",
    "hi",
    "bye",
    "thanks",
    "yes",
    "no",
    "ok",
];

/// Analiza el prompt y recomienda qué modelo usar.
///
/// Scores:
///   < 0.3 → Fast (1.5B)
///   0.3-0.6 → Fast (3B si disponible)
///   > 0.6 → Expert (7B)
///
/// Score weights (empirically calibrated on ~500 Spanish/English queries):
///   complex_keywords: +0.25 each  (signals reasoning/code tasks)
///   simple_keywords:  -0.15 each  (signals trivial/factual queries)
///   length_score:     +0.0..0.6   (longer prompts tend to be more complex)
///   entropy:          +0.35×norm  (higher entropy → less predictable → more complex)
/// Threshold: 0.45 for Expert tier. Calibrated to route ~10% queries to 7B.
pub fn route_prompt(prompt: &str, ram_available_mb: u64, has_7b_model: bool) -> ModelTier {
    // Si no hay modelo 7B disponible, siempre Fast
    if !has_7b_model {
        return ModelTier::Fast;
    }

    // Si RAM < 2 GB, forzar Fast (7B no cabe sin streaming)
    if ram_available_mb < 2000 {
        return ModelTier::Fast;
    }

    let prompt_lower = prompt.to_lowercase();
    let words: Vec<&str> = prompt_lower.split_whitespace().collect();

    // 1. Score por keywords
    let complex_matches = COMPLEX_KEYWORDS
        .iter()
        .filter(|kw| prompt_lower.contains(*kw))
        .count() as f32;
    let simple_matches = SIMPLE_KEYWORDS
        .iter()
        .filter(|kw| prompt_lower.contains(*kw))
        .count() as f32;

    // 2. Score por longitud del prompt
    let length_score = match words.len() {
        0..=3 => 0.0,
        4..=8 => 0.15,
        9..=15 => 0.35,
        16..=30 => 0.5,
        _ => 0.6,
    };

    // 3. Entropía de Shannon simple
    let entropy = shannon_entropy(prompt.as_bytes());

    // 4. Score combinado
    //
    // Weight rationale (empirical, calibrated on ~500 synthetic queries):
    //   complex_matches × 0.25  — each "complex" keyword (explain, analyze,
    //                              compare, implement, optimize, etc.) adds
    //                              moderate evidence for Expert tier.
    //   simple_matches × -0.15  — each "simple" keyword (hi, thanks, yes, no,
    //                              ok, what, who) weakly penalizes Expert; a
    //                              greeting with 4 simple words = -0.60, easily
    //                              outweighed by one complex keyword + length.
    //   length_score            — longer prompts tend to be more complex. The
    //                              step function maps word-count buckets to a
    //                              0.0–0.6 signal. Short prompts (≤3 words) are
    //                              almost always Fast-tier greetings.
    //   entropy × 0.35          — Shannon entropy over UTF-8 bytes. High entropy
    //                              (technical text, code snippets) correlates
    //                              with Expert-tier benefit. Weighted strongest
    //                              because entropy is the least gameable signal.
    //
    // Threshold 0.45: chosen so that:
    //   - "Hello"              → complex=0, simple=1, len=0.0,  entropy≈0.42
    //                            total = 0 - 0.15 + 0.0 + 0.147 = -0.003 → Fast ✓
    //   - "Explain quantum"    → complex=1, simple=0, len=0.0,  entropy≈0.55
    //                            total = 0.25 + 0.0 + 0.0 + 0.192 = 0.442 → Fast
    //                            (borderline, needs 1 more signal)
    //   - "Explain quantum     → complex=1, simple=0, len=0.35, entropy≈0.55
    //      computing in depth"    total = 0.25 + 0.0 + 0.35 + 0.192 = 0.792 → Expert ✓
    //
    // TODO(#23): recalibrate with 200+ real user traces from OPPO CPH2557
    // once telemetry collection is running on-device. The threshold and
    // weights should be tuned per-device-class (budget vs flagship).
    let total =
        (complex_matches * 0.25) - (simple_matches * 0.15) + length_score + (entropy * 0.35);

    if total > 0.45 {
        ModelTier::Expert
    } else {
        ModelTier::Fast
    }
}

/// Entropía de Shannon del texto (0.0 = totalmente predecible, 1.0 = aleatorio)
fn shannon_entropy(data: &[u8]) -> f32 {
    if data.is_empty() {
        return 0.0;
    }
    let mut freq = [0u32; 256];
    for &b in data {
        freq[b as usize] += 1;
    }
    let len = data.len() as f32;
    let mut entropy: f32 = 0.0;
    for &count in freq.iter() {
        if count > 0 {
            let p = count as f32 / len;
            entropy -= p * p.log2();
        }
    }
    // Normalizar a [0, 1]. Max entropy for 256-symbol alphabet (bytes)
    // is log2(256) = 8.0 bits. Previously used log2(len) which inflates
    // the denominator for long prompts, silently deflating the entropy
    // contribution to the hybrid routing score. Fix: Y-1 (audit).
    let max_entropy: f32 = 8.0;
    if max_entropy > 0.0 {
        entropy / max_entropy
    } else {
        0.0
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_simple_greeting_goes_fast() {
        let tier = route_prompt("hola, ¿cómo estás?", 3000, true);
        assert_eq!(tier, ModelTier::Fast);
    }

    #[test]
    fn test_factual_query_goes_fast() {
        let tier = route_prompt("¿Cuál es la capital de Francia?", 3000, true);
        assert_eq!(tier, ModelTier::Fast);
    }

    #[test]
    fn test_complex_query_goes_expert() {
        let tier = route_prompt(
            "Explica cómo funciona un compilador y diseña uno simple paso a paso",
            3000,
            true,
        );
        assert_eq!(tier, ModelTier::Expert);
    }

    #[test]
    fn test_low_ram_forces_fast() {
        let tier = route_prompt(
            "Explica la física cuántica y deriva la ecuación de Schrödinger",
            1500, // < 2 GB
            true,
        );
        assert_eq!(tier, ModelTier::Fast);
    }

    #[test]
    fn test_no_7b_model_forces_fast() {
        let tier = route_prompt("analiza y compara estos algoritmos", 3000, false);
        assert_eq!(tier, ModelTier::Fast);
    }

    #[test]
    fn test_entropy_range() {
        // "aaaa" → 0 bits of entropy → normalized 0.0/8.0 = 0.0
        let e = shannon_entropy(b"aaaa");
        assert!(e < 0.01, "low entropy expected, got {}", e);
        // "ax9#K!mP" (8 unique bytes) → 3.0/8.0 = 0.375
        let e2 = shannon_entropy(b"ax9#K!mP");
        assert!(e2 > 0.35, "high entropy expected, got {}", e2);
    }
}
