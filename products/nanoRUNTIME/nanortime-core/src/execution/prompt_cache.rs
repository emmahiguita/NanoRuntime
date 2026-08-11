//! Caché de prompts — evita regenerar respuestas idénticas.
//!
//! Cachea respuestas generadas localmente usando una política LRU.
//! La caché se salta cuando hay herramientas registradas (el resultado
//! podría cambiar) o cuando el modo edge-only fuerza generación fresca.

use std::collections::{HashMap, VecDeque};

/// Entrada en la caché de prompts.
#[derive(Debug, Clone)]
struct CacheEntry {
    /// Texto generado.
    text: String,
    /// Probabilidades por token (para cálculo de confianza).
    probabilities: Vec<f32>,
}

/// Caché LRU de prompts con tamaño máximo configurable.
///
/// Almacena pares (prompt → respuesta generada) para evitar
/// reprocesar consultas idénticas. Útil cuando el usuario repite
/// preguntas o cuando RAG devuelve los mismos documentos.
pub struct PromptCache {
    /// Almacenamiento interno: prompt hash → entrada.
    entries: HashMap<u64, CacheEntry>,
    /// Orden de acceso para LRU (front = más reciente, back = más antiguo).
    order: VecDeque<u64>,
    /// Capacidad máxima de la caché.
    capacity: usize,
    /// Si la caché está habilitada.
    enabled: bool,
}

impl PromptCache {
    /// Crea una nueva caché de prompts.
    ///
    /// `capacity`: número máximo de entradas (0 = sin caché).
    pub fn new(capacity: usize) -> Self {
        Self {
            entries: HashMap::with_capacity(capacity),
            order: VecDeque::with_capacity(capacity),
            capacity,
            enabled: capacity > 0,
        }
    }

    /// Intenta recuperar una respuesta cacheada.
    ///
    /// Retorna `Some((text, probabilities))` si hay un hit,
    /// o `None` si es miss.
    pub fn get(&mut self, prompt: &str) -> Option<(String, Vec<f32>)> {
        if !self.enabled {
            return None;
        }

        let hash = self.hash(prompt);
        // Clone the entry data first, then update LRU order
        let result = self
            .entries
            .get(&hash)
            .map(|entry| (entry.text.clone(), entry.probabilities.clone()));
        if result.is_some() {
            // Move to front (most recent) — separate from the immutable borrow above
            self.move_to_front(hash);
            tracing::trace!("Prompt cache HIT ({} entries)", self.entries.len());
        } else {
            tracing::trace!("Prompt cache MISS ({} entries)", self.entries.len());
        }
        result
    }

    /// Almacena una respuesta en la caché.
    ///
    /// Si la caché está llena, elimina la entrada más antigua (LRU).
    pub fn put(&mut self, prompt: &str, text: String, probabilities: Vec<f32>) {
        if !self.enabled {
            return;
        }

        let hash = self.hash(prompt);

        // If key already exists, update and move to front
        if let Some(entry) = self.entries.get_mut(&hash) {
            entry.text = text;
            entry.probabilities = probabilities;
            self.move_to_front(hash);
            return;
        }

        // Evict LRU if at capacity
        if self.entries.len() >= self.capacity {
            if let Some(oldest) = self.order.pop_back() {
                self.entries.remove(&oldest);
            }
        }

        // Insert new entry
        self.entries.insert(
            hash,
            CacheEntry {
                text,
                probabilities,
            },
        );
        self.order.push_front(hash);

        tracing::trace!("Prompt cache PUT ({} entries)", self.entries.len());
    }

    /// Invalida una entrada específica.
    pub fn invalidate(&mut self, prompt: &str) {
        let hash = self.hash(prompt);
        self.entries.remove(&hash);
        self.order.retain(|&h| h != hash);
    }

    /// Limpia toda la caché.
    pub fn clear(&mut self) {
        self.entries.clear();
        self.order.clear();
        tracing::info!("Prompt cache cleared");
    }

    /// Número de entradas en caché.
    pub fn len(&self) -> usize {
        self.entries.len()
    }

    /// Si la caché está vacía.
    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }

    /// Capacidad máxima de la caché.
    pub fn capacity(&self) -> usize {
        self.capacity
    }

    /// Habilita o deshabilita la caché.
    pub fn set_enabled(&mut self, enabled: bool) {
        if !enabled {
            self.clear();
        }
        self.enabled = enabled;
    }

    /// Hash simple para el prompt (evita almacenar strings largos como clave).
    fn hash(&self, prompt: &str) -> u64 {
        use std::hash::{Hash, Hasher};
        let mut hasher = std::collections::hash_map::DefaultHasher::new();
        prompt.hash(&mut hasher);
        hasher.finish()
    }

    /// Mueve una entrada al frente (más reciente).
    fn move_to_front(&mut self, hash: u64) {
        if let Some(pos) = self.order.iter().position(|&h| h == hash) {
            self.order.remove(pos);
            self.order.push_front(hash);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cache_hit() {
        let mut cache = PromptCache::new(10);
        cache.put("Hello", "Hi there!".into(), vec![0.9, 0.8]);
        let result = cache.get("Hello");
        assert!(result.is_some());
        assert_eq!(result.unwrap().0, "Hi there!");
    }

    #[test]
    fn test_cache_miss() {
        let mut cache = PromptCache::new(10);
        assert!(cache.get("unknown").is_none());
    }

    #[test]
    fn test_cache_eviction() {
        let mut cache = PromptCache::new(2);
        cache.put("A", "a".into(), vec![]);
        cache.put("B", "b".into(), vec![]);
        cache.put("C", "c".into(), vec![]); // Should evict "A"
        assert!(cache.get("A").is_none());
        assert!(cache.get("B").is_some());
        assert!(cache.get("C").is_some());
    }

    #[test]
    fn test_cache_disabled() {
        let mut cache = PromptCache::new(0);
        cache.put("Hello", "Hi".into(), vec![]);
        assert!(cache.get("Hello").is_none());
        assert!(cache.is_empty());
    }

    #[test]
    fn test_cache_clear() {
        let mut cache = PromptCache::new(10);
        cache.put("A", "a".into(), vec![]);
        cache.put("B", "b".into(), vec![]);
        assert_eq!(cache.len(), 2);
        cache.clear();
        assert!(cache.is_empty());
    }

    #[test]
    fn test_cache_recently_used() {
        let mut cache = PromptCache::new(3);
        cache.put("A", "a".into(), vec![]);
        cache.put("B", "b".into(), vec![]);
        cache.put("C", "c".into(), vec![]);
        // Access A, making it recent
        cache.get("A");
        // Now eviction should remove B (oldest accessed)
        cache.put("D", "d".into(), vec![]);
        assert!(
            cache.get("A").is_some(),
            "A was recently used, should survive"
        );
        assert!(cache.get("B").is_none(), "B was oldest, should be evicted");
        assert!(cache.get("C").is_some());
        assert!(cache.get("D").is_some());
    }
}
