//! Comandos Tauri para Inferencia y Chat en Nano Desktop.
//!
//! QUÉ HACE: Expone las interfaces IPC invocables desde el frontend de JavaScript.
//! CÓMO FUNCIONA: Inyecta `RuntimeService` mediante `tauri::State` y retransmite
//! los tokens de inferencia directamente hacia la ventana web activa usando eventos.
//! POR QUÉ: Sustituye el polling y la recarga en disco por streaming nativo reactivo.

use serde::{Deserialize, Serialize};
use std::sync::Arc;
use tauri::{AppHandle, Emitter, State};

use crate::runtime::RuntimeService;

#[derive(Debug, Deserialize)]
pub struct ChatInput {
    pub prompt: String,
    pub model_path: Option<String>,
    pub max_tokens: Option<usize>,
    pub temperature: Option<f32>,
    pub request_id: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct ChatOutput {
    pub text: String,
    pub tok_s: f64,
    pub confidence: f64,
    pub status: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct TokenEventPayload {
    pub request_id: String,
    pub token: String,
    pub probability: f32,
}

#[derive(Debug, Clone, Serialize)]
pub struct DoneEventPayload {
    pub request_id: String,
    pub text: String,
    pub tok_s: f64,
    pub total_tokens: usize,
    pub model: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct ErrorEventPayload {
    pub request_id: String,
    pub message: String,
}

fn emit_chat_error(app: &AppHandle, request_id: &str, message: impl Into<String>) {
    let _ = app.emit(
        "chat-error",
        ErrorEventPayload {
            request_id: request_id.to_string(),
            message: message.into(),
        },
    );
}

/// Comando IPC sincrónico/acumulativo que utiliza el RuntimeService persistente.
#[tauri::command]
pub async fn nano_chat_prompt(
    service: State<'_, Arc<RuntimeService>>,
    input: ChatInput,
) -> Result<ChatOutput, String> {
    let model = input.model_path.unwrap_or_else(|| "qwen.gguf".to_string());
    let max_tokens = input.max_tokens.unwrap_or(256);

    let (response_rx, mut token_rx) = service
        .stream_prompt(&model, &input.prompt, max_tokens, input.temperature)
        .await
        .map_err(|e| format!("[Error Runtime] {}", e))?;

    let mut accumulated = String::new();
    while let Some((token, _)) = token_rx.recv().await {
        accumulated.push_str(&token);
    }

    match response_rx.await {
        Ok(Ok(resp)) => {
            let tok_s = resp.stats.as_ref().map(|s| s.decode_tok_s).unwrap_or(0.0);
            Ok(ChatOutput {
                text: resp.text,
                tok_s,
                confidence: resp.confidence.map(|c| c as f64).unwrap_or(1.0),
                status: "ok".into(),
            })
        }
        Ok(Err(e)) => Ok(ChatOutput {
            text: format!("[Error Runtime] {}", e),
            tok_s: 0.0,
            confidence: 0.0,
            status: "error".into(),
        }),
        Err(_) => Ok(ChatOutput {
            text: accumulated,
            tok_s: 0.0,
            confidence: 0.0,
            status: "ok".into(),
        }),
    }
}

/// Inicia inferencia en tiempo real emitiendo tokens por el canal de eventos Tauri.
#[tauri::command]
pub async fn nano_chat_prompt_stream(
    app: AppHandle,
    service: State<'_, Arc<RuntimeService>>,
    input: ChatInput,
) -> Result<(), String> {
    let request_id = input
        .request_id
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string)
        .ok_or_else(|| "request_id es obligatorio para streaming".to_string())?;
    let model = input.model_path.unwrap_or_else(|| "qwen.gguf".to_string());
    let max_tokens = input.max_tokens.unwrap_or(512);

    let (response_rx, mut token_rx) = service
        .stream_prompt(&model, &input.prompt, max_tokens, input.temperature)
        .await
        .map_err(|e| {
            let message = format!("[Error Runtime] {}", e);
            emit_chat_error(&app, &request_id, message.clone());
            message
        })?;

    let app_clone = app.clone();
    let model_clone = model.clone();
    let stream_request_id = request_id.clone();

    tokio::spawn(async move {
        while let Some((token, prob)) = token_rx.recv().await {
            let _ = app_clone.emit(
                "chat-token",
                TokenEventPayload {
                    request_id: stream_request_id.clone(),
                    token,
                    probability: prob,
                },
            );
        }

        match response_rx.await {
            Ok(Ok(resp)) => {
                let tok_s = resp.stats.as_ref().map(|s| s.decode_tok_s).unwrap_or(0.0);
                let total_tokens = resp
                    .stats
                    .as_ref()
                    .map(|s| s.total_tokens)
                    .unwrap_or(resp.tokens_generated);
                let _ = app_clone.emit(
                    "chat-done",
                    DoneEventPayload {
                        request_id: stream_request_id,
                        text: resp.text,
                        tok_s,
                        total_tokens,
                        model: model_clone,
                    },
                );
            }
            Ok(Err(e)) => {
                emit_chat_error(
                    &app_clone,
                    &stream_request_id,
                    format!("[Error Runtime] {}", e),
                );
            }
            Err(e) => {
                emit_chat_error(
                    &app_clone,
                    &stream_request_id,
                    format!("Canal de respuesta abortado: {}", e),
                );
            }
        }
    });

    Ok(())
}
