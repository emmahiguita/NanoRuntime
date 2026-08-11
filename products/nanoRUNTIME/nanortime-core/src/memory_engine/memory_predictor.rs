//! Memory Predictor — predice qué capas del modelo se necesitarán próximamente.
//!
//! Implementación v1 heurística basada en ventana deslizante de scores de atención.
//! v2 usará un modelo tiny de 5-10M params entrenado con datos de sesiones reales.

use std::collections::VecDeque;

/// Patrón de atención observado en un token.
#[derive(Debug, Clone)]
pub struct AttentionPattern {
    /// Capas con alta atención en este token.
    pub hot_layers: Vec<usize>,
    /// Posición en la secuencia de tokens.
    pub token_position: usize,
}

/// Predictor de uso de capas basado en historial de atención.
pub struct MemoryPredictor {
    /// Ventana deslizante de scores de atención por capa, últimos N tokens.
    /// `lookback_window[i]` = vector de scores para el token i-ésimo más reciente.
    lookback_window: VecDeque<Vec<f32>>,
    /// Tamaño de la ventana de análisis.
    lookback: usize,
    /// Umbral de score de atención para considerar una capa "caliente".
    hot_threshold: f32,
    /// Contador de tokens procesados.
    token_count: usize,
}

impl MemoryPredictor {
    /// Crea un nuevo predictor.
    ///
    /// `lookback`: cuántos tokens pasados analizar para la predicción.
    pub fn new(lookback: usize) -> Self {
        Self {
            lookback_window: VecDeque::with_capacity(lookback.max(1)),
            lookback: lookback.max(1),
            hot_threshold: 0.65, // Capas con score > 65% se consideran activas
            token_count: 0,
        }
    }

    /// Alimenta los scores de atención del token actual a la ventana.
    ///
    /// Llamar una vez por token generado.
    pub fn feed(&mut self, scores: &[f32]) {
        if self.lookback_window.len() >= self.lookback {
            self.lookback_window.pop_front();
        }
        self.lookback_window.push_back(scores.to_vec());
        self.token_count += 1;
    }

    /// Predice qué capas se necesitarán en los próximos `lookahead` tokens.
    ///
    /// Retorna IDs de capas que probablemente serán necesarias.
    pub fn predict(&mut self, attention_scores: &[f32], lookahead: usize) -> Vec<usize> {
        // Primero ingerir el token actual
        self.feed(attention_scores);

        if self.lookback_window.is_empty() {
            return Vec::new();
        }

        let n_layers = attention_scores.len();
        if n_layers == 0 {
            return Vec::new();
        }

        // Algoritmo v1:
        // 1. Calcular promedio de atención por capa en la ventana completa
        let avg_scores = self.compute_window_averages(n_layers);

        // 2. Detectar capas consistentemente activas (avg > threshold)
        let mut hot_layers: Vec<usize> = avg_scores
            .iter()
            .enumerate()
            .filter(|(_, &score)| score > self.hot_threshold)
            .map(|(id, _)| id)
            .collect();

        // 3. Detectar capas con tendencia creciente (últimos 3 tokens)
        let trending = self.detect_trending_layers(n_layers);
        for layer_id in trending {
            if !hot_layers.contains(&layer_id) {
                hot_layers.push(layer_id);
            }
        }

        // 4. Con lookahead, ampliar a capas vecinas de las hot (localidad espacial)
        if lookahead > 1 {
            let mut extended = hot_layers.clone();
            for &id in &hot_layers {
                if id > 0 && !extended.contains(&(id - 1)) {
                    extended.push(id - 1);
                }
                if id + 1 < n_layers && !extended.contains(&(id + 1)) {
                    extended.push(id + 1);
                }
            }
            hot_layers = extended;
        }

        hot_layers.sort_unstable();
        tracing::trace!(
            "MemoryPredictor: {} layers predicted hot (lookahead={}, window={})",
            hot_layers.len(),
            lookahead,
            self.lookback_window.len()
        );

        hot_layers
    }

    /// Retorna el patrón de atención actual (capas con score > threshold).
    pub fn current_pattern(&self) -> Option<AttentionPattern> {
        let latest = self.lookback_window.back()?;
        let hot_layers = latest
            .iter()
            .enumerate()
            .filter(|(_, &s)| s > self.hot_threshold)
            .map(|(id, _)| id)
            .collect();
        Some(AttentionPattern {
            hot_layers,
            token_position: self.token_count,
        })
    }

    /// Número de tokens procesados.
    pub fn token_count(&self) -> usize {
        self.token_count
    }

    /// Resetea el historial de la ventana.
    pub fn reset(&mut self) {
        self.lookback_window.clear();
        self.token_count = 0;
    }

    /// Calcula el promedio de atención por capa sobre toda la ventana.
    fn compute_window_averages(&self, n_layers: usize) -> Vec<f32> {
        if self.lookback_window.is_empty() {
            return vec![0.0; n_layers];
        }

        let mut sums = vec![0.0f32; n_layers];
        let mut counts = vec![0u32; n_layers];

        for token_scores in &self.lookback_window {
            for (layer_id, &score) in token_scores.iter().enumerate() {
                if layer_id < n_layers {
                    sums[layer_id] += score;
                    counts[layer_id] += 1;
                }
            }
        }

        sums.iter()
            .zip(counts.iter())
            .map(|(&sum, &count)| if count > 0 { sum / count as f32 } else { 0.0 })
            .collect()
    }

    /// Detecta capas con score de atención creciente en los últimos 3 tokens.
    fn detect_trending_layers(&self, n_layers: usize) -> Vec<usize> {
        let window_len = self.lookback_window.len();
        if window_len < 3 {
            return Vec::new();
        }

        let recent: Vec<&Vec<f32>> = self.lookback_window.iter().rev().take(3).collect();

        let mut trending = Vec::new();
        for layer_id in 0..n_layers {
            let s0 = recent
                .get(2)
                .and_then(|v| v.get(layer_id))
                .copied()
                .unwrap_or(0.0);
            let s1 = recent
                .get(1)
                .and_then(|v| v.get(layer_id))
                .copied()
                .unwrap_or(0.0);
            let s2 = recent
                .first()
                .and_then(|v| v.get(layer_id))
                .copied()
                .unwrap_or(0.0);

            // Tendencia creciente: s0 < s1 < s2 con incremento significativo
            if s2 > s1 && s1 > s0 && (s2 - s0) > 0.15 {
                trending.push(layer_id);
            }
        }

        trending
    }
}

/// Estadísticas del predictor para benchmarking.
#[derive(Debug, Clone)]
pub struct PredictorStats {
    /// Número de tokens procesados.
    pub tokens_processed: usize,
    /// Promedio de capas predichas por token.
    pub avg_predicted_layers: f32,
    /// Tamaño actual de la ventana.
    pub window_size: usize,
}

impl MemoryPredictor {
    /// Retorna estadísticas del predictor.
    pub fn stats(&self) -> PredictorStats {
        PredictorStats {
            tokens_processed: self.token_count,
            avg_predicted_layers: 0.0, // Calculable con historial adicional
            window_size: self.lookback_window.len(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_predictor_new() {
        let p = MemoryPredictor::new(10);
        assert_eq!(p.lookback, 10);
        assert_eq!(p.token_count, 0);
    }

    #[test]
    fn test_feed_respects_window_size() {
        let mut p = MemoryPredictor::new(5);
        for i in 0..10 {
            p.feed(&vec![i as f32 / 10.0; 8]);
        }
        assert_eq!(p.lookback_window.len(), 5); // Bounded by lookback
        assert_eq!(p.token_count, 10);
    }

    #[test]
    fn test_predict_returns_hot_layers() {
        let mut p = MemoryPredictor::new(5);
        // Feed several tokens with layer 3 and 7 consistently hot
        for _ in 0..5 {
            let mut scores = vec![0.1f32; 8];
            scores[3] = 0.9; // Layer 3 hot
            scores[7] = 0.85; // Layer 7 hot
            p.feed(&scores);
        }
        let mut scores = vec![0.1f32; 8];
        scores[3] = 0.9;
        scores[7] = 0.85;
        let predicted = p.predict(&scores, 1);
        assert!(predicted.contains(&3), "Layer 3 should be predicted hot");
        assert!(predicted.contains(&7), "Layer 7 should be predicted hot");
    }

    #[test]
    fn test_predict_empty_returns_empty() {
        let mut p = MemoryPredictor::new(5);
        let predicted = p.predict(&[], 1);
        assert!(predicted.is_empty());
    }

    #[test]
    fn test_predict_with_lookahead_expands_neighbors() {
        let mut p = MemoryPredictor::new(5);
        // Only layer 5 is hot
        for _ in 0..5 {
            let mut scores = vec![0.1f32; 10];
            scores[5] = 0.9;
            p.feed(&scores);
        }
        let mut scores = vec![0.1f32; 10];
        scores[5] = 0.9;
        let predicted = p.predict(&scores, 2);
        // With lookahead > 1, layer 4 and 6 should also be included
        assert!(
            predicted.contains(&4) || predicted.contains(&6),
            "Neighbors of hot layer should be predicted with lookahead > 1"
        );
    }

    #[test]
    fn test_trending_detection() {
        let mut p = MemoryPredictor::new(10);
        // Gradually increasing scores for layer 2
        p.feed(&[0.1, 0.1, 0.2, 0.1, 0.1]);
        p.feed(&[0.1, 0.1, 0.5, 0.1, 0.1]);
        p.feed(&[0.1, 0.1, 0.8, 0.1, 0.1]);

        let trending = p.detect_trending_layers(5);
        assert!(
            trending.contains(&2),
            "Rapidly increasing layer should be detected as trending"
        );
    }

    #[test]
    fn test_reset_clears_state() {
        let mut p = MemoryPredictor::new(5);
        for _ in 0..5 {
            p.feed(&vec![0.5; 8]);
        }
        assert!(p.token_count > 0);
        p.reset();
        assert_eq!(p.token_count, 0);
        assert!(p.lookback_window.is_empty());
    }

    #[test]
    fn test_current_pattern_none_on_empty() {
        let p = MemoryPredictor::new(5);
        assert!(p.current_pattern().is_none());
    }

    #[test]
    fn test_current_pattern_detects_hot() {
        let mut p = MemoryPredictor::new(5);
        let mut scores = vec![0.1f32; 8];
        scores[4] = 0.9;
        p.feed(&scores);
        let pattern = p.current_pattern().unwrap();
        assert!(pattern.hot_layers.contains(&4));
    }
}
