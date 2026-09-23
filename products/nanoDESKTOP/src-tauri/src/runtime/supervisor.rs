//! RuntimeSupervisor: Actor y supervisor persistente de NanoRuntime.
//!
//! QUÉ HACE: Aísla el motor NanoRuntime y sus punteros FFI (*mut c_void) en un
//! hilo de trabajo dedicado (worker thread), exponiendo una interfaz 100% Send
//! para Tauri mediante canales asíncronos Tokio.
//!
//! CÓMO FUNCIONA: Mantiene una única instancia en memoria (singleton) del modelo,
//! evitando recargas desde disco. Los comandos IPC envían peticiones a través de un
//! canal mpsc y reciben tokens en tiempo real mediante canales desacoplados.
//!
//! POR QUÉ: Los punteros crudos FFI de llama.cpp no implementan Send entre hilos
//! del pool de Tokio. El modelo de actor en hilo dedicado resuelve la seguridad
//! de tipos de Rust y previene bloqueos en la interfaz gráfica.

use std::sync::Arc;
use tokio::sync::{mpsc, oneshot};

use nanortime_core::config::manifest::Config;
use nanortime_core::{NanoRuntime, Response, UserRequest};

enum RuntimeCommand {
    StreamPrompt {
        model_path: String,
        request: UserRequest,
        token_tx: mpsc::Sender<(String, f32)>,
        response_tx: oneshot::Sender<Result<Response, String>>,
    },
    GetLoadedModel {
        reply_tx: oneshot::Sender<Option<String>>,
    },
    Shutdown,
}

pub struct RuntimeSupervisor {
    cmd_tx: mpsc::Sender<RuntimeCommand>,
}

impl Default for RuntimeSupervisor {
    fn default() -> Self {
        Self::new()
    }
}

impl RuntimeSupervisor {
    pub fn new() -> Self {
        let (cmd_tx, mut cmd_rx) = mpsc::channel::<RuntimeCommand>(32);

        // Hilo de trabajo dedicado para aislar punteros FFI
        std::thread::Builder::new()
            .name("nano-runtime-worker".to_string())
            .spawn(move || {
                let rt = match tokio::runtime::Builder::new_current_thread()
                    .enable_all()
                    .build()
                {
                    Ok(r) => r,
                    Err(e) => {
                        eprintln!("[RuntimeSupervisor] Error creando Tokio runtime local: {}", e);
                        return;
                    }
                };

                rt.block_on(async move {
                    let mut runtime: Option<Arc<NanoRuntime>> = None;
                    let mut loaded_model: Option<String> = None;

                    while let Some(cmd) = cmd_rx.recv().await {
                        match cmd {
                            RuntimeCommand::StreamPrompt {
                                model_path,
                                request,
                                token_tx,
                                response_tx,
                            } => {
                                let model_clean = model_path.trim().to_string();

                                // Inicialización o conmutación en caliente de modelo
                                let rt_instance = match ensure_engine(
                                    &mut runtime,
                                    &mut loaded_model,
                                    &model_clean,
                                )
                                .await
                                {
                                    Ok(inst) => inst,
                                    Err(err) => {
                                        let _ = response_tx.send(Err(err));
                                        continue;
                                    }
                                };

                                match rt_instance.process_request_streaming(request).await {
                                    Ok((final_rx, mut stream_rx)) => {
                                        // Retransmisión de tokens hacia el canal de Tauri
                                        tokio::spawn(async move {
                                            while let Some(item) = stream_rx.recv().await {
                                                if token_tx.send(item).await.is_err() {
                                                    break; // Receptor desconectado
                                                }
                                            }
                                        });

                                        tokio::spawn(async move {
                                            match final_rx.await {
                                                Ok(res) => {
                                                    let _ = response_tx.send(Ok(res));
                                                }
                                                Err(e) => {
                                                    let _ = response_tx.send(Err(format!(
                                                        "Canal final abortado: {}",
                                                        e
                                                    )));
                                                }
                                            }
                                        });
                                    }
                                    Err(e) => {
                                        let _ = response_tx.send(Err(format!("Error inferencia: {}", e)));
                                    }
                                }
                            }
                            RuntimeCommand::GetLoadedModel { reply_tx } => {
                                let _ = reply_tx.send(loaded_model.clone());
                            }
                            RuntimeCommand::Shutdown => {
                                drop(runtime);
                                drop(loaded_model);
                                break;
                            }
                        }
                    }
                });
            })
            .expect("Fallo al crear hilo nano-runtime-worker");

        Self { cmd_tx }
    }

    /// Despacha una inferencia con canales de tokens y respuesta final.
    pub async fn generate_stream(
        &self,
        model_path: &str,
        request: UserRequest,
    ) -> Result<(oneshot::Receiver<Result<Response, String>>, mpsc::Receiver<(String, f32)>), String> {
        let (token_tx, token_rx) = mpsc::channel(128);
        let (response_tx, response_rx) = oneshot::channel();

        self.cmd_tx
            .send(RuntimeCommand::StreamPrompt {
                model_path: model_path.to_string(),
                request,
                token_tx,
                response_tx,
            })
            .await
            .map_err(|e| format!("Error comunicando con worker de inferencia: {}", e))?;

        Ok((response_rx, token_rx))
    }

    pub async fn loaded_model(&self) -> Option<String> {
        let (reply_tx, reply_rx) = oneshot::channel();
        if self
            .cmd_tx
            .send(RuntimeCommand::GetLoadedModel { reply_tx })
            .await
            .is_ok()
        {
            reply_rx.await.unwrap_or(None)
        } else {
            None
        }
    }

    pub async fn shutdown(&self) {
        let _ = self.cmd_tx.send(RuntimeCommand::Shutdown).await;
    }
}

/// Helper para inicializar o reutilizar la instancia de NanoRuntime.
async fn ensure_engine(
    runtime: &mut Option<Arc<NanoRuntime>>,
    loaded_model: &mut Option<String>,
    target_model: &str,
) -> Result<Arc<NanoRuntime>, String> {
    if let (Some(rt), Some(current)) = (runtime.as_ref(), loaded_model.as_ref()) {
        if current == target_model {
            return Ok(Arc::clone(rt));
        }
        rt.switch_model(target_model)
            .await
            .map_err(|e| format!("Error cambiando modelo a {}: {}", target_model, e))?;
        *loaded_model = Some(target_model.to_string());
        return Ok(Arc::clone(rt));
    }

    let mut config = Config::default_config();
    config.local_model.path = target_model.to_string();
    config.hybrid_routing.edge_only = true;
    config.tools.auto_discover = false;

    let new_rt = Arc::new(
        NanoRuntime::new(config)
            .await
            .map_err(|e| format!("Error inicializando NanoRuntime con {}: {}", target_model, e))?,
    );

    *runtime = Some(Arc::clone(&new_rt));
    *loaded_model = Some(target_model.to_string());

    Ok(new_rt)
}
