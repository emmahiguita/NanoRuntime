//! Evaluación de confianza basada en entropía.
//!
//! Calcula la entropía de las distribuciones de probabilidad de tokens
//! generadas por el modelo local. Una entropía baja indica alta confianza;
//! una entropía alta sugiere incertidumbre y posible alucinación.

/// Calcula la entropía de Shannon para una distribución de probabilidades.
///
/// Fórmula: H = -Σ p(x) * log2(p(x))
///
/// Donde p(x) es la probabilidad de cada token y la suma es sobre
/// todos los tokens en el vocabulario.
///
/// Una entropía de 0 indica certeza absoluta (una sola opción con probabilidad 1).
/// La entropía máxima es log2(n) para n opciones equiprobables.
///
/// # Ejemplos
///
/// ```
/// use nanortime_core::orchestrator::confidence::calculate_entropy;
///
/// // Distribución uniforme: máxima entropía
/// let probs = vec![0.25, 0.25, 0.25, 0.25];
/// let entropy = calculate_entropy(&probs);
/// assert!((entropy - 2.0).abs() < 0.01); // log2(4) = 2.0
///
/// // Distribución cierta: entropía cero
/// let probs = vec![1.0, 0.0, 0.0, 0.0];
/// let entropy = calculate_entropy(&probs);
/// assert!(entropy.abs() < 0.01);
/// ```
pub fn calculate_entropy(probabilities: &[f32]) -> f32 {
    probabilities
        .iter()
        .filter(|&&p| p > 0.0)
        .map(|&p| -p * p.log2())
        .sum()
}

/// Calcula la entropía normalizada (0.0 a 1.0) para facilitar comparaciones.
///
/// La entropía normalizada es entropy / log2(n), donde n es el número de opciones.
/// Esto permite comparar entropías entre vocabularios de diferentes tamaños.
///
/// Un valor cercano a 0 indica alta confianza; cercano a 1 indica máxima incertidumbre.
pub fn normalized_entropy(probabilities: &[f32]) -> f32 {
    let n = probabilities.len() as f32;
    if n <= 1.0 {
        return 0.0;
    }
    let raw = calculate_entropy(probabilities);
    let max_entropy = n.log2();
    if max_entropy == 0.0 {
        0.0
    } else {
        (raw / max_entropy).clamp(0.0, 1.0)
    }
}

/// Convierte entropía a una puntuación de confianza (0.0 = nada, 1.0 = máxima).
///
/// confidence = 1.0 - normalized_entropy
pub fn entropy_to_confidence(probabilities: &[f32]) -> f32 {
    1.0 - normalized_entropy(probabilities)
}

/// Evalúa si una respuesta tiene suficiente confianza según un umbral.
///
/// Retorna `true` si la confianza está por encima del umbral,
/// indicando que la respuesta es probablemente correcta.
pub fn is_confident(probabilities: &[f32], threshold: f32) -> bool {
    entropy_to_confidence(probabilities) >= threshold
}

/// Calcula la perplejidad a partir de la entropía.
///
/// Perplejidad = 2^H
///
/// Una perplejidad baja indica que el modelo está "sorprendido" con poca frecuencia;
/// una perplejidad alta sugiere incertidumbre.
pub fn perplexity(probabilities: &[f32]) -> f32 {
    2.0f32.powf(calculate_entropy(probabilities))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_entropy_uniform() {
        let probs = vec![0.25, 0.25, 0.25, 0.25];
        let entropy = calculate_entropy(&probs);
        assert!((entropy - 2.0).abs() < 0.01);
    }

    #[test]
    fn test_entropy_certain() {
        let probs = vec![1.0, 0.0, 0.0, 0.0];
        let entropy = calculate_entropy(&probs);
        assert!(entropy.abs() < 0.01);
    }

    #[test]
    fn test_entropy_mixed() {
        let probs = vec![0.7, 0.2, 0.1, 0.0];
        let entropy = calculate_entropy(&probs);
        assert!(entropy > 0.0 && entropy < 2.0);
    }

    #[test]
    fn test_normalized_entropy_uniform() {
        let probs = vec![0.25, 0.25, 0.25, 0.25];
        let norm = normalized_entropy(&probs);
        assert!((norm - 1.0).abs() < 0.01);
    }

    #[test]
    fn test_normalized_entropy_certain() {
        let probs = vec![1.0, 0.0, 0.0, 0.0];
        let norm = normalized_entropy(&probs);
        assert!(norm.abs() < 0.01);
    }

    #[test]
    fn test_entropy_to_confidence() {
        let certain = vec![1.0, 0.0];
        let uncertain = vec![0.5, 0.5];

        let conf_certain = entropy_to_confidence(&certain);
        let conf_uncertain = entropy_to_confidence(&uncertain);

        assert!(conf_certain > 0.9);
        assert!(conf_uncertain < 0.1);
    }

    #[test]
    fn test_is_confident() {
        let probs = vec![0.9, 0.05, 0.05];
        // entropy ≈ 0.569, normalized ≈ 0.359, confidence ≈ 0.641
        assert!(is_confident(&probs, 0.6));
        assert!(!is_confident(&probs, 0.7));
    }

    #[test]
    fn test_perplexity() {
        let certain = vec![1.0, 0.0];
        let uniform = vec![0.25, 0.25, 0.25, 0.25];

        let ppl_certain = perplexity(&certain);
        let ppl_uniform = perplexity(&uniform);

        assert!((ppl_certain - 1.0).abs() < 0.01); // 2^0 = 1
        assert!((ppl_uniform - 4.0).abs() < 0.01); // 2^2 = 4
    }
}
