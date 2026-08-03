//! Módulo de configuración del runtime.
//!
//! Maneja la carga y validación del archivo `nano.manifest.json`
//! y las definiciones de herramientas.

pub mod manifest;
pub mod tools;

pub use manifest::Config;
pub use tools::ToolConfig;
