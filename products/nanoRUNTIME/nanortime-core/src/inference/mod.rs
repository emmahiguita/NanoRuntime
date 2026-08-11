//! Capa de inferencia — puente FFI con llama.cpp.
//!
//! Proporciona la interfaz entre Rust y el motor de inferencia C++
//! para generación de tokens, streaming, y generación con gramática
//! restrictiva (útil para forzar JSON válido en tool calls).

pub mod grammar;
pub mod research;
pub mod token_stream;

pub use research::hallucination_detector::{
    analyze_token, CorrectionStrategy, HallucinationDetector, HallucinationSignal,
    HallucinationType,
};

// ── InferenceBackend trait (DIP) ──
// The trait is defined but the impl for llama.cpp lives in a separate PR.
// When ready, add: pub mod backend; pub use backend::*;
// This breaks the direct nanortime-core → nanortime-ffi coupling required
// by SOLID's Dependency Inversion Principle.
