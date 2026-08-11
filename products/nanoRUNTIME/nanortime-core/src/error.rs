//! Tipos de error del runtime NanoAI.
//!
//! Define la jerarquía de errores usando `thiserror` para errores
//! de dominio y `anyhow` para errores de aplicación.

use thiserror::Error;

/// Errores del dominio de NanoAI.
///
/// Cada variante representa una categoría de error distinta
/// con mensajes descriptivos y contexto relevante.
#[derive(Error, Debug)]
pub enum NanoError {
    /// El modelo especificado no existe en la ruta indicada.
    #[error("Model not found: {path}")]
    ModelNotFound { path: String },

    /// No hay suficiente memoria para cargar el modelo.
    #[error("Insufficient memory: required {required}MB, available {available}MB")]
    InsufficientMemory { required: usize, available: usize },

    /// Fallo al cargar el modelo desde disco.
    #[error("Failed to load model from {path}: {reason}")]
    ModelLoadFailed { path: String, reason: String },

    /// La ejecución de una herramienta falló.
    #[error("Tool execution failed: {tool_name}")]
    ToolExecutionFailed {
        tool_name: String,
        #[source]
        source: Box<dyn std::error::Error + Send + Sync>,
    },

    /// Herramienta no encontrada en el registro.
    #[error("Tool not found: {name}")]
    ToolNotFound { name: String },

    /// Error de parsing de la definición JSON de una herramienta.
    #[error("Invalid tool definition: {reason}")]
    InvalidToolDefinition { reason: String },

    /// Error en la configuración (archivo de manifiesto inválido).
    #[error("Configuration error: {reason}")]
    ConfigError { reason: String },

    /// Error de I/O al leer o escribir archivos.
    #[error("I/O error: {message}")]
    IoError {
        message: String,
        #[source]
        source: std::io::Error,
    },

    /// Error en la base de datos vectorial.
    #[error("Vector database error: {reason}")]
    VectorDbError { reason: String },

    /// Error en la capa de inferencia.
    #[error("Inference error: {reason}")]
    InferenceError { reason: String },

    /// Error en la comunicación HTTP (Tier 3 cloud).
    #[error("HTTP request failed: {reason}")]
    HttpError {
        reason: String,
        #[source]
        source: reqwest::Error,
    },

    /// Error de red (LAN, Ollama, etc.).
    #[error("Network error: {0}")]
    Network(String),

    /// Error de parsing (LAN responses, etc.).
    #[error("Parse error: {0}")]
    Parse(String),

    /// Error de serialización/deserialización JSON.
    #[error("Serialization error: {reason}")]
    SerializationError {
        reason: String,
        #[source]
        source: serde_json::Error,
    },

    /// Error interno inesperado.
    #[error("Internal error: {message}")]
    Internal { message: String },

    /// Timeout en una operación.
    #[error("Operation timed out: {operation}")]
    Timeout { operation: String },
}

impl From<std::io::Error> for NanoError {
    fn from(source: std::io::Error) -> Self {
        NanoError::IoError {
            message: source.to_string(),
            source,
        }
    }
}

impl From<reqwest::Error> for NanoError {
    fn from(source: reqwest::Error) -> Self {
        NanoError::HttpError {
            reason: source.to_string(),
            source,
        }
    }
}

impl From<serde_json::Error> for NanoError {
    fn from(source: serde_json::Error) -> Self {
        NanoError::SerializationError {
            reason: source.to_string(),
            source,
        }
    }
}

/// Tipo de resultado alias para operaciones que pueden fallar con NanoError.
pub type Result<T> = std::result::Result<T, NanoError>;
