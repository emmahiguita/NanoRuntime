//! Tipos compartidos del memory engine.
//!
//! Tipos puros sin lógica de sistema, usados por componentes activos y por
//! módulos gateados tras `feature = "unstable"`. Separados de sus archivos de
//! origen (gguf_layout, policy_engine) para que los consumidores vivos no
//! dependan de módulos dormidos (ISP: depender del tipo, no del módulo).

use std::fmt;

/// Rango de bytes dentro del archivo del modelo.
///
/// Originalmente definido en `gguf_layout`; movido aquí porque
/// `CacheAwareLoader` (activo) lo usa sin necesitar el parser GGUF.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ByteRange {
    pub start: usize,
    pub end: usize,
}

impl ByteRange {
    pub fn len(&self) -> usize {
        self.end.saturating_sub(self.start)
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }
}

/// Quality of Service mode.
///
/// Originalmente definido en `policy_engine`; movido aquí porque el
/// orchestrator lo usa para auto_detect_qos sin necesitar el optimizador.
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum QosMode {
    Eco,
    Balanced,
    Performance,
}

impl fmt::Display for QosMode {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            QosMode::Eco => write!(f, "Eco"),
            QosMode::Balanced => write!(f, "Balanced"),
            QosMode::Performance => write!(f, "Performance"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_byte_range_math() {
        let r = ByteRange {
            start: 100,
            end: 200,
        };
        assert_eq!(r.len(), 100);
        assert!(!r.is_empty());
        let empty = ByteRange {
            start: 100,
            end: 100,
        };
        assert!(empty.is_empty());
    }

    #[test]
    fn test_qos_display() {
        assert_eq!(QosMode::Eco.to_string(), "Eco");
        assert_eq!(QosMode::Balanced.to_string(), "Balanced");
        assert_eq!(QosMode::Performance.to_string(), "Performance");
    }
}
