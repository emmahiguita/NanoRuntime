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
//!         session_id: None,
//!         max_tokens: None,
//!         temperature: None,
//!     }).await?;
//!
//!     println!("{}", response.text);
//!     Ok(())
//! }
//! ```

pub mod cli_inference_bridge;
pub mod config;
pub mod error;
pub mod execution;
pub mod hybrid_router;
pub mod inference;
pub mod inference_backend; // DIP: InferenceBackend trait + LlamaCppBackend impl
pub mod memory_engine;
pub mod nano_session; // KV-cache persistence (was #[cfg(unstable)], enabled v0.2)
pub mod orchestrator;
pub mod speculative_decoder; // speculative decoding (always available, export unconditional)

use std::sync::Arc;

use execution::{ModelManager, ToolExecutor, VectorEngine};
use tracing::info;

pub use config::manifest::Config;
pub use config::tools::ToolDefinition;
pub use error::NanoError;
pub use execution::model_manager::{RuntimeStatus, ViabilityStatus};
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
    /// Identificador estable de conversacion para cache KV.
    pub session_id: Option<String>,
    /// Límite opcional de tokens para esta petición.
    pub max_tokens: Option<usize>,
    /// Temperatura opcional para esta petición. Si es None, se usa la del
    /// config. Some(0.0) es válido y significa greedy determinista.
    pub temperature: Option<f32>,
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
    /// Memoria total del modelo cargado (MB). 0 si no hay modelo.
    pub model_memory_mb: u64,
    /// Gate R10 — métricas de generación del último turno (TTFT, prefill,
    /// cache-hit). Permite al cliente saber SIEMPRE por qué un turno fue
    /// lento: modelo cargando vs prefill vs cache miss vs decode vs tool.
    pub stats: Option<GenerationStats>,
}

/// Gate R10 — métricas de latencia de una generación. Medidas en el backend
/// (ffi), propagadas por ModelManager y expuestas en /completion (SSE final).
#[derive(Debug, Clone, Default, serde::Serialize)]
pub struct GenerationStats {
    /// Tiempo hasta el primer token emitido (ms). Incluye prefill + decode.
    pub ttft_ms: u64,
    /// Tiempo de prefill puro — procesado del prompt (ms).
    pub prefill_ms: u64,
    /// Tokens del prompt reutilizados del KV cache (prefix hit).
    pub cache_hit_tokens: usize,
    /// Tokens del prompt que hubo que decodificar (miss).
    pub cache_miss_tokens: usize,
    /// Tokens totales procesados (prompt + generados).
    pub total_tokens: usize,
    /// Tokens generados en este turno.
    pub generated_tokens: usize,
    /// Tokens por segundo (decode).
    pub decode_tok_s: f64,
    /// Tiempo total de la generación (ms).
    pub total_ms: u64,
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
    /// Estado completo del runtime (telemetría + viabilidad) para la API HTTP.
    /// Síncrono — lo consume el hilo del servidor HTTP.
    pub fn status(&self) -> RuntimeStatus {
        self.model_manager.status()
    }

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
    pub async fn new(config: Config) -> Result<Self, NanoError> {
        info!("Initializing NanoAI Runtime v{}", env!("CARGO_PKG_VERSION"));

        // Pre-flight: check model file exists. V2 auto-config runs inside
        // ModelManager::load_model() (hardware-aware, big.LITTLE detection).
        let model_path = std::path::Path::new(&config.local_model.path);
        if !model_path.exists() {
            tracing::warn!(
                "Model file not found at {} — runtime will fail on model load",
                config.local_model.path
            );
        } else {
            let model_file_mb = (std::fs::metadata(model_path).map(|m| m.len()).unwrap_or(0)
                / (1024 * 1024)) as u64;
            tracing::info!(
                "Model file exists: {} ({} MB)",
                config.local_model.path,
                model_file_mb
            );
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
            let count = tool_executor
                .discover_tools(&config.tools.directory)
                .await?;
            info!("Discovered {} tools", count);
        }

        // 5. Auto-index documents in background if configured
        if let Some(ref paths) = config.memory.auto_index_paths {
            let paths_clone = paths.clone();
            let ve = vector_engine.clone();
            tokio::spawn(async move {
                for path in paths_clone {
                    match ve.index_directory(&path).await {
                        Ok(count) => {
                            info!("Background indexed {} documents from {}", count, path);
                            let _ = ve.flush().await; // Persist batch — ignore flush errors
                        }
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
    pub async fn process_request(&self, request: UserRequest) -> Result<Response, NanoError> {
        self.orchestrator.process_request(request).await
    }

    /// Procesa una petición con streaming de tokens.
    ///
    /// Retorna (respuesta_final, receiver) donde el receiver emite (token,
    /// probability) en tiempo real y la respuesta completa se resuelve en
    /// el oneshot cuando la generación termina o se aborta.
    pub async fn process_request_streaming(
        &self,
        request: UserRequest,
    ) -> Result<
        (
            tokio::sync::oneshot::Receiver<Response>,
            tokio::sync::mpsc::Receiver<(String, f32)>,
        ),
        NanoError,
    > {
        self.orchestrator.process_request_streaming(request).await
    }

    /// Cambia el modelo activo a otro archivo GGUF.
    ///
    /// Descarga el modelo actual y carga el nuevo desde la ruta especificada.
    pub async fn switch_model(&self, model_path: &str) -> Result<(), NanoError> {
        info!("Switching model to: {}", model_path);
        // Cache entries from the old model are stale — different model, different outputs.
        self.orchestrator.invalidate_caches().await;
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
        let embedding = match self.model_manager.embed_text(content).await {
            Ok(emb) => Some(emb),
            Err(e) => {
                tracing::warn!(
                    "Document embedding failed for index_document — indexing without embedding: {}",
                    e
                );
                None
            }
        };
        self.vector_engine
            .index_document(content, metadata, embedding)
            .await
    }

    /// Escanea un directorio e indexa archivos de código/texto para RAG.
    pub async fn index_directory(&self, path: &str) -> Result<usize, NanoError> {
        self.vector_engine.index_directory(path).await
    }

    /// Flushes the vector engine's in-memory state to disk.
    /// No-op if no changes since last flush.
    pub async fn flush_index(&self) -> Result<(), NanoError> {
        self.vector_engine.flush().await
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
        info!(
            "Learning from correction: '{}' → '{}'",
            &original_prompt[..original_prompt.len().min(50)],
            &user_correction[..user_correction.len().min(50)]
        );
        self.orchestrator
            .learn_from_correction(original_prompt, user_correction)
            .await
    }

    /// Devuelve una referencia al motor vectorial para operaciones avanzadas.
    pub fn vector_engine(&self) -> &Arc<VectorEngine> {
        &self.vector_engine
    }

    /// Devuelve una referencia al ejecutor de herramientas.
    pub fn tool_executor(&self) -> &Arc<ToolExecutor> {
        &self.tool_executor
    }

    /// Acceso al gestor de modelos (para persistencia de sesión, etc.).
    pub fn model_manager(&self) -> &Arc<ModelManager> {
        &self.model_manager
    }

    /// Gate R6 — invalida el KV de la sesión tras una cancelación.
    /// La usa el server HTTP al detectar POST /cancel o desconexión del
    /// cliente: el siguiente turno arranca con prefill limpio, nunca con
    /// estado dudoso heredado.
    pub async fn invalidate_session_kv(&self) {
        self.model_manager.invalidate_session_kv().await;
    }

    /// Gate R6 — marca el KV de la sesión [session_id] como dudoso tras una
    /// cancelación. Más fino que [invalidate_session_kv]: solo afecta a la
    /// sesión indicada, dejando intactas otras sesiones concurrentes.
    pub async fn mark_session_cancelled(&self, session_id: &str) {
        self.model_manager.mark_session_cancelled(session_id).await;
    }
}
