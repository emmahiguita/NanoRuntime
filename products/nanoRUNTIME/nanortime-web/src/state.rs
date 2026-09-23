//! Estado y DTOs para el servidor HTTP de NanoRuntime Web.
//!
//! Este módulo encapsula las estructuras de datos intercambiadas vía JSON
//! y el estado compartido entre hilos de ejecución de la API REST.

use std::sync::{
    mpsc::{self, Receiver, SyncSender, TrySendError},
    Arc, Mutex,
};

use nanortime_core::{ChatMessage, Config, NanoRuntime, UserRequest};

const INFERENCE_QUEUE_CAPACITY: usize = 4;

/// Petición de inferencia recibida vía POST /api/chat.
#[derive(Debug, serde::Deserialize)]
pub struct ChatRequest {
    pub prompt: String,
    #[serde(default = "default_max_tokens")]
    pub max_tokens: usize,
    #[serde(default)]
    pub history: Vec<ChatMessage>,
    #[serde(default)]
    pub session_id: Option<String>,
}

fn default_max_tokens() -> usize {
    150
}

/// Respuesta estructurada emitida tras completar la inferencia.
#[derive(Debug, serde::Serialize)]
pub struct ChatResponse {
    pub response: String,
    pub tok_s: f64,
    pub confidence: f64,
}

impl ChatResponse {
    pub fn error(message: impl Into<String>) -> Self {
        Self {
            response: message.into(),
            tok_s: 0.0,
            confidence: 0.0,
        }
    }
}

#[derive(Debug)]
pub enum InferenceError {
    Busy,
    Unavailable(String),
}

struct InferenceJob {
    prompt: String,
    max_tokens: usize,
    history: Vec<ChatMessage>,
    session_id: Option<String>,
    response_tx: SyncSender<Result<ChatResponse, String>>,
}

/// Telemetría y estado general del servidor web y runtime.
#[derive(Debug, serde::Serialize)]
pub struct StatusResponse {
    pub status: String,
    pub model: String,
    pub model_status: String,
    pub model_error: Option<String>,
    pub ram_available_mb: u64,
    pub message: String,
}

#[derive(Debug)]
struct ModelConnectionState {
    status: String,
    error: Option<String>,
}

/// Estado compartido protegido para el servidor REST.
pub struct ServerState {
    pub model_path: String,
    pub last_tok_s: Mutex<f64>,
    pub last_confidence: Mutex<f64>,
    inference_tx: SyncSender<InferenceJob>,
    model_connection: Arc<Mutex<ModelConnectionState>>,
}

impl ServerState {
    pub fn new(model_path: &str) -> Self {
        let model_path = model_path.to_string();
        let worker_model_path = model_path.clone();
        let (inference_tx, inference_rx) = mpsc::sync_channel(INFERENCE_QUEUE_CAPACITY);
        let initial_status = if std::path::Path::new(&model_path).is_file() {
            "configured"
        } else {
            "missing"
        };
        let model_connection = Arc::new(Mutex::new(ModelConnectionState {
            status: initial_status.to_string(),
            error: (initial_status == "missing")
                .then(|| format!("No existe el archivo GGUF: {}", model_path)),
        }));
        let worker_connection = Arc::clone(&model_connection);

        std::thread::Builder::new()
            .name("nanortime-web-runtime".to_string())
            .spawn(move || inference_worker(worker_model_path, inference_rx, worker_connection))
            .expect("No se pudo iniciar el worker persistente de NanoRuntime");

        Self {
            model_path,
            last_tok_s: Mutex::new(0.0),
            last_confidence: Mutex::new(0.0),
            inference_tx,
            model_connection,
        }
    }

    pub fn model_connection(&self) -> (String, Option<String>) {
        match self.model_connection.lock() {
            Ok(connection) => (connection.status.clone(), connection.error.clone()),
            Err(_) => (
                "error".to_string(),
                Some("Estado del modelo no disponible".to_string()),
            ),
        }
    }

    /// Encola una inferencia en el único worker que mantiene el modelo cargado.
    pub fn run_inference(
        &self,
        prompt: &str,
        max_tokens: usize,
        history: Vec<ChatMessage>,
        session_id: Option<String>,
    ) -> Result<ChatResponse, InferenceError> {
        let (response_tx, response_rx) = mpsc::sync_channel(1);
        let job = InferenceJob {
            prompt: prompt.to_string(),
            max_tokens,
            history,
            session_id,
            response_tx,
        };

        match self.inference_tx.try_send(job) {
            Ok(()) => {}
            Err(TrySendError::Full(_)) => return Err(InferenceError::Busy),
            Err(TrySendError::Disconnected(_)) => {
                return Err(InferenceError::Unavailable(
                    "Worker de inferencia detenido".to_string(),
                ));
            }
        }

        match response_rx.recv() {
            Ok(Ok(response)) => {
                if let Ok(mut tok) = self.last_tok_s.lock() {
                    *tok = response.tok_s;
                }
                if let Ok(mut conf) = self.last_confidence.lock() {
                    *conf = response.confidence;
                }
                Ok(response)
            }
            Ok(Err(message)) => Err(InferenceError::Unavailable(message)),
            Err(_) => Err(InferenceError::Unavailable(
                "Worker de inferencia no respondió".to_string(),
            )),
        }
    }
}

fn inference_worker(
    model_path: String,
    inference_rx: Receiver<InferenceJob>,
    model_connection: Arc<Mutex<ModelConnectionState>>,
) {
    let tokio_runtime = match tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
    {
        Ok(runtime) => runtime,
        Err(error) => {
            eprintln!("[nanortime-web] No se pudo crear Tokio runtime: {}", error);
            return;
        }
    };

    let mut runtime: Option<NanoRuntime> = None;

    while let Ok(job) = inference_rx.recv() {
        let result = tokio_runtime.block_on(async {
            if runtime.is_none() {
                update_model_connection(&model_connection, "loading", None);
                let mut config = Config::default_config();
                config.local_model.path = model_path.clone();
                config.hybrid_routing.edge_only = true;
                config.tools.auto_discover = false;

                match NanoRuntime::new(config).await {
                    Ok(loaded_runtime) => {
                        runtime = Some(loaded_runtime);
                        update_model_connection(&model_connection, "ready", None);
                    }
                    Err(error) => {
                        let message = format!("Runtime init: {}", error);
                        update_model_connection(&model_connection, "error", Some(message.clone()));
                        return Err(message);
                    }
                }
            }

            let request = UserRequest {
                prompt: job.prompt,
                context: None,
                history: (!job.history.is_empty()).then_some(job.history),
                session_id: job.session_id,
                max_tokens: Some(job.max_tokens),
                temperature: Some(0.0),
            };
            let started = std::time::Instant::now();
            let response = runtime
                .as_ref()
                .expect("runtime inicializado")
                .process_request(request)
                .await
                .map_err(|error| format!("Inference: {}", error))?;
            let elapsed = started.elapsed().as_secs_f64();
            let measured_tok_s = response
                .stats
                .as_ref()
                .map(|stats| stats.decode_tok_s)
                .filter(|tok_s| tok_s.is_finite() && *tok_s > 0.0)
                .unwrap_or_else(|| {
                    if elapsed > 0.0 {
                        response.tokens_generated as f64 / elapsed
                    } else {
                        0.0
                    }
                });

            Ok(ChatResponse {
                response: response.text,
                tok_s: measured_tok_s,
                confidence: response.confidence.unwrap_or(0.0) as f64,
            })
        });

        let _ = job.response_tx.send(result);
    }
}

fn update_model_connection(
    connection: &Arc<Mutex<ModelConnectionState>>,
    status: &str,
    error: Option<String>,
) {
    if let Ok(mut connection) = connection.lock() {
        connection.status = status.to_string();
        connection.error = error;
    }
}
