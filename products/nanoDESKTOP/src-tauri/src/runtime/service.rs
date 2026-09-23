//! RuntimeService: Fachada de aplicación para comandos Tauri.
//!
//! QUÉ HACE: Desacopla la capa de presentación Tauri de los detalles de bajo
//! nivel de nanortime-core y de la concurrencia del Supervisor.
//!
//! CÓMO FUNCIONA: Construye las instancias de `UserRequest` requeridas por el
//! motor, aplica saneamiento de entradas y delega la ejecución al Supervisor.
//!
//! POR QUÉ: Sigue el principio de Responsabilidad Única (SRP) y Clean Architecture:
//! los controladores IPC no manipulan directamente hilos ni punteros FFI.

use std::sync::Arc;
use tokio::sync::{mpsc, oneshot};

use super::supervisor::RuntimeSupervisor;
use nanortime_core::{Response, UserRequest};

pub struct RuntimeService {
    supervisor: Arc<RuntimeSupervisor>,
}

impl Default for RuntimeService {
    fn default() -> Self {
        Self::new()
    }
}

impl RuntimeService {
    pub fn new() -> Self {
        Self {
            supervisor: Arc::new(RuntimeSupervisor::new()),
        }
    }

    /// Prepara y despacha una consulta con emisión continua de tokens.
    pub async fn stream_prompt(
        &self,
        model_path: &str,
        prompt: &str,
        max_tokens: usize,
        temperature: Option<f32>,
    ) -> Result<(oneshot::Receiver<Result<Response, String>>, mpsc::Receiver<(String, f32)>), String> {
        let trimmed = prompt.trim();
        if trimmed.is_empty() {
            return Err("El prompt proporcionado no puede estar vacío".to_string());
        }

        let request = UserRequest {
            prompt: trimmed.to_string(),
            context: None,
            history: None,
            session_id: Some("desktop-chat-session".to_string()),
            max_tokens: Some(max_tokens),
            temperature,
        };

        self.supervisor.generate_stream(model_path, request).await
    }

    /// Retorna el nombre del modelo actualmente cargado o "none".
    pub async fn current_model(&self) -> String {
        self.supervisor
            .loaded_model()
            .await
            .unwrap_or_else(|| "none".to_string())
    }

    /// Detiene el runtime activo y libera memoria.
    pub async fn shutdown(&self) {
        self.supervisor.shutdown().await;
    }
}
