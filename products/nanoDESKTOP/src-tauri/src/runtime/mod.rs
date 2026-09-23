//! Módulo de integración de Runtime para NanoAI Desktop.
//!
//! Proporciona el supervisor de ciclo de vida y el servicio de aplicación
//! desacoplado para coordinar la inferencia nativa con nanortime-core.

pub mod service;
pub mod supervisor;

pub use service::RuntimeService;
pub use supervisor::RuntimeSupervisor;
