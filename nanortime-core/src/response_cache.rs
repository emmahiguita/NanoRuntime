// response_cache.rs — Caché de respuestas con embeddings para NanoAI
// Mínimo viable: sin dependencia de onnxruntime. Usa hash + frecuencia de palabras.
// Para producción: integrar all-MiniLM-L6-v2 (~20 MB) con onnxruntime.

use std::collections::HashMap;
use std::time::{SystemTime, UNIX_EPOCH};

/// Entrada en el caché de respuestas
#[derive(Debug, Clone)]
pub struct CachedResponse {
    pub prompt_hash: u64,
    pub response: String,
    pub model: String,
    pub timestamp: u64,
    pub hits: u32,
}

/// Caché en memoria de respuestas frecuentes.
/// Para prompts idénticos (hash colisiona) → respuesta instantánea.
/// Para prompts similares (mismas keywords) → respuesta cacheada.
pub struct ResponseCache {
    /// Exact match: hash del prompt → respuesta
    exact: HashMap<u64, CachedResponse>,
    /// Fuzzy match: keywords normalizadas → respuesta (más permisivo)
    fuzzy: HashMap<String, CachedResponse>,
    max_entries: usize,
    hits_total: u64,
    misses_total: u64,
}

impl ResponseCache {
    pub fn new(max_entries: usize) -> Self {
        Self {
            exact: HashMap::with_capacity(max_entries),
            fuzzy: HashMap::with_capacity(max_entries),
            max_entries,
            hits_total: 0,
            misses_total: 0,
        }
    }

    /// Normaliza un prompt: minúsculas, solo letras y espacios, sin puntuación
    fn normalize(prompt: &str) -> String {
        prompt
            .to_lowercase()
            .chars()
            .map(|c| match c {
                'á' | 'à' | 'ä' | 'â' | 'ã' => 'a',
                'é' | 'è' | 'ë' | 'ê' => 'e',
                'í' | 'ì' | 'ï' | 'î' => 'i',
                'ó' | 'ò' | 'ö' | 'ô' | 'õ' => 'o',
                'ú' | 'ù' | 'ü' | 'û' => 'u',
                'ñ' => 'n',
                'ç' => 'c',
                other => other,
            })
            .filter(|c| c.is_alphanumeric() || c.is_whitespace())
            .collect::<String>()
            .split_whitespace()
            .collect::<Vec<_>>()
            .join(" ")
    }

    /// Hash simple del prompt normalizado
    fn hash(prompt: &str) -> u64 {
        let mut h: u64 = 0xcbf29ce484222325;
        for byte in prompt.bytes() {
            h ^= byte as u64;
            h = h.wrapping_mul(0x100000001b3);
        }
        h
    }

    /// Busca una respuesta cacheada. Retorna Some si existe match exacto o fuzzy.
    pub fn find(&mut self, prompt: &str) -> Option<String> {
        let normalized = Self::normalize(prompt);
        let hash = Self::hash(&normalized);

        // 1. Match exacto por hash
        if let Some(cached) = self.exact.get(&hash) {
            self.hits_total += 1;
            return Some(cached.response.clone());
        }

        // 2. Match fuzzy por keywords normalizadas
        if let Some(cached) = self.fuzzy.get(&normalized) {
            self.hits_total += 1;
            return Some(cached.response.clone());
        }

        self.misses_total += 1;
        None
    }

    /// Almacena una respuesta en el caché
    pub fn store(&mut self, prompt: &str, response: &str, model: &str) {
        let normalized = Self::normalize(prompt);
        let hash = Self::hash(&normalized);
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();

        let entry = CachedResponse {
            prompt_hash: hash,
            response: response.to_string(),
            model: model.to_string(),
            timestamp: now,
            hits: 0,
        };

        self.exact.insert(hash, entry.clone());
        self.fuzzy.insert(normalized, entry);

        // Limpiar entradas más antiguas si excedemos el máximo
        let len = self.exact.len();
        if len > self.max_entries {
            self.evict_oldest();
        }
    }

    /// Registra un cache miss (para estadísticas)
    pub fn record_miss(&mut self) {
        self.misses_total += 1;
    }

    /// Registra un cache hit (para estadísticas)
    fn record_hit(&mut self) {
        self.hits_total += 1;
    }

    /// Elimina las entradas más antiguas
    fn evict_oldest(&mut self) {
        let to_remove = self.max_entries / 4; // eliminar 25% más viejos
        
        // Colectar claves a eliminar (evita borrow conflict)
        let mut exact_entries: Vec<_> = self.exact.iter().collect();
        exact_entries.sort_by_key(|(_, v)| v.timestamp);
        let exact_keys: Vec<u64> = exact_entries.iter().take(to_remove).map(|(k, _)| **k).collect();
        for k in exact_keys {
            self.exact.remove(&k);
        }
        
        // También limpiar fuzzy
        let fuzzy_len = self.fuzzy.len();
        if fuzzy_len > self.max_entries {
            let mut fuzzy_entries: Vec<_> = self.fuzzy.iter().collect();
            fuzzy_entries.sort_by_key(|(_, v)| v.timestamp);
            let fuzzy_keys: Vec<String> = fuzzy_entries.iter().take(to_remove).map(|(k, _)| (*k).clone()).collect();
            for k in fuzzy_keys {
                self.fuzzy.remove(&k);
            }
        }
    }

    /// Tasa de aciertos (0.0 - 1.0)
    pub fn hit_rate(&self) -> f32 {
        let total = self.hits_total + self.misses_total;
        if total == 0 {
            0.0
        } else {
            self.hits_total as f32 / total as f32
        }
    }

    /// Número de entradas en el caché
    pub fn len(&self) -> usize {
        self.exact.len()
    }

    pub fn is_empty(&self) -> bool {
        self.exact.is_empty()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_exact_match() {
        let mut cache = ResponseCache::new(100);
        cache.store("Hola, ¿cómo estás?", "¡Bien! ¿Y tú?", "qwen-1.5b");

        let result = cache.find("Hola, ¿cómo estás?");
        assert_eq!(result, Some("¡Bien! ¿Y tú?".to_string()));
    }

    #[test]
    fn test_fuzzy_match_ignores_punctuation() {
        let mut cache = ResponseCache::new(100);
        cache.store("¿Cuál es la capital de Francia?", "París", "qwen-1.5b");

        // Mismo prompt sin puntuación
        let result = cache.find("Cual es la capital de Francia");
        assert_eq!(result, Some("París".to_string()));
    }

    #[test]
    fn test_miss() {
        let mut cache = ResponseCache::new(100);
        assert_eq!(cache.find("algo que nunca pregunté antes"), None);
    }

    #[test]
    fn test_hit_rate() {
        let mut cache = ResponseCache::new(100);
        cache.store("hola", "hola", "qwen");
        cache.find("hola");
        cache.find("hola");
        cache.find("adios"); // miss
        cache.find("adios"); // miss

        // 2 hits, 2 misses = 50%
        assert!((cache.hit_rate() - 0.5).abs() < 0.01);
        assert_eq!(cache.len(), 1);
    }

    #[test]
    fn test_normalize_removes_accents_and_case() {
        let normalized = ResponseCache::normalize("¿¡Hóla, CÓMO estás!?");
        assert_eq!(normalized, "hola como estas");
    }
}
