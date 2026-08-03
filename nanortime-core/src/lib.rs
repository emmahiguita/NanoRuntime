//! NanoAI Runtime — Motor de orquestación de IA híbrido (Edge-Cloud)
//!
//! Este crate implementa el núcleo del runtime: orquestación,
//! ejecución de modelos, herramientas declarativas y búsqueda vectorial.
//!
//! # Arquitectura
//!
//! El runtime se divide en tres capas:
//!
//! - **Orchestrator Layer**: Routing híbrido, filtro de privacidad, evaluación de confianza
//! - **Execution Layer**: Gestión de modelos, memoria, herramientas y vectores
//! - **Inference Layer**: Puente FFI con llama.cpp, streaming de tokens, generación con gramática
//!
//! # Ejemplo
//!
//! ```rust,no_run
//! use nanortime_core::{NanoRuntime, Config, UserRequest};
//!
//! #[tokio::main]
//! async fn main() -> anyhow::Result<()> {
//!     let config = Config::load("nano.manifest.json")?;
//!     let runtime = NanoRuntime::new(config).await?;
//!
//!     let response = runtime.process_request(UserRequest {
//!         prompt: "¿Qué hora es?".to_string(),
//!         context: None,
//!         history: None,
//!     }).await?;
//!
//!     println!("{}", response.text);
//!     Ok(())
//! }
//! ```

pub mod config;
pub mod error;
pub mod execution;
pub mod inference;
pub mod memory_engine;
pub mod orchestrator;
pub mod streaming_output;

use std::sync::Arc;

use execution::{ModelManager, ToolExecutor, VectorEngine};
use tracing::info;

pub use config::manifest::Config;
pub use config::tools::ToolDefinition;
pub use error::NanoError;
pub use memory_engine::NanoMemoryEngine;
pub use orchestrator::Orchestrator; 

/// Petición del usuario al runtime.
#[derive(Debug, Clone)]
pub struct UserRequest {
    /// El prompt o mensaje del usuario.
    pub prompt: String,
    /// Contexto adicional (archivos, documentos, etc.).
    pub context: Option<String>,
    /// Historial de conversación previa.
    pub history: Option<Vec<ChatMessage>>,
}

/// Mensaje en el historial de conversación.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct ChatMessage {
    /// Rol del emisor: "user" o "assistant".
    pub role: String,
    /// Contenido del mensaje.
    pub content: String,
}

/// Respuesta del runtime al usuario.
#[derive(Debug, Clone)]
pub struct Response {
    /// Texto de la respuesta generada.
    pub text: String,
    /// Tier que procesó la petición (Local, Lan, Cloud).
    pub tier_used: String,
    /// Puntuación de confianza del modelo local (0.0 a 1.0).
    pub confidence: Option<f32>,
    /// Herramientas ejecutadas durante el procesamiento.
    pub tool_calls: Vec<ToolCallResult>,
    /// Documentos fuente usados por RAG.
    pub sources: Vec<SourceDocument>,
    /// Tokens generados en esta respuesta.
    pub tokens_generated: usize,
}

/// Resultado de la ejecución de una herramienta.
#[derive(Debug, Clone)]
pub struct ToolCallResult {
    /// Nombre de la herramienta ejecutada.
    pub tool_name: String,
    /// Parámetros con los que se ejecutó.
    pub parameters: serde_json::Value,
    /// Resultado de la ejecución.
    pub result: serde_json::Value,
    /// Si la ejecución fue exitosa.
    pub success: bool,
    /// Mensaje de error si falló.
    pub error: Option<String>,
}

/// Documento fuente recuperado por RAG.
#[derive(Debug, Clone)]
pub struct SourceDocument {
    /// Contenido del documento.
    pub content: String,
    /// Metadatos del documento.
    pub metadata: serde_json::Value,
    /// Puntuación de similitud (0.0 a 1.0).
    pub similarity: f32,
}

/// Punto de entrada principal del runtime.
///
/// `NanoRuntime` orquesta todos los componentes: carga el modelo,
/// inicializa la base de datos vectorial, registra herramientas y
/// procesa peticiones del usuario con routing híbrido.
pub struct NanoRuntime {
    orchestrator: Arc<Orchestrator>,
    model_manager: Arc<ModelManager>,
    tool_executor: Arc<ToolExecutor>,
    vector_engine: Arc<VectorEngine>,
}

impl NanoRuntime {
    /// Inicializa el runtime con la configuración proporcionada.
    ///
    /// Carga el modelo local, inicializa la base de datos vectorial,
    /// registra herramientas del directorio configurado e indexa
    /// documentos automáticamente si está configurado.
    ///
    /// # Errors
    ///
    /// Retorna error si:
    /// - El modelo no se encuentra en la ruta especificada
    /// - No hay suficiente memoria para cargar el modelo
    /// - La base de datos vectorial no puede inicializarse
    pub async fn new(mut config: Config) -> Result<Self, NanoError> {
        info!("Initializing NanoAI Runtime v{}", env!("CARGO_PKG_VERSION"));

        // 0. Memory-aware configuration: ajustar contexto según RAM disponible
        let model_path = std::path::Path::new(&config.local_model.path);
        if model_path.exists() {
            let model_file_mb = (std::fs::metadata(model_path)
                .map(|m| m.len()).unwrap_or(0) / (1024 * 1024)) as u64;
            if model_file_mb > 0 {
                let (recommended_ctx, recommended_batch) = crate::execution::MemoryManager::auto_configure(
                    model_file_mb,
                    config.local_model.context_size as u32,
                );
                // Solo reducir, nunca aumentar sobre lo configurado
                if (recommended_ctx as usize) < config.local_model.context_size {
                    tracing::info!(
                        "RAM optimization: reducing context from {} to {}, batch from {} to {}",
                        config.local_model.context_size, recommended_ctx,
                        config.local_model.batch_size, recommended_batch,
                    );
                    config.local_model.context_size = recommended_ctx as usize;
                    config.local_model.batch_size = recommended_batch as usize;
                } else {
                    tracing::info!("RAM: sufficient memory for full context {}", config.local_model.context_size);
                }
            }
        }

        // 1. Initialize core components
        let model_manager = Arc::new(ModelManager::new(config.clone()).await?);
        let vector_engine = Arc::new(VectorEngine::new(&config).await?);
        let tool_executor = Arc::new(ToolExecutor::new(&config).await?);

        // 2. Initialize orchestrator
        let orchestrator = Arc::new(Orchestrator::new(
            config.clone(),
            model_manager.clone(),
            vector_engine.clone(),
            tool_executor.clone(),
        ));

        // 3. Load initial model
        model_manager.load_model(&config.local_model.path).await?;
        info!("Model loaded successfully");

        // 4. Auto-discover tools from directory
        if config.tools.auto_discover {
            let count = tool_executor.discover_tools(&config.tools.directory).await?;
            info!("Discovered {} tools", count);
        }

        // 5. Auto-index documents in background if configured
        if let Some(ref paths) = config.memory.auto_index_paths {
            let paths_clone = paths.clone();
            let ve = vector_engine.clone();
            tokio::spawn(async move {
                for path in paths_clone {
                    match ve.index_directory(&path).await {
                        Ok(count) => info!("Background indexed {} documents from {}", count, path),
                        Err(e) => tracing::warn!("Background index failed for {}: {}", path, e),
                    }
                }
            });
        }

        Ok(Self {
            orchestrator,
            model_manager,
            tool_executor,
            vector_engine,
        })
    }

    /// Procesa una petición del usuario a través del pipeline completo:
    /// privacy check → RAG → routing → inference → tool execution.
    pub async fn process_request(
        &self,
        request: UserRequest,
    ) -> Result<Response, NanoError> {
        self.orchestrator.process_request(request).await
    }

    /// Procesa una petición con streaming de tokens.
    ///
    /// Retorna (respuesta, receiver) donde receiver emite (token, probability).
    pub async fn process_request_streaming(
        &self,
        request: UserRequest,
    ) -> Result<(Response, tokio::sync::mpsc::Receiver<(String, f32)>), NanoError> {
        self.orchestrator.process_request_streaming(request).await
    }

    /// Cambia el modelo activo a otro archivo GGUF.
    ///
    /// Descarga el modelo actual y carga el nuevo desde la ruta especificada.
    pub async fn switch_model(&self, model_path: &str) -> Result<(), NanoError> {
        info!("Switching model to: {}", model_path);
        self.model_manager.load_model(model_path).await
    }

    /// Aplica un adaptador LoRA al modelo activo.
    ///
    /// Permite especializar el modelo sin recargarlo completamente.
    /// `strength` controla la intensidad del adaptador (0.0 a 1.0).
    pub async fn apply_lora(&self, lora_path: &str, strength: f32) -> Result<(), NanoError> {
        info!("Applying LoRA: {} (strength: {})", lora_path, strength);
        self.model_manager.apply_lora(lora_path, strength).await
    }

    /// Registra una herramienta desde su definición JSON.
    pub async fn register_tool(&self, json: &str) -> Result<(), NanoError> {
        self.tool_executor.register_from_json(json).await
    }

    /// Indexa un documento en la base de datos vectorial para RAG.
    pub async fn index_document(
        &self,
        content: &str,
        metadata: serde_json::Value,
    ) -> Result<(), NanoError> {
        // Generate embedding from the model for semantic search
        let embedding = self.model_manager.embed_text(content).await.ok();
        self.vector_engine.index_document(content, metadata, embedding).await
    }

    /// Escanea un directorio e indexa archivos de código/texto para RAG.
    pub async fn index_directory(&self, path: &str) -> Result<usize, NanoError> {
        self.vector_engine.index_directory(path).await
    }

    /// Aprende de una corrección del usuario.
    ///
    /// La corrección se almacena en la base de datos vectorial y se
    /// inyectará automáticamente en el contexto cuando el usuario haga
    /// una consulta similar en el futuro.
    pub async fn learn_from_correction(
        &self,
        original_prompt: &str,
        user_correction: &str,
    ) -> Result<(), NanoError> {
        info!("Learning from correction: '{}' → '{}'",
            &original_prompt[..original_prompt.len().min(50)],
            &user_correction[..user_correction.len().min(50)]);
        self.orchestrator.learn_from_correction(original_prompt, user_correction).await
    }

    /// Devuelve una referencia al motor vectorial para operaciones avanzadas.
    pub fn vector_engine(&self) -> &Arc<VectorEngine> {
        &self.vector_engine
    }

    /// Devuelve una referencia al ejecutor de herramientas.
    pub fn tool_executor(&self) -> &Arc<ToolExecutor> {
        &self.tool_executor
    }
}
