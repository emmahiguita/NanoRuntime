//! Manejadores HTTP para NanoRuntime Web.
//!
//! Procesa las peticiones GET/POST, aplica validaciones de tamaño,
//! maneja timeouts contra DoS y sirve la interfaz web Sovereign Terminal.

use std::collections::HashMap;
use std::io::{BufRead, BufReader, Read, Write};
use std::net::TcpStream;
use std::path::PathBuf;
use std::sync::Arc;

use crate::state::{ChatRequest, ChatResponse, InferenceError, ServerState, StatusResponse};

pub fn cors_origin() -> &'static str {
    static CORS: std::sync::OnceLock<&str> = std::sync::OnceLock::new();
    CORS.get_or_init(|| {
        let origin =
            std::env::var("NANO_CORS_ORIGIN").unwrap_or_else(|_| "http://127.0.0.1".to_string());
        Box::leak(origin.into_boxed_str())
    })
}

pub fn send_response(mut stream: TcpStream, status: &str, body: &str, content_type: &str) {
    let response = format!(
        "HTTP/1.1 {}\r\nContent-Type: {}\r\nContent-Length: {}\r\nAccess-Control-Allow-Origin: {}\r\n\r\n{}",
        status, content_type, body.len(), cors_origin(), body
    );
    let _ = stream.write_all(response.as_bytes());
    let _ = stream.flush();
}

pub fn send_json(stream: TcpStream, status: &str, value: &impl serde::Serialize) {
    let body = serde_json::to_string(value).unwrap_or_else(|_| "{}".to_string());
    send_response(stream, status, &body, "application/json");
}

/// Localiza y sirve el archivo HTML de la terminal web buscando en rutas canónicas relativas.
pub fn serve_html(stream: TcpStream) {
    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let candidates = [
        manifest_dir.join("../../../docs/nanortime_terminal.html"),
        manifest_dir.join("../../docs/nanortime_terminal.html"),
        manifest_dir.join("../docs/nanortime_terminal.html"),
        PathBuf::from("docs/nanortime_terminal.html"),
    ];

    let mut found_html = None;
    for candidate in &candidates {
        if candidate.exists() {
            if let Ok(content) = std::fs::read_to_string(candidate) {
                found_html = Some(content);
                break;
            }
        }
    }

    let html = found_html.unwrap_or_else(|| {
        "<html><body><h1>NanoRuntime Web</h1><p>Interfaz nanortime_terminal.html no encontrada.</p></body></html>".to_string()
    });

    send_response(stream, "200 OK", &html, "text/html");
}

pub fn handle_connection(mut stream: TcpStream, state: &Arc<ServerState>) {
    let _ = stream.set_read_timeout(Some(std::time::Duration::from_secs(30)));
    let mut reader = BufReader::new(&mut stream);
    let mut request_line = String::new();
    if reader.read_line(&mut request_line).is_err() {
        return;
    }

    let mut headers = HashMap::new();
    loop {
        let mut line = String::new();
        if reader.read_line(&mut line).is_err() || line == "\r\n" || line == "\n" {
            break;
        }
        if let Some((k, v)) = line.split_once(':') {
            headers.insert(k.trim().to_lowercase(), v.trim().to_string());
        }
    }

    let parts: Vec<&str> = request_line.split_whitespace().collect();
    if parts.len() < 2 {
        return;
    }
    let method = parts[0];
    let path = parts[1];

    match (method, path) {
        ("GET", "/") => serve_html(stream),
        ("GET", "/api/status") => {
            let (model_status, model_error) = state.model_connection();
            let status = StatusResponse {
                status: "running".to_string(),
                model: state.model_path.clone(),
                model_status,
                model_error,
                ram_available_mb: read_ram_mb(),
                message: "NanoRuntime web server activo".to_string(),
            };
            send_json(stream, "200 OK", &status);
        }
        ("POST", "/api/chat") => {
            let content_length = headers
                .get("content-length")
                .and_then(|v| v.parse::<usize>().ok())
                .unwrap_or(0);

            const MAX_BODY: usize = 64 * 1024;
            if content_length > MAX_BODY {
                send_json(
                    stream,
                    "413 Payload Too Large",
                    &ChatResponse::error("Petición demasiado larga (máx 64 KB)"),
                );
                return;
            }

            let mut body = vec![0u8; content_length];
            if content_length > 0 && reader.read_exact(&mut body).is_err() {
                send_json(
                    stream,
                    "400 Bad Request",
                    &ChatResponse::error("Error leyendo cuerpo de petición"),
                );
                return;
            }

            let req: ChatRequest = match serde_json::from_slice(&body) {
                Ok(request) => request,
                Err(error) => {
                    send_json(
                        stream,
                        "400 Bad Request",
                        &ChatResponse::error(format!("JSON inválido: {}", error)),
                    );
                    return;
                }
            };

            if req.prompt.trim().is_empty() {
                send_json(
                    stream,
                    "400 Bad Request",
                    &ChatResponse::error("Prompt vacío"),
                );
                return;
            }

            const MAX_HISTORY_MESSAGES: usize = 24;
            if req.history.len() > MAX_HISTORY_MESSAGES {
                send_json(
                    stream,
                    "400 Bad Request",
                    &ChatResponse::error("El historial admite máximo 24 mensajes"),
                );
                return;
            }

            if req.history.iter().any(|message| {
                !matches!(message.role.as_str(), "user" | "assistant")
                    || message.content.trim().is_empty()
            }) {
                send_json(
                    stream,
                    "400 Bad Request",
                    &ChatResponse::error("Historial inválido"),
                );
                return;
            }

            if req
                .session_id
                .as_ref()
                .is_some_and(|session_id| session_id.len() > 128)
            {
                send_json(
                    stream,
                    "400 Bad Request",
                    &ChatResponse::error("session_id demasiado largo"),
                );
                return;
            }

            const MAX_TOKENS: usize = 4096;
            if req.max_tokens == 0 || req.max_tokens > MAX_TOKENS {
                send_json(
                    stream,
                    "400 Bad Request",
                    &ChatResponse::error("max_tokens debe estar entre 1 y 4096"),
                );
                return;
            }

            let ChatRequest {
                prompt,
                max_tokens,
                history,
                session_id,
            } = req;

            match state.run_inference(&prompt, max_tokens, history, session_id) {
                Ok(result) => send_json(stream, "200 OK", &result),
                Err(InferenceError::Busy) => send_json(
                    stream,
                    "503 Service Unavailable",
                    &ChatResponse::error("Runtime ocupado; intenta nuevamente"),
                ),
                Err(InferenceError::Unavailable(message)) => send_json(
                    stream,
                    "500 Internal Server Error",
                    &ChatResponse::error(format!("[Error Runtime] {}", message)),
                ),
            }
        }
        _ => send_response(stream, "404 Not Found", "Not found", "text/plain"),
    }
}

pub fn read_ram_mb() -> u64 {
    #[cfg(target_os = "linux")]
    {
        if let Ok(contents) = std::fs::read_to_string("/proc/meminfo") {
            for line in contents.lines() {
                if line.starts_with("MemAvailable:") {
                    if let Some(kb) = line.split_whitespace().nth(1) {
                        if let Ok(kb) = kb.parse::<u64>() {
                            return kb / 1024;
                        }
                    }
                }
            }
        }
    }
    0
}
