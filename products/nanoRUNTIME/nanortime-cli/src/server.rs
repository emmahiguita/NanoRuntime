//! NanoAI HTTP+SSE Server — Backend for Flutter, HTML terminal, and Web UIs.
//!
//! Provides:
//!   POST /completion   — SSE streaming (llama.cpp API compatible)
//!   POST /api/chat     — JSON request/response (legacy web UI)
//!   GET  /api/status   — Runtime status

use std::io::{BufRead, BufReader, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::Arc;

use nanortime_core::NanoRuntime;

/// Starts the HTTP+SSE server. Blocks forever.
pub fn run_server(runtime: &Arc<NanoRuntime>, bind_addr: &str, port: u16) {
    let bind_host = std::env::var("NANO_BIND_ADDR")
        .unwrap_or_else(|_| bind_addr.to_string());
    let full_addr = format!("{}:{}", bind_host, port);
    let listener = TcpListener::bind(&full_addr)
        .unwrap_or_else(|e| panic!("Failed to bind {}: {}", full_addr, e));

    println!("NanoAI Server listening on http://{}", full_addr);
    if bind_host == "0.0.0.0" {
        println!("  ⚠ Binding to 0.0.0.0 — accessible from any device on the network.");
        println!("    Set NANO_BIND_ADDR=127.0.0.1 to restrict to localhost.");
    }
    println!("  Completion (SSE):  POST /completion");
    println!("  Chat API:          POST /api/chat");
    println!("  Status:            GET  /api/status");

    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                let runtime = Arc::clone(runtime);
                let _ = stream.set_read_timeout(Some(std::time::Duration::from_secs(30)));
                std::thread::spawn(move || {
                    handle_http(stream, &runtime);
                });
            }
            Err(e) => eprintln!("Connection error: {}", e),
        }
    }
}

fn cors_origin() -> &'static str {
    // Box::leak is acceptable here: the string lives for the server's lifetime
    // and is tiny (~30 bytes). Freed when the process exits.
    static CORS: std::sync::OnceLock<&str> = std::sync::OnceLock::new();
    CORS.get_or_init(|| {
        let origin = std::env::var("NANO_CORS_ORIGIN").unwrap_or_else(|_| {
            tracing::warn!("NANO_CORS_ORIGIN not set, defaulting to '*'. This allows any origin to access the API.");
            "*".to_string()
        });
        Box::leak(origin.into_boxed_str())
    })
}

/// Writes data to the TCP stream. Returns `true` if the write succeeded,
/// `false` if the client disconnected or the write failed (error is logged).
/// Callers should stop sending data after a `false` return — further writes
/// will also fail and waste CPU on the SSE/token-generation hot path.
fn write_all_or_log(stream: &mut TcpStream, data: &[u8]) -> bool {
    match stream.write_all(data) {
        Ok(()) => true,
        Err(e) => {
            tracing::warn!("Failed to write to TCP stream (client likely disconnected): {}", e);
            false
        }
    }
}

fn send_json(stream: &mut TcpStream, status: &str, body: &str) {
    let response = format!(
        "HTTP/1.1 {}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nAccess-Control-Allow-Origin: {}\r\nConnection: close\r\n\r\n{}",
        status, body.len(), cors_origin(), body
    );
    write_all_or_log(stream, response.as_bytes());
    let _ = stream.flush();
}

fn read_body_bytes(reader: &mut BufReader<&mut TcpStream>, headers: &std::collections::HashMap<String, String>) -> Vec<u8> {
    let content_length = headers
        .get("content-length")
        .and_then(|v| v.parse::<usize>().ok())
        .unwrap_or(0)
        .min(65536); // 64KB max body
    let mut body = vec![0u8; content_length];
    if content_length > 0 {
        if let Err(e) = reader.read_exact(&mut body) {
            // Client sent fewer bytes than Content-Length claimed.
            // Body will contain partial data — downstream JSON parsing
            // will fail with a descriptive error. This is better than
            // silently processing a half-initialized buffer.
            tracing::warn!(
                "Failed to read request body (expected {} bytes): {} — partial body",
                content_length, e
            );
        }
    }
    body
}

fn run_async<F, T>(f: F) -> T
where
    F: std::future::Future<Output = T>,
{
    tokio::runtime::Builder::new_current_thread()
        .enable_time()
        .build()
        .unwrap()
        .block_on(f)
}

/// POST /completion — SSE streaming compatible with llama.cpp HTTP API.
fn handle_completion_sse(
    mut stream: &mut TcpStream,
    body: &[u8],
    runtime: &NanoRuntime,
) {

    #[derive(serde::Deserialize)]
    #[allow(dead_code)]
    struct CompletionReq {
        prompt: String,
        #[serde(default = "default_n_predict")]
        n_predict: usize,
        #[serde(default)]
        temperature: f32,
    }
    fn default_n_predict() -> usize { 512 }

    let req: CompletionReq = match serde_json::from_slice(&body) {
        Ok(r) => r,
        Err(_) => {
            send_json(&mut stream, "400 Bad Request", r#"{"error":"Invalid JSON"}"#);
            return;
        }
    };

    if req.prompt.is_empty() {
        send_json(&mut stream, "400 Bad Request", r#"{"error":"Empty prompt"}"#);
        return;
    }

    // SSE headers — abort if client already disconnected
    if !write_all_or_log(
        stream,
        format!(
            "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\nAccess-Control-Allow-Origin: {}\r\nConnection: keep-alive\r\n\r\n",
            cors_origin()
        ).as_bytes()
    ) {
        return; // Client disconnected before we could send headers
    }
    if let Err(e) = stream.flush() {
        tracing::warn!("SSE header flush failed: {}", e);
        return;
    }

    let request = nanortime_core::UserRequest {
        prompt: req.prompt,
        context: None,
        history: None,
    };

    let result = run_async(async {
        let (_, mut rx) = runtime.process_request_streaming(request).await
            .map_err(|e| format!("{}", e))?;
        // Receive tokens within the runtime — the forwarder task runs here.
        // Break the loop on write failure: the client disconnected, and
        // further token generation is wasted compute.
        while let Some((token, _prob)) = rx.recv().await {
            let json = serde_json::json!({"content": token, "stop": false});
            if !write_all_or_log(&mut stream, format!("data: {}\n\n", json).as_bytes()) {
                break;
            }
            if let Err(e) = stream.flush() {
                tracing::warn!("SSE token flush failed (client disconnected): {}", e);
                break;
            }
        }
        // Only send stop event if client is still connected
        if write_all_or_log(&mut stream, b"data: {\"content\":\"\",\"stop\":true}\n\n") {
            let _ = stream.flush(); // Best-effort flush for stop event
        }
        Ok::<_, String>(())
    });

    if let Err(e) = result {
        let json = serde_json::json!({"content": format!("[Error: {}]", e), "stop": true});
        write_all_or_log(&mut stream, format!("data: {}\n\n", json).as_bytes());
        let _ = stream.flush(); // Best-effort: client may already be gone
    }
}

/// POST /api/chat — Legacy JSON API.
fn handle_chat_json(
    mut stream: &mut TcpStream,
    body: &[u8],
    runtime: &NanoRuntime,
) {

    #[derive(serde::Deserialize)]
    #[allow(dead_code)]
    struct ChatReq {
        prompt: String,
        #[serde(default = "default_max_tokens")]
        max_tokens: usize,
    }
    fn default_max_tokens() -> usize { 150 }

    let req: ChatReq = match serde_json::from_slice(&body) {
        Ok(r) => r,
        Err(_) => {
            send_json(&mut stream, "400 Bad Request", r#"{"error":"Invalid JSON"}"#);
            return;
        }
    };

    let request = nanortime_core::UserRequest {
        prompt: req.prompt,
        context: None,
        history: None,
    };

    let response = run_async(async {
        runtime.process_request(request).await
    });

    let json_body = match response {
        Ok(r) => serde_json::json!({
            "response": r.text,
            "tier": r.tier_used,
            "confidence": r.confidence,
        }).to_string(),
        Err(e) => serde_json::json!({
            "response": format!("[Error: {}]", e),
            "tier": "error",
            "confidence": serde_json::Value::Null,
        }).to_string(),
    };

    send_json(&mut stream, "200 OK", &json_body);
}

/// GET /api/status — Runtime info.
fn handle_status(mut stream: &mut TcpStream, _runtime: &NanoRuntime) {
    let json = serde_json::json!({
        "status": "running",
        "tier": "local",
        "message": "NanoAI HTTP+SSE server active",
    }).to_string();
    send_json(&mut stream, "200 OK", &json);
}

fn handle_http(mut stream: TcpStream, runtime: &NanoRuntime) {
    let mut request_line = String::new();
    {
        let mut reader = BufReader::new(&mut stream);
        if reader.read_line(&mut request_line).is_err() {
            return;
        }
    }

    let mut headers = std::collections::HashMap::new();
    {
        let mut reader = BufReader::new(&mut stream);
        loop {
            let mut line = String::new();
            if reader.read_line(&mut line).is_err() || line == "\r\n" || line == "\n" {
                break;
            }
            if let Some((k, v)) = line.split_once(':') {
                headers.insert(k.trim().to_lowercase(), v.trim().to_string());
            }
        }
    }

    let parts: Vec<&str> = request_line.split_whitespace().collect();
    if parts.len() < 2 {
        return;
    }
    let method = parts[0];
    let path = parts[1];

    // Read body (drop reader before passing stream to handler)
    let body = {
        let mut reader = BufReader::new(&mut stream);
        read_body_bytes(&mut reader, &headers)
    };

    match (method, path) {
        ("POST", "/completion") => handle_completion_sse(&mut stream, &body, runtime),
        ("POST", "/api/chat") => handle_chat_json(&mut stream, &body, runtime),
        ("GET", "/api/status") => handle_status(&mut stream, runtime),
        _ => {
            write_all_or_log(&mut stream, b"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
        }
    }
}
