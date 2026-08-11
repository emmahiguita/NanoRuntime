//! Configuración del manifiesto (`nano.manifest.json`).
//!
//! Define la estructura de configuración completa del runtime:
//! modelo local, routing híbrido, tiers, memoria y herramientas.

use serde::{Deserialize, Serialize};
use std::path::Path;

use crate::error::{NanoError, Result};

/// Configuración raíz cargada desde `nano.manifest.json`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    /// Versión del esquema de configuración.
    #[serde(default = "default_version")]
    pub version: String,

    /// Configuración del modelo local.
    pub local_model: LocalModelConfig,

    /// Configuración del routing híbrido.
    #[serde(default)]
    pub hybrid_routing: HybridRoutingConfig,

    /// Configuración de los tiers de inferencia.
    #[serde(default)]
    pub tiers: TiersConfig,

    /// Configuración de memoria y RAG.
    #[serde(default)]
    pub memory: MemoryConfig,

    /// Configuración de herramientas declarativas.
    #[serde(default)]
    pub tools: ToolsConfig,

    /// Configuración de logging.
    #[serde(default)]
    pub logging: LoggingConfig,

    /// Configuración de parámetros de generación.
    #[serde(default)]
    pub generation: GenerationConfig,
}

/// Configuración del modelo local (Tier 1).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LocalModelConfig {
    /// Ruta al archivo GGUF del modelo.
    pub path: String,

    /// Tamaño del contexto en tokens (default: 8192).
    #[serde(default = "default_context_size")]
    pub context_size: usize,

    /// Capas a offloadear a GPU (-1 = todas).
    #[serde(default = "default_gpu_layers")]
    pub gpu_layers: i32,

    /// Usar memory-mapped I/O para carga eficiente.
    #[serde(default = "default_true")]
    pub use_mmap: bool,

    /// Número de threads para inferencia en CPU.
    #[serde(default = "default_threads")]
    pub threads: usize,

    /// Tamaño del batch de procesamiento.
    #[serde(default = "default_batch_size")]
    pub batch_size: usize,
}

/// Configuración del routing híbrido.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HybridRoutingConfig {
    /// Activar routing híbrido (local → cloud).
    #[serde(default = "default_true")]
    pub enabled: bool,

    /// Umbral de confianza para aceptar respuesta local (0.0 - 1.0).
    #[serde(default = "default_confidence")]
    pub confidence_threshold: f32,

    /// Activar filtro de privacidad (detección de PII).
    #[serde(default = "default_true")]
    pub privacy_filter: bool,

    /// Solo usar inferencia local, desactivar tiers cloud/LAN.
    #[serde(default)]
    pub edge_only: bool,
}

/// Configuración de tiers de inferencia.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TiersConfig {
    /// Tier 1: inferencia local.
    #[serde(default)]
    pub tier1: Tier1Config,

    /// Tier 2: servidor local en LAN.
    #[serde(default)]
    pub tier2: Tier2Config,

    /// Tier 3: API cloud.
    #[serde(default)]
    pub tier3: Tier3Config,
}

/// Configuración de Tier 1 (local).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Tier1Config {
    pub provider: String,
    #[serde(default = "default_true")]
    pub enabled: bool,
}

impl Default for Tier1Config {
    fn default() -> Self {
        Self {
            provider: "local".to_string(),
            enabled: true,
        }
    }
}

/// Configuración de Tier 2 (LAN).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Tier2Config {
    pub provider: String,
    pub endpoint: String,
    #[serde(default)]
    pub enabled: bool,
}

impl Default for Tier2Config {
    fn default() -> Self {
        Self {
            provider: "local_server".to_string(),
            endpoint: "http://localhost:11434".to_string(),
            enabled: false,
        }
    }
}

/// Configuración de Tier 3 (cloud).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Tier3Config {
    /// Proveedor: "anthropic", "openai", o "custom".
    pub provider: String,

    /// ID del modelo en la API del proveedor.
    pub model: String,

    /// Nombre de la variable de entorno que contiene la API key.
    pub api_key_env: String,

    /// Si el tier está habilitado.
    #[serde(default)]
    pub enabled: bool,

    /// Máximo de tokens a generar en la nube.
    #[serde(default = "default_max_tokens")]
    pub max_tokens: usize,

    /// Temperatura para generación en la nube.
    #[serde(default = "default_temperature")]
    pub temperature: f32,
}

impl Default for Tier3Config {
    fn default() -> Self {
        Self {
            provider: "anthropic".to_string(),
            model: "claude-sonnet-4-20250514".to_string(),
            api_key_env: "NANO_API_KEY".to_string(),
            enabled: false,
            max_tokens: 4096,
            temperature: 0.7,
        }
    }
}

/// Configuración de memoria y base de datos vectorial.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryConfig {
    /// Ruta a la base de datos LanceDB.
    pub vector_db_path: String,

    /// Ruta al modelo de embeddings.
    pub embedding_model: String,

    /// Directorios a indexar automáticamente al iniciar.
    #[serde(default)]
    pub auto_index_paths: Option<Vec<String>>,

    /// Máximo de documentos a inyectar en el contexto.
    #[serde(default = "default_max_context_docs")]
    pub max_context_docs: usize,

    /// Similitud mínima para considerar un documento relevante.
    #[serde(default = "default_min_similarity")]
    pub min_similarity: f32,
}

/// Configuración de herramientas.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolsConfig {
    /// Directorio donde se buscan archivos JSON de herramientas.
    pub directory: String,

    /// Descubrir herramientas automáticamente al iniciar.
    #[serde(default = "default_true")]
    pub auto_discover: bool,
}

/// Configuración de logging.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LoggingConfig {
    /// Nivel de log: trace, debug, info, warn, error.
    #[serde(default = "default_log_level")]
    pub level: String,

    /// Archivo de salida para logs.
    #[serde(default)]
    pub file: Option<String>,
}

/// Configuración de parámetros de generación.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenerationConfig {
    #[serde(default = "default_max_tokens")]
    pub max_tokens: usize,

    #[serde(default = "default_temperature")]
    pub temperature: f32,

    #[serde(default = "default_top_p")]
    pub top_p: f32,

    #[serde(default = "default_repeat_penalty")]
    pub repeat_penalty: f32,

    #[serde(default)]
    pub stop_sequences: Vec<String>,
}

// ── Default values ────────────────────────────────────────────

fn default_version() -> String {
    "1.0".to_string()
}

fn default_context_size() -> usize {
    8192
}

fn default_gpu_layers() -> i32 {
    -1
}

fn default_true() -> bool {
    true
}

fn default_threads() -> usize {
    4
}

fn default_batch_size() -> usize {
    512
}

fn default_confidence() -> f32 {
    0.85
}

fn default_max_tokens() -> usize {
    2048
}

fn default_temperature() -> f32 {
    0.7
}

fn default_top_p() -> f32 {
    0.9
}

fn default_repeat_penalty() -> f32 {
    1.1
}

fn default_max_context_docs() -> usize {
    5
}

fn default_min_similarity() -> f32 {
    0.7
}

fn default_log_level() -> String {
    "info".to_string()
}

// ── Default impls ──────────────────────────────────────────────

impl Default for HybridRoutingConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            confidence_threshold: 0.85,
            privacy_filter: true,
            edge_only: false,
        }
    }
}

impl Default for TiersConfig {
    fn default() -> Self {
        Self {
            tier1: Tier1Config {
                provider: "local".to_string(),
                enabled: true,
            },
            tier2: Tier2Config {
                provider: "local_server".to_string(),
                endpoint: "http://localhost:11434".to_string(),
                enabled: false,
            },
            tier3: Tier3Config {
                provider: "anthropic".to_string(),
                model: "claude-sonnet-4-20250514".to_string(),
                api_key_env: "NANO_API_KEY".to_string(),
                enabled: false,
                max_tokens: 4096,
                temperature: 0.7,
            },
        }
    }
}

impl Default for MemoryConfig {
    fn default() -> Self {
        Self {
            vector_db_path: "data/vectors.lance".to_string(),
            embedding_model: "models/bge-micro-v2.gguf".to_string(),
            auto_index_paths: None,
            max_context_docs: 5,
            min_similarity: 0.7,
        }
    }
}

impl Default for ToolsConfig {
    fn default() -> Self {
        Self {
            directory: "tools/".to_string(),
            auto_discover: true,
        }
    }
}

impl Default for LoggingConfig {
    fn default() -> Self {
        Self {
            level: "info".to_string(),
            file: None,
        }
    }
}

impl Default for GenerationConfig {
    fn default() -> Self {
        Self {
            max_tokens: 2048,
            temperature: 0.7,
            top_p: 0.9,
            repeat_penalty: 1.1,
            stop_sequences: vec![
                "</s>".to_string(),
                "<|endoftext|>".to_string(),
                "<|im_end|>".to_string(),
            ],
        }
    }
}

// ── Config loading ────────────────────────────────────────────

impl Config {
    /// Carga la configuración desde un archivo JSON.
    ///
    /// # Errors
    ///
    /// Retorna error si el archivo no existe, no se puede leer,
    /// o el JSON no cumple con el esquema esperado.
    pub fn load<P: AsRef<Path>>(path: P) -> Result<Self> {
        let path = path.as_ref();
        let content = std::fs::read_to_string(path).map_err(|e| NanoError::ConfigError {
            reason: format!("Cannot read config file '{}': {}", path.display(), e),
        })?;

        let config: Config =
            serde_json::from_str(&content).map_err(|e| NanoError::ConfigError {
                reason: format!("Invalid config JSON: {}", e),
            })?;

        config.validate_dev()?;
        Ok(config)
    }

    /// Valida que la configuración sea coherente.
    ///
    /// Si `allow_missing_model` es `true`, no falla si el modelo no existe
    /// (útil para desarrollo y testing sin modelo real).
    pub fn validate(&self) -> Result<()> {
        self.validate_with_options(false)
    }

    /// Valida permitiendo modelo faltante (para desarrollo/testing).
    pub fn validate_dev(&self) -> Result<()> {
        self.validate_with_options(true)
    }

    fn validate_with_options(&self, allow_missing_model: bool) -> Result<()> {
        // Validate model path exists
        let model_path = Path::new(&self.local_model.path);
        if !model_path.exists() && !self.local_model.path.is_empty() && !allow_missing_model {
            return Err(NanoError::ConfigError {
                reason: format!(
                    "Model file not found: {}. Download a GGUF model or use --features simulated for testing.",
                    self.local_model.path
                ),
            });
        }

        // Validate confidence threshold
        if self.hybrid_routing.confidence_threshold < 0.0
            || self.hybrid_routing.confidence_threshold > 1.0
        {
            return Err(NanoError::ConfigError {
                reason: format!(
                    "confidence_threshold must be between 0.0 and 1.0, got {}",
                    self.hybrid_routing.confidence_threshold
                ),
            });
        }

        // Validate Tier 3 API key if enabled
        if self.tiers.tier3.enabled {
            let key_var = &self.tiers.tier3.api_key_env;
            if std::env::var(key_var).is_err() {
                return Err(NanoError::ConfigError {
                    reason: format!(
                        "Tier 3 is enabled but environment variable '{}' is not set.",
                        key_var
                    ),
                });
            }
        }

        Ok(())
    }

    /// Crea una configuración de prueba con valores por defecto.
    #[cfg(test)]
    pub fn test_config() -> Self {
        Self::default_config()
    }

    /// Crea una configuración por defecto válida para desarrollo.
    pub fn default_config() -> Self {
        Self {
            version: "1.0".to_string(),
            local_model: LocalModelConfig {
                path: String::new(),
                context_size: 8192,
                gpu_layers: -1,
                use_mmap: true,
                threads: 4,
                batch_size: 512,
            },
            hybrid_routing: HybridRoutingConfig::default(),
            tiers: TiersConfig::default(),
            memory: MemoryConfig::default(),
            tools: ToolsConfig::default(),
            logging: LoggingConfig::default(),
            generation: GenerationConfig::default(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config_valid() {
        let config = Config::test_config();
        assert!(config.validate().is_ok());
        assert_eq!(config.version, "1.0");
        assert_eq!(config.hybrid_routing.confidence_threshold, 0.85);
    }

    #[test]
    fn test_invalid_confidence_threshold() {
        let mut config = Config::test_config();
        config.hybrid_routing.confidence_threshold = 2.0;
        assert!(config.validate().is_err());
    }
}
