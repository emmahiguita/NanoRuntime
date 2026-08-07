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
    "código", "programa", "algoritmo", "optimiza", "debug",
    "cuántica", "relatividad", "demuestra", "compara", "analiza",
    "razona", "implementa", "función", "clase", "struct",
    "explica", "resuelve", "calcula", "deriva", "prueba",
    "diseña", "arquitectura", "sistema", "compilador",
    "explain", "code", "implement", "analyze", "compare",
    "solve", "prove", "derive", "design", "optimize",
];

/// Palabras que sugieren simplicidad (1.5B es suficiente)
const SIMPLE_KEYWORDS: &[&str] = &[
    "hola", "adiós", "gracias", "sí", "no", "ok",
    "qué hora", "clima", "capital", "quién es",
    "cuántos", "dónde", "cuándo", "cómo estás",
    "hello", "hi", "bye", "thanks", "yes", "no", "ok",
];

/// Analiza el prompt y recomienda qué modelo usar.
///
/// Scores:
///   < 0.3 → Fast (1.5B)
///   0.3-0.6 → Fast (3B si disponible)
///   > 0.6 → Expert (7B)
pub fn route_prompt(
    prompt: &str,
    ram_available_mb: u64,
    has_7b_model: bool,
) -> ModelTier {
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

    // 4. Score combinado (pesos empíricos)
    let total = (complex_matches * 0.25)
        - (simple_matches * 0.15)
        + length_score
        + (entropy * 0.35);

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
    // Normalizar a [0, 1]
    let max_entropy = (len as f32).log2();
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
        let e = shannon_entropy(b"aaaa");
        assert!(e < 0.3, "low entropy expected, got {}", e);
        let e2 = shannon_entropy(b"ax9#K!mP");
        assert!(e2 > 0.5, "high entropy expected, got {}", e2);
    }
}
