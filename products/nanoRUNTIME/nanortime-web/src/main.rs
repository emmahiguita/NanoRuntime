//! Nano Runtime HTTP Server — Interfaz web para el motor.
//!
//! Expone el runtime como API REST para que la interfaz web
//! (`docs/nanortime_terminal.html`) haga preguntas al motor real.
//!
//! Endpoints:
//!   GET  /                 → Sirve la interfaz HTML
//!   POST /api/chat         → Envía una pregunta, recibe respuesta
//!   GET  /api/status       → Estado del runtime (RAM, modelo, tok/s)
//!
//! Uso:
//!   nanortime-web --model qwen.gguf --port 8080
//!
//! Luego abre http://localhost:8080 en el navegador.
//! Para usar desde el móvil: http://IP_DEL_PC:8080 (misma red WiFi).

use std::collections::HashMap;
use std::io::{BufRead, BufReader, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::Arc;
use std::sync::Mutex;

// ── Estado compartido del runtime ────────────────────────────────────

/// Petición de chat desde la web.
#[derive(serde::Deserialize)]
struct ChatRequest {
    prompt: String,
    #[serde(default = "default_max_tokens")]
    max_tokens: usize,
}

fn default_max_tokens() -> usize {
    150
}

/// Respuesta del chat.
#[derive(serde::Serialize)]
struct ChatResponse {
    response: String,
    tok_s: f64,
    confidence: f64,
}

/// Estado del runtime.
#[derive(serde::Serialize)]
struct StatusResponse {
    status: String,
    model: String,
    ram_available_mb: u64,
    message: String,
}

/// Estado compartido del servidor.
struct ServerState {
    model_path: String,
    last_tok_s: Mutex<f64>,
    last_confidence: Mutex<f64>,
}

impl ServerState {
    fn new(model_path: &str) -> Self {
        Self {
            model_path: model_path.to_string(),
            last_tok_s: Mutex::new(0.0),
            last_confidence: Mutex::new(0.0),
        }
    }

    /// Ejecuta una consulta con el runtime.
    ///
    /// Intenta usar el runtime real; si no está disponible (modo dev),
    /// responde con un mensaje claro. La integración completa usa el
    /// ModelManager del runtime.
    fn run_inference(&self, prompt: &str, max_tokens: usize) -> ChatResponse {
        // ── Integración con el runtime real ──────────────────────
        // En producción esto llama a NanoRuntime::process_request().
        // Aquí documentamos el punto de integración exacto.
        let result = nanortime_core::cli_inference_bridge::run_single(
            &self.model_path,
            prompt,
            max_tokens,
            0.0, // temperature determinista
        );

        match result {
            Ok(single) => {
                if let Ok(mut tok) = self.last_tok_s.lock() {
                    *tok = single.tok_s;
                }
                if let Ok(mut conf) = self.last_confidence.lock() {
                    *conf = single.confidence;
                }
                ChatResponse {
                    response: single.text,
                    tok_s: single.tok_s,
                    confidence: single.confidence,
                }
            }
            Err(e) => ChatResponse {
                response: format!("[Error] No se pudo generar respuesta: {}", e),
                tok_s: 0.0,
                confidence: 0.0,
            },
        }
    }
}

// ── HTTP helpers ─────────────────────────────────────────────────────

fn cors_origin() -> &'static str {
    static CORS: std::sync::OnceLock<&str> = std::sync::OnceLock::new();
    CORS.get_or_init(|| {
        let origin = std::env::var("NANO_CORS_ORIGIN").unwrap_or_else(|_| {
            eprintln!("[warn] NANO_CORS_ORIGIN not set, defaulting to '*'. This allows any origin to access the API.");
            "*".to_string()
        });
        Box::leak(origin.into_boxed_str())
    })
}

fn send_response(mut stream: TcpStream, status: &str, body: &str, content_type: &str) {
    let response = format!(
        "HTTP/1.1 {}\r\nContent-Type: {}\r\nContent-Length: {}\r\nAccess-Control-Allow-Origin: {}\r\n\r\n{}",
        status,
        content_type,
        body.len(),
        cors_origin(),
        body
    );
    if let Err(e) = stream.write_all(response.as_bytes()) {
        eprintln!("[warn] Failed to write HTTP response: {}", e);
    }
    let _ = stream.flush();
}

fn send_json(stream: TcpStream, status: &str, value: &impl serde::Serialize) {
    let body = serde_json::to_string(value).unwrap_or_else(|_| "{}".to_string());
    send_response(stream, status, &body, "application/json");
}

fn serve_html(stream: TcpStream) {
    // Cargar la interfaz desde docs/nanortime_terminal.html
    let path = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../docs/nanortime_terminal.html");
    let html = std::fs::read_to_string(&path).unwrap_or_else(|_| {
        "<html><body><h1>NanoRuntime Web</h1><p>Interfaz no encontrada</p></body></html>"
            .to_string()
    });
    send_response(stream, "200 OK", &html, "text/html");
}

use std::path::PathBuf;

// ── Main ─────────────────────────────────────────────────────────────

fn handle_connection(mut stream: TcpStream, state: &Arc<ServerState>) {
    // ── Anti-DoS: read timeout prevents slow clients from holding threads ──
    let _ = stream.set_read_timeout(Some(std::time::Duration::from_secs(30)));
    let mut reader = BufReader::new(&mut stream);
    let mut request_line = String::new();
    if reader.read_line(&mut request_line).is_err() {
        return;
    }

    // Leer headers
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

    // Parsear método y ruta
    let parts: Vec<&str> = request_line.split_whitespace().collect();
    if parts.len() < 2 {
        return;
    }
    let method = parts[0];
    let path = parts[1];

    match (method, path) {
        ("GET", "/") => serve_html(stream),
        ("GET", "/api/status") => {
            let status = StatusResponse {
                status: "running".to_string(),
                model: state.model_path.clone(),
                ram_available_mb: read_ram_mb(),
                message: "NanoRuntime web server activo".to_string(),
            };
            send_json(stream, "200 OK", &status);
        }
        ("POST", "/api/chat") => {
            // Leer body
            let content_length = headers
                .get("content-length")
                .and_then(|v| v.parse::<usize>().ok())
                .unwrap_or(0);

            // ── Seguridad: límite máximo de body (4 KB) ─────────
            // Evita DoS con prompts gigantes. Un prompt de chat
            // razonable nunca excede 4 KB (~1000 tokens).
            const MAX_BODY: usize = 4096;
            if content_length > MAX_BODY {
                send_json(
                    stream,
                    "413 Payload Too Large",
                    &ChatResponse {
                        response: "Prompt demasiado largo (máx 4 KB)".to_string(),
                        tok_s: 0.0,
                        confidence: 0.0,
                    },
                );
                return;
            }

            let mut body = vec![0u8; content_length];
            if content_length > 0 {
                if let Err(e) = reader.read_exact(&mut body) {
                    eprintln!(
                        "[nanortime-web] Failed to read request body ({} bytes): {}",
                        content_length, e
                    );
                    send_json(
                        stream,
                        "400 Bad Request",
                        &ChatResponse {
                            response: format!("Error leyendo cuerpo de la petición: {}", e),
                            tok_s: 0.0,
                            confidence: 0.0,
                        },
                    );
                    return;
                }
            }

            let chat_req: ChatRequest = serde_json::from_slice(&body).unwrap_or(ChatRequest {
                prompt: String::new(),
                max_tokens: default_max_tokens(),
            });

            if chat_req.prompt.trim().is_empty() {
                send_json(
                    stream,
                    "400 Bad Request",
                    &ChatResponse {
                        response: "Prompt vacío".to_string(),
                        tok_s: 0.0,
                        confidence: 0.0,
                    },
                );
                return;
            }

            let result = state.run_inference(&chat_req.prompt, chat_req.max_tokens);
            send_json(stream, "200 OK", &result);
        }
        _ => send_response(stream, "404 Not Found", "Not found", "text/plain"),
    }
}

fn read_ram_mb() -> u64 {
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

/// CLI simple sin clap para no añadir dependencias.
fn main() {
    let args: Vec<String> = std::env::args().collect();
    let mut model = "qwen.gguf".to_string();
    let mut port = 8080u16;

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--model" | "-m" => {
                if i + 1 < args.len() {
                    model = args[i + 1].clone();
                    i += 1;
                }
            }
            "--port" | "-p" if i + 1 < args.len() => {
                port = args[i + 1].parse().unwrap_or(8080);
                i += 1;
            }
            _ => {}
        }
        i += 1;
    }

    let bind_host = std::env::var("NANO_BIND_ADDR").unwrap_or_else(|_| "127.0.0.1".to_string());
    let bind_addr = format!("{}:{}", bind_host, port);
    println!("NanoRuntime Web Server");
    println!("  Model: {}", model);
    println!("  URL:   http://{}", bind_addr);
    if bind_host == "0.0.0.0" {
        println!("  ⚠ Binding to 0.0.0.0 — accessible from any device on the network.");
        println!("    Set NANO_BIND_ADDR=127.0.0.1 to restrict to localhost.");
    }
    println!();

    let state = Arc::new(ServerState::new(&model));
    let listener = TcpListener::bind(&bind_addr)
        .unwrap_or_else(|e| panic!("No se pudo bindear {}: {}", bind_addr, e));

    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                let state = Arc::clone(&state);
                // NOTE: unbounded thread spawn per connection. For production,
                // use a thread pool (e.g. rayon) or an async runtime (tokio) with
                // connection limit. The 30s read_timeout above mitigates the worst
                // slow-loris case.
                std::thread::spawn(move || {
                    handle_connection(stream, &state);
                });
            }
            Err(e) => eprintln!("Error de conexión: {}", e),
        }
    }
}
