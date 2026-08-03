//! Limitador de tasa (Rate Limiter) — token bucket algorithm.
//!
//! Protege los tiers cloud y LAN contra uso excesivo,
//! permitiendo picos cortos dentro de límites configurables.

use std::sync::Mutex;
use std::time::Instant;

/// Estado interno del token bucket.
struct BucketState {
    /// Capacidad máxima del bucket (tokens).
    capacity: f64,
    /// Tasa de relleno (tokens por segundo).
    refill_rate: f64,
    /// Tokens disponibles actualmente.
    tokens: f64,
    /// Última vez que se rellenaron tokens.
    last_refill: Instant,
}

/// Limitador de tasa basado en token bucket.
///
/// Permite `capacity` requests en ráfaga, luego se rellena
/// a razón de `refill_rate` tokens por segundo.
///
/// # Ejemplo
///
/// ```
/// use nanortime_core::execution::RateLimiter;
///
/// let limiter = RateLimiter::new(10.0, 1.0); // 10 requests burst, 1 per second refill
/// assert!(limiter.try_consume(1.0)); // Consume 1 token
/// assert!(limiter.try_consume(5.0)); // Consume 5 tokens
/// assert!(limiter.remaining() < 5.0); // At most ~4 remaining (minus tiny refill)
/// ```
pub struct RateLimiter {
    /// Estado interno protegido por mutex (incluye capacidad y tasa).
    state: Mutex<BucketState>,
}

impl RateLimiter {
    /// Crea un nuevo limitador de tasa.
    ///
    /// - `capacity`: número máximo de tokens (tamaño de ráfaga).
    /// - `refill_rate`: tokens por segundo que se añaden.
    ///
    /// Si ambos son 0.0, el limitador permite todas las requests (sin límite).
    pub fn new(capacity: f64, refill_rate: f64) -> Self {
        Self {
            state: Mutex::new(BucketState {
                capacity,
                refill_rate,
                tokens: capacity,
                last_refill: Instant::now(),
            }),
        }
    }

    /// Crea un limitador sin límite (permite todo).
    pub fn unlimited() -> Self {
        Self::new(0.0, 0.0)
    }

    /// Intenta consumir `tokens` del bucket.
    ///
    /// Retorna `true` si hay suficientes tokens y los consume.
    /// Retorna `false` si no hay suficientes (rate limit exceeded).
    pub fn try_consume(&self, tokens: f64) -> bool {
        if tokens <= 0.0 {
            return true;
        }

        let mut state = self.state.lock().unwrap();

        // Unlimited mode
        if state.capacity <= 0.0 && state.refill_rate <= 0.0 {
            return true;
        }

        // Blocked mode (capacity=0 with positive refill = no tokens ever unless via refill)
        // If capacity is 0 AND refill_rate is 0, it's unlimited (handled above).
        // If capacity is 0 but refill > 0, no initial tokens but can accumulate.
        if state.capacity <= 0.0 && state.refill_rate > 0.0 {
            state.last_refill = Instant::now();
            return false;
        }

        // Refill tokens based on elapsed time
        let now = Instant::now();
        let elapsed = now.duration_since(state.last_refill).as_secs_f64();
        if elapsed > 0.0 {
            state.tokens = (state.tokens + elapsed * state.refill_rate).min(state.capacity);
            state.last_refill = now;
        }

        // Try to consume
        if state.tokens >= tokens {
            state.tokens -= tokens;
            true
        } else {
            false
        }
    }

    /// Intenta consumir 1 token (un request completo).
    pub fn try_consume_one(&self) -> bool {
        self.try_consume(1.0)
    }

    /// Tokens restantes (valor aproximado).
    pub fn remaining(&self) -> f64 {
        let state = self.state.lock().unwrap();
        let now = Instant::now();
        let elapsed = now.duration_since(state.last_refill).as_secs_f64();
        if state.refill_rate > 0.0 {
            (state.tokens + elapsed * state.refill_rate).min(state.capacity)
        } else {
            state.tokens
        }
    }

    /// Resetea el bucket a capacidad máxima.
    pub fn reset(&self) {
        let mut state = self.state.lock().unwrap();
        state.tokens = state.capacity;
        state.last_refill = Instant::now();
    }

    /// Cambia los límites del bucket.
    pub fn reconfigure(&self, capacity: f64, refill_rate: f64) {
        let mut state = self.state.lock().unwrap();
        state.capacity = capacity;
        state.refill_rate = refill_rate;
        state.tokens = state.tokens.min(capacity);
    }
}

impl Clone for RateLimiter {
    fn clone(&self) -> Self {
        let state = self.state.lock().unwrap();
        Self {
            state: Mutex::new(BucketState {
                capacity: state.capacity,
                refill_rate: state.refill_rate,
                tokens: state.tokens,
                last_refill: state.last_refill,
            }),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::time::Duration;

    #[test]
    fn test_basic_rate_limit() {
        let limiter = RateLimiter::new(5.0, 10.0); // 5 tokens burst, 10/sec refill
        // Consume all 5
        for i in 0..5 {
            assert!(limiter.try_consume_one(), "Request {} should succeed", i);
        }
        // 6th should fail
        assert!(!limiter.try_consume_one(), "6th request should be rate limited");
    }

    #[test]
    fn test_unlimited() {
        let limiter = RateLimiter::unlimited();
        for _ in 0..100 {
            assert!(limiter.try_consume_one());
        }
    }

    #[test]
    fn test_refill() {
        let limiter = RateLimiter::new(1.0, 1000.0); // 1 token, fast refill (1000/sec)
        assert!(limiter.try_consume_one());
        assert!(!limiter.try_consume_one()); // No tokens left

        // Wait for refill
        std::thread::sleep(Duration::from_millis(50));
        // Should have at least some tokens (1000/sec * 0.05s = 50 tokens, capped at 1)
        assert!(limiter.try_consume_one(), "Should have refilled after 50ms");
    }

    #[test]
    fn test_remaining() {
        let limiter = RateLimiter::new(10.0, 1.0);
        assert!((limiter.remaining() - 10.0).abs() < 0.1);
        limiter.try_consume(3.0);
        assert!((limiter.remaining() - 7.0).abs() < 0.1);
    }

    #[test]
    fn test_reset() {
        let limiter = RateLimiter::new(5.0, 1.0);
        limiter.try_consume(3.0);
        limiter.reset();
        assert!((limiter.remaining() - 5.0).abs() < 0.1);
    }

    #[test]
    fn test_consume_partial() {
        let limiter = RateLimiter::new(10.0, 1.0);
        assert!(limiter.try_consume(7.0));
        assert!(limiter.try_consume(3.0));
        assert!(!limiter.try_consume(1.0)); // Empty
    }
}
