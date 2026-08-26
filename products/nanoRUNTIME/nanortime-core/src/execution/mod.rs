//! Capa de ejecución — modelos, memoria, herramientas y vectores.
//!
//! Contiene los componentes que interactúan directamente con recursos
//! del sistema: carga de modelos, gestión de KV-cache, ejecución de
//! herramientas HTTP/script, y búsqueda vectorial con LanceDB.

pub mod lan_executor;
pub mod memory_manager;
pub mod model_manager;
pub mod prefix_cache;
pub mod prompt_cache;
pub mod rate_limiter;
pub mod session;
pub mod tool_executor;
pub mod vector_engine;

pub use lan_executor::LanExecutor;
pub use memory_manager::MemoryManager;
pub use model_manager::ModelManager;
pub use prefix_cache::{content_hash, PrefixCache, PrefixKey, PrefixLookup, STATE_VERSION};
pub use prompt_cache::PromptCache;
pub use rate_limiter::RateLimiter;
pub use session::{template_hash, NanoSession, SessionState};
pub use tool_executor::ToolExecutor;
pub use vector_engine::VectorEngine;
