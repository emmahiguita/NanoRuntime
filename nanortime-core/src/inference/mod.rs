//! Capa de inferencia — puente FFI con llama.cpp.
//!
//! Proporciona la interfaz entre Rust y el motor de inferencia C++
//! para generación de tokens, streaming, y generación con gramática
//! restrictiva (útil para forzar JSON válido en tool calls).

pub mod grammar;
pub mod research;
pub mod token_stream;

pub use research::hallucination_detector::{
    HallucinationDetector, HallucinationSignal, HallucinationType,
    CorrectionStrategy, analyze_token,
};
