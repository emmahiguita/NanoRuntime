//! KV Cache Optimizer — compresión y evicción inteligente del KV cache.
//!
//! Calcula la importancia de cada token en el KV cache y decide
//! si mantenerlo, eviccionarlo o comprimirlo para liberar memoria.

/// Nivel de compresión para el KV cache.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub enum CompressionLevel {
    /// Sin compresión — precisión completa FP16.
    None,
    /// Cuantización a INT8 — ~2x reducción, <0.5% pérdida de calidad.
    Int8,
    /// Cuantización a INT4 — ~4x reducción, ~1% pérdida de calidad.
    Int4,
    /// Cuantización a INT2 — ~8x reducción, >2% pérdida de calidad.
    Int2,
}

impl CompressionLevel {
    /// Factor de reducción de memoria por nivel.
    pub fn compression_ratio(&self) -> f32 {
        match self {
            CompressionLevel::None => 1.0,
            CompressionLevel::Int8 => 2.0,
            CompressionLevel::Int4 => 4.0,
            CompressionLevel::Int2 => 8.0,
        }
    }

    /// Pérdida de calidad estimada por nivel (porcentaje).
    pub fn quality_loss_pct(&self) -> f32 {
        match self {
            CompressionLevel::None => 0.0,
            CompressionLevel::Int8 => 0.3,
            CompressionLevel::Int4 => 1.0,
            CompressionLevel::Int2 => 2.5,
        }
    }
}

/// Importancia de un token en el KV cache.
#[derive(Debug, Clone)]
pub struct TokenImportance {
    /// Índice del token en la secuencia.
    pub token_id: usize,
    /// Score de atención recibida por este token.
    pub attention_score: f32,
    /// Recencia (1.0 = token más reciente, 0.0 = token más antiguo).
    pub recency: f32,
    /// Unicidad del token (0.0 = muy similar a otros, 1.0 = único).
    pub uniqueness: f32,
}

/// Acción a tomar sobre un token en el KV cache.
#[derive(Debug, Clone, PartialEq)]
pub enum KvAction {
    /// Mantener en cache con precisión completa.
    Keep,
    /// Eliminar del cache (puede recalcularse si es necesario).
    Evict,
    /// Comprimir a nivel especificado.
    Compress(CompressionLevel),
}

/// Optimizador de KV cache con evicción inteligente y compresión cuantizada.
pub struct KvCacheOptimizer {
    /// Tamaño objetivo del cache en bytes.
    target_size: usize,
    /// Nivel de compresión por defecto para tokens candidatos.
    compression_level: CompressionLevel,
    /// Umbral mínimo de importancia para mantener un token.
    eviction_threshold: f32,
    /// Número de tokens recientes siempre protegidos de evicción.
    protected_recent: usize,
}

impl KvCacheOptimizer {
    /// Crea un nuevo optimizador.
    ///
    /// `target_mb`: tamaño objetivo del cache en MB.
    /// `strategy`: "aggressive" | "balanced" | "conservative".
    pub fn new(target_mb: f64, strategy: &str) -> Self {
        let target_size = (target_mb * 1024.0 * 1024.0) as usize;

        let (compression_level, eviction_threshold, protected_recent) = match strategy {
            "aggressive" => (CompressionLevel::Int4, 0.35, 8),
            "conservative" => (CompressionLevel::Int8, 0.20, 32),
            _ => (CompressionLevel::Int8, 0.25, 16), // balanced
        };

        Self {
            target_size,
            compression_level,
            eviction_threshold,
            protected_recent,
        }
    }

    /// Calcula el score de importancia de un token.
    ///
    /// Fórmula: attention_score × recency × uniqueness
    pub fn calculate_importance(token: &TokenImportance) -> f32 {
        let score = token.attention_score.clamp(0.0, 1.0)
            * token.recency.clamp(0.0, 1.0)
            * token.uniqueness.clamp(0.0, 1.0);
        score.max(0.001) // Mínimo para evitar cero
    }

    /// Determina la acción óptima para cada token del KV cache.
    ///
    /// Retorna un Vec de (token_id, KvAction) ordenado por token_id.
    pub fn optimize(
        &self,
        tokens: &[TokenImportance],
        current_size: usize,
    ) -> Vec<(usize, KvAction)> {
        if tokens.is_empty() {
            return Vec::new();
        }

        // Si el cache cabe en el objetivo, no hacer nada
        if current_size <= self.target_size {
            return tokens
                .iter()
                .map(|t| (t.token_id, KvAction::Keep))
                .collect();
        }

        let n_tokens = tokens.len();
        let bytes_to_free = current_size.saturating_sub(self.target_size);
        let bytes_per_token = current_size.checked_div(n_tokens).unwrap_or(0);

        // Calcular importancia de cada token
        let mut ranked: Vec<(usize, f32, bool)> = tokens
            .iter()
            .enumerate()
            .map(|(idx, t)| {
                let importance = Self::calculate_importance(t);
                let is_recent = idx >= n_tokens.saturating_sub(self.protected_recent);
                (t.token_id, importance, is_recent)
            })
            .collect();

        // Ordenar por importancia (mayor primero para decisiones)
        ranked.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

        let mut actions = vec![KvAction::Keep; tokens.len()];
        let mut freed_bytes = 0usize;

        // Procesar desde menor importancia → mayor (invertir)
        for (ranked_idx, &(token_id, importance, is_recent)) in ranked.iter().rev().enumerate() {
            let token_idx = tokens
                .iter()
                .position(|t| t.token_id == token_id)
                .unwrap_or(ranked_idx);

            if is_recent {
                // Tokens recientes: nunca evictar, comprimir solo en emergencia
                if freed_bytes < bytes_to_free && importance < self.eviction_threshold * 0.5 {
                    actions[token_idx] = KvAction::Compress(CompressionLevel::Int8);
                    freed_bytes +=
                        bytes_per_token / CompressionLevel::Int8.compression_ratio() as usize;
                }
                continue;
            }

            if freed_bytes >= bytes_to_free {
                break; // Ya liberamos suficiente
            }

            if importance < self.eviction_threshold {
                // Importancia muy baja → evictar
                actions[token_idx] = KvAction::Evict;
                freed_bytes += bytes_per_token;
            } else if importance < self.eviction_threshold * 2.0 {
                // Importancia media → comprimir al nivel configurado
                actions[token_idx] = KvAction::Compress(self.compression_level);
                let saved = bytes_per_token
                    - (bytes_per_token as f32 / self.compression_level.compression_ratio())
                        as usize;
                freed_bytes += saved;
            }
            // Alta importancia → mantener (Keep)
        }

        // Reconstruir resultado asociado a token_id
        tokens
            .iter()
            .enumerate()
            .map(|(idx, t)| (t.token_id, actions[idx].clone()))
            .collect()
    }

    /// Comprime datos KV usando cuantización simulada.
    ///
    /// En producción real integraría con llama.cpp o bitsandbytes.
    pub fn compress_kv(kv_data: &[u8], level: CompressionLevel) -> Vec<u8> {
        match level {
            CompressionLevel::None => kv_data.to_vec(),
            CompressionLevel::Int8 => {
                // Simular reducción ~2x: tomar cada dos bytes y promediarlos
                kv_data
                    .chunks(2)
                    .map(|chunk| {
                        if chunk.len() == 2 {
                            ((chunk[0] as u16 + chunk[1] as u16) / 2) as u8
                        } else {
                            chunk[0]
                        }
                    })
                    .collect()
            }
            CompressionLevel::Int4 => {
                // Simular reducción ~4x: tomar cada cuatro bytes
                kv_data
                    .chunks(4)
                    .map(|chunk| chunk[0]) // Solo primer byte por simplificación
                    .collect()
            }
            CompressionLevel::Int2 => {
                // Simular reducción ~8x: tomar cada ocho bytes
                kv_data.chunks(8).map(|chunk| chunk[0]).collect()
            }
        }
    }

    /// Descomprime datos KV (expansión desde representación comprimida).
    pub fn decompress_kv(compressed: &[u8], level: CompressionLevel) -> Vec<u8> {
        match level {
            CompressionLevel::None => compressed.to_vec(),
            CompressionLevel::Int8 => {
                // Expandir ~2x: duplicar cada byte
                compressed.iter().flat_map(|&b| [b, b]).collect()
            }
            CompressionLevel::Int4 => {
                // Expandir ~4x: repetir cada byte 4 veces
                compressed.iter().flat_map(|&b| [b, b, b, b]).collect()
            }
            CompressionLevel::Int2 => {
                // Expandir ~8x: repetir cada byte 8 veces
                compressed.iter().flat_map(|&b| [b; 8]).collect()
            }
        }
    }

    /// Estima el ahorro de memoria al aplicar acciones de optimización.
    pub fn estimate_savings(actions: &[(usize, KvAction)], bytes_per_token: usize) -> usize {
        actions
            .iter()
            .map(|(_, action)| match action {
                KvAction::Keep => 0,
                KvAction::Evict => bytes_per_token,
                KvAction::Compress(level) => {
                    let compressed_size =
                        (bytes_per_token as f32 / level.compression_ratio()) as usize;
                    bytes_per_token.saturating_sub(compressed_size)
                }
            })
            .sum()
    }

    /// Retorna el nivel de compresión configurado.
    pub fn compression_level(&self) -> CompressionLevel {
        self.compression_level
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn make_token(id: usize, attention: f32, recency: f32, uniqueness: f32) -> TokenImportance {
        TokenImportance {
            token_id: id,
            attention_score: attention,
            recency,
            uniqueness,
        }
    }

    #[test]
    fn test_calculate_importance() {
        let t = make_token(0, 0.8, 0.9, 0.7);
        let score = KvCacheOptimizer::calculate_importance(&t);
        assert!((score - 0.504).abs() < 0.01, "0.8×0.9×0.7 = {}", score);
    }

    #[test]
    fn test_calculate_importance_zero_attention() {
        let t = make_token(0, 0.0, 1.0, 1.0);
        let score = KvCacheOptimizer::calculate_importance(&t);
        assert!(
            score > 0.0,
            "Score should be > 0 even with zero attention (min floor)"
        );
    }

    #[test]
    fn test_compression_ratio() {
        assert_eq!(CompressionLevel::None.compression_ratio(), 1.0);
        assert_eq!(CompressionLevel::Int8.compression_ratio(), 2.0);
        assert_eq!(CompressionLevel::Int4.compression_ratio(), 4.0);
        assert_eq!(CompressionLevel::Int2.compression_ratio(), 8.0);
    }

    #[test]
    fn test_optimize_no_action_when_under_budget() {
        let opt = KvCacheOptimizer::new(100.0, "balanced");
        let tokens = vec![make_token(0, 0.5, 0.5, 0.5), make_token(1, 0.3, 0.3, 0.3)];
        let actions = opt.optimize(&tokens, 100); // Under 100MB budget
        assert!(actions.iter().all(|(_, a)| *a == KvAction::Keep));
    }

    #[test]
    fn test_optimize_evicts_low_importance() {
        let opt = KvCacheOptimizer::new(0.001, "aggressive"); // Very small budget
        let tokens: Vec<TokenImportance> = (0..20)
            .map(|i| {
                make_token(i, 0.1, 0.1, 0.1) // All low importance
            })
            .collect();
        // 20 * 1000 bytes = 20KB, target ~1KB → lots to free
        let actions = opt.optimize(&tokens, 20_000);
        let evicted = actions
            .iter()
            .filter(|(_, a)| *a == KvAction::Evict)
            .count();
        assert!(evicted > 0, "Some tokens should be evicted");
    }

    #[test]
    fn test_optimize_protects_recent_tokens() {
        let opt = KvCacheOptimizer::new(0.001, "balanced"); // Tiny budget
        let tokens: Vec<TokenImportance> = (0..20)
            .map(|i| {
                let recency = i as f32 / 19.0;
                make_token(i, 0.1, recency, 0.1)
            })
            .collect();
        let actions = opt.optimize(&tokens, 20_000);
        // Recent tokens (last 16 by default) should not be evicted
        for i in 4..20 {
            // Last 16 tokens (index 4-19)
            let action = &actions.iter().find(|(id, _)| *id == i).unwrap().1;
            assert_ne!(
                action,
                &KvAction::Evict,
                "Recent token {} should not be evicted",
                i
            );
        }
    }

    #[test]
    fn test_compress_decompress_int8_size() {
        let data = vec![100u8; 1024];
        let compressed = KvCacheOptimizer::compress_kv(&data, CompressionLevel::Int8);
        assert_eq!(compressed.len(), data.len() / 2);
        let decompressed = KvCacheOptimizer::decompress_kv(&compressed, CompressionLevel::Int8);
        assert_eq!(decompressed.len(), compressed.len() * 2);
    }

    #[test]
    fn test_compress_decompress_none_passthrough() {
        let data = vec![42u8; 256];
        let compressed = KvCacheOptimizer::compress_kv(&data, CompressionLevel::None);
        assert_eq!(compressed, data);
    }

    #[test]
    fn test_estimate_savings() {
        let actions = vec![
            (0, KvAction::Evict),
            (1, KvAction::Keep),
            (2, KvAction::Compress(CompressionLevel::Int8)),
        ];
        let savings = KvCacheOptimizer::estimate_savings(&actions, 1000);
        // Evict: 1000 bytes + Compress INT8: 1000 - 500 = 500 bytes → total 1500
        assert_eq!(savings, 1500);
    }

    #[test]
    fn test_new_strategies() {
        let agg = KvCacheOptimizer::new(50.0, "aggressive");
        assert_eq!(agg.compression_level(), CompressionLevel::Int4);

        let cons = KvCacheOptimizer::new(50.0, "conservative");
        assert_eq!(cons.compression_level(), CompressionLevel::Int8);

        let bal = KvCacheOptimizer::new(50.0, "balanced");
        assert_eq!(bal.compression_level(), CompressionLevel::Int8);
    }
}
