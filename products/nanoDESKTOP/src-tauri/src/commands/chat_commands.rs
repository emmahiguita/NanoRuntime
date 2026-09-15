use serde::{Deserialize, Serialize};

#[derive(Debug, Deserialize)]
pub struct ChatInput {
    pub prompt: String,
    pub model_path: Option<String>,
    pub max_tokens: Option<usize>,
}

#[derive(Debug, Serialize)]
pub struct ChatOutput {
    pub text: String,
    pub tok_s: f64,
    pub confidence: f64,
    pub status: String,
}

/// Ejecuta inferencia directa con nanortime-core sin simulación
#[tauri::command]
pub async fn nano_chat_prompt(input: ChatInput) -> Result<ChatOutput, String> {
    let prompt = input.prompt.trim();
    if prompt.is_empty() {
        return Err("El prompt no puede estar vacío".into());
    }

    let model = input
        .model_path
        .unwrap_or_else(|| "qwen.gguf".to_string());
    let max_tokens = input.max_tokens.unwrap_or(256);

    let result = nanortime_core::cli_inference_bridge::run_single(
        &model,
        prompt,
        max_tokens,
        0.0,
    );

    match result {
        Ok(single) => Ok(ChatOutput {
            text: single.text,
            tok_s: single.tok_s,
            confidence: single.confidence,
            status: "ok".into(),
        }),
        Err(e) => Ok(ChatOutput {
            text: format!("[Error Runtime] {}", e),
            tok_s: 0.0,
            confidence: 0.0,
            status: "error".into(),
        }),
    }
}
