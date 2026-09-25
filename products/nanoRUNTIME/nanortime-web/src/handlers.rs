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
            std::env::var("NANO_CORS_ORIGIN").unwrap_or_else(|_| "*".to_string());
        Box::leak(origin.into_boxed_str())
    })
}

pub fn send_response_bytes(mut stream: TcpStream, status: &str, body: &[u8], content_type: &str) {
    let header = format!(
        "HTTP/1.1 {}\r\nContent-Type: {}\r\nContent-Length: {}\r\nAccess-Control-Allow-Origin: {}\r\nAccess-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type, Authorization\r\n\r\n",
        status, content_type, body.len(), cors_origin()
    );
    let _ = stream.write_all(header.as_bytes());
    let _ = stream.write_all(body);
    let _ = stream.flush();
}

pub fn send_response(stream: TcpStream, status: &str, body: &str, content_type: &str) {
    send_response_bytes(stream, status, body.as_bytes(), content_type);
}

pub fn send_json(stream: TcpStream, status: &str, value: &impl serde::Serialize) {
    let body = serde_json::to_string(value).unwrap_or_else(|_| "{}".to_string());
    send_response(stream, status, &body, "application/json");
}

fn get_ui_dir() -> PathBuf {
    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let candidates = [
        manifest_dir.join("../../nanoDESKTOP/ui"),
        PathBuf::from("products/nanoDESKTOP/ui"),
        PathBuf::from("nanoDESKTOP/ui"),
        manifest_dir.join("../../../nanoDESKTOP/ui"),
    ];

    for candidate in &candidates {
        if candidate.join("index.html").is_file() {
            return candidate.clone();
        }
    }

    PathBuf::from("products/nanoDESKTOP/ui")
}

fn mime_type_for(path: &str) -> &'static str {
    if path.ends_with(".html") {
        "text/html; charset=utf-8"
    } else if path.ends_with(".css") {
        "text/css; charset=utf-8"
    } else if path.ends_with(".js") || path.ends_with(".mjs") {
        "application/javascript; charset=utf-8"
    } else if path.ends_with(".json") {
        "application/json; charset=utf-8"
    } else if path.ends_with(".svg") {
        "image/svg+xml"
    } else if path.ends_with(".png") {
        "image/png"
    } else if path.ends_with(".jpg") || path.ends_with(".jpeg") {
        "image/jpeg"
    } else if path.ends_with(".ico") {
        "image/x-icon"
    } else if path.ends_with(".woff2") {
        "font/woff2"
    } else if path.ends_with(".woff") {
        "font/woff"
    } else if path.ends_with(".ttf") {
        "font/ttf"
    } else {
        "application/octet-stream"
    }
}

pub fn serve_static_file(stream: TcpStream, request_path: &str) {
    let clean = request_path.trim_start_matches('/');
    if clean.contains("..") {
        send_response(stream, "403 Forbidden", "Acceso denegado", "text/plain");
        return;
    }

    let ui_dir = get_ui_dir();
    let target = if clean.is_empty() || clean == "index.html" {
        ui_dir.join("index.html")
    } else {
        ui_dir.join(clean)
    };

    if target.is_file() {
        match std::fs::read(&target) {
            Ok(bytes) => {
                let mime = mime_type_for(&target.to_string_lossy());
                send_response_bytes(stream, "200 OK", &bytes, mime);
            }
            Err(_) => {
                send_response(stream, "500 Internal Server Error", "Error de lectura", "text/plain");
            }
        }
    } else {
        send_response(stream, "404 Not Found", "Archivo no encontrado", "text/plain");
    }
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
    let raw_path = parts[1];
    let path = raw_path.split('?').next().unwrap_or(raw_path);

    if method == "OPTIONS" {
        send_response(stream, "204 No Content", "", "text/plain");
        return;
    }

    match (method, path) {
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
        ("GET", _) => serve_static_file(stream, path),
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
