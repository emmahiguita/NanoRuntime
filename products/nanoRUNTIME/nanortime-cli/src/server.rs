//! NanoAI HTTP+SSE Server — Backend for Flutter, HTML terminal, and Web UIs.
//!
//! Provides:
//!   GET  /health      — Liveness/readiness probe (model-independent)
//!   POST /completion  — SSE streaming or JSON (llama.cpp API compatible)
//!   POST /cancel      — Cancel an in-flight generation by `request_id`
//!   POST /api/chat    — JSON request/response (legacy web UI)
//!   GET  /api/status  — Runtime status
//!
//! Protocol contract:
//!   `/completion` body: `{prompt, n_predict?, temperature?, stream?, request_id?}`
//!   `stream: true` (default) sends SSE frames
//!     `data: {"content":"<token>","stop":false}` then a final
//!     `data: {"content":"","stop":true,"request_id":"...","cancelled":false}`
//!   `stream: false` sends a single JSON `{"content":"...","stop":true,"request_id":"..."}`
//!   SSE errors: `data: {"content":"[Error: ...]","stop":true}`
//!   JSON errors: `{"error":{"code":"...","message":"..."}}`
//!   A `request_id` is echoed in every terminal frame so clients can correlate
//!   a cancellation with the generation it targets. If omitted, the server
//!   assigns one (`req-<n>`).
//!
//! Cancellation semantics (honest): `/cancel` cuts the SSE stream and drops
//! the client-side token loop immediately — including during model prefill
//! (the stream-start future is raced against the cancel watch). The backing
//! inference task is not preempted mid-token by the engine (no abort hook
//! yet) — its output is discarded. The stream ends with `"cancelled":true`.

use std::collections::HashMap;
use std::io::{BufRead, BufReader, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Instant;

use nanortime_core::NanoRuntime;
use tokio::sync::watch;

/// Shared server state. Single source of truth for in-flight generations.
pub struct ServerState {
    /// `request_id` → cancel switch. The generation loop watches this; a
    /// `true` send cuts the SSE stream. Entry removed when generation ends.
    cancel_registry: Mutex<HashMap<String, watch::Sender<bool>>>,
    next_request_id: AtomicU64,
    started_at: Instant,
}

impl ServerState {
    pub fn new() -> Self {
        Self {
            cancel_registry: Mutex::new(HashMap::new()),
            next_request_id: AtomicU64::new(1),
            started_at: Instant::now(),
        }
    }

    fn new_request_id(&self) -> String {
        format!(
            "req-{}",
            self.next_request_id.fetch_add(1, Ordering::Relaxed)
        )
    }

    /// Poison-safe read of active generation count. A poisoned mutex means a
    /// handler panicked while holding the registry; the server keeps serving
    /// health probes rather than crashing the status thread.
    fn active_requests(&self) -> usize {
        self.cancel_registry
            .lock()
            .map(|m| m.len())
            .unwrap_or_else(|poisoned| poisoned.into_inner().len())
    }

    fn register(&self, request_id: &str) -> watch::Receiver<bool> {
        let (tx, rx) = watch::channel(false);
        match self.cancel_registry.lock() {
            Ok(mut m) => {
                m.insert(request_id.to_string(), tx);
            }
            Err(poisoned) => {
                poisoned.into_inner().insert(request_id.to_string(), tx);
            }
        }
        rx
    }

    fn unregister(&self, request_id: &str) {
        self.cancel_registry
            .lock()
            .map(|mut m| m.remove(request_id))
            .unwrap_or_else(|poisoned| poisoned.into_inner().remove(request_id));
    }

    fn signal_cancel(&self, request_id: &str) -> bool {
        let entry = self
            .cancel_registry
            .lock()
            .map(|mut m| m.remove(request_id))
            .unwrap_or_else(|poisoned| poisoned.into_inner().remove(request_id));
        match entry {
            Some(tx) => {
                // Best-effort: receiver may have already finished and dropped.
                let _ = tx.send(true);
                true
            }
            None => false,
        }
    }
}

/// Starts the HTTP+SSE server. Blocks forever.
///
/// `runtime: None` = model-free (flag `--no-model`): /health y /cancel
/// responden, /completion y /api/status devuelven 503 runtime_unavailable.
pub fn run_server(runtime: Option<Arc<NanoRuntime>>, bind_addr: &str, port: u16) {
    let bind_host = std::env::var("NANO_BIND_ADDR").unwrap_or_else(|_| bind_addr.to_string());
    let full_addr = format!("{}:{}", bind_host, port);
    // exit(1), no panic!: un panic dentro de la task de tokio NO mata el
    // proceso (tokio lo captura) y dejaría un nanortime vivo sin listener
    // (evidencia smoke Windows 2026-08-13: doble instancia → huérfano).
    let listener = match TcpListener::bind(&full_addr) {
        Ok(listener) => listener,
        Err(e) => {
            eprintln!("Failed to bind {}: {}", full_addr, e);
            std::process::exit(1);
        }
    };

    println!("NanoAI Server listening on http://{}", full_addr);
    if bind_host == "0.0.0.0" {
        println!("  ⚠ Binding to 0.0.0.0 — accessible from any device on the network.");
        println!("    Set NANO_BIND_ADDR=127.0.0.1 to restrict to localhost.");
    }
    println!("  Health:            GET  /health");
    println!("  Completion (SSE):  POST /completion");
    println!("  Cancel:            POST /cancel");
    println!("  Chat API:          POST /api/chat");
    println!("  Status:            GET  /api/status");

    let state = Arc::new(ServerState::new());
    serve(listener, runtime, &state);
}

/// Accept loop. Separated from `run_server` so tests can drive it on an
/// ephemeral port with the same code path as production.
fn serve(listener: TcpListener, runtime: Option<Arc<NanoRuntime>>, state: &Arc<ServerState>) {
    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                let runtime = runtime.clone();
                let state = Arc::clone(state);
                let _ = stream.set_read_timeout(Some(std::time::Duration::from_secs(30)));
                std::thread::spawn(move || {
                    handle_http(stream, runtime.as_ref().map(|r| r.as_ref()), &state);
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
            tracing::warn!(
                "Failed to write to TCP stream (client likely disconnected): {}",
                e
            );
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

fn read_body_bytes(
    reader: &mut BufReader<&mut TcpStream>,
    headers: &HashMap<String, String>,
) -> Vec<u8> {
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
                content_length,
                e
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

/// GET /health — Liveness probe. Model-independent: answers as soon as the
/// server is bound, regardless of model load state. Honest fields only.
fn handle_health(stream: &mut TcpStream, state: &Arc<ServerState>) {
    tracing::info!("HTTP: /health handler, writing 200");
    let json = serde_json::json!({
        "status": "ok",
        "version": env!("CARGO_PKG_VERSION"),
        "uptime_seconds": state.started_at.elapsed().as_secs(),
        "active_requests": state.active_requests(),
    })
    .to_string();
    send_json(stream, "200 OK", &json);
    tracing::info!("HTTP: /health response written");
}

/// POST /cancel — Cancel an in-flight generation by `request_id`.
fn handle_cancel(stream: &mut TcpStream, body: &[u8], state: &Arc<ServerState>) {
    #[derive(serde::Deserialize)]
    struct CancelReq {
        request_id: String,
    }

    let req: CancelReq = match serde_json::from_slice(body) {
        Ok(r) => r,
        Err(_) => {
            send_json(
                stream,
                "400 Bad Request",
                r#"{"error":{"code":"invalid_json","message":"Invalid JSON"}}"#,
            );
            return;
        }
    };

    if state.signal_cancel(&req.request_id) {
        send_json(
            stream,
            "200 OK",
            &format!(r#"{{"cancelled":true,"request_id":"{}"}}"#, req.request_id),
        );
    } else {
        send_json(
            stream,
            "404 Not Found",
            &format!(
                r#"{{"error":{{"code":"unknown_request_id","message":"No in-flight generation with request_id {}"}}}}"#,
                req.request_id
            ),
        );
    }
}

/// POST /completion — SSE streaming or JSON, compatible with llama.cpp HTTP API.
fn handle_completion_sse(
    stream: &mut TcpStream,
    body: &[u8],
    runtime: &NanoRuntime,
    state: &Arc<ServerState>,
) {
    #[derive(serde::Deserialize)]
    #[allow(dead_code)]
    struct CompletionReq {
        prompt: String,
        #[serde(default = "default_n_predict")]
        n_predict: usize,
        #[serde(default)]
        temperature: f32,
        #[serde(default = "default_stream")]
        stream: bool,
        request_id: Option<String>,
    }
    fn default_n_predict() -> usize {
        512
    }
    fn default_stream() -> bool {
        true
    }

    let req: CompletionReq = match serde_json::from_slice(body) {
        Ok(r) => r,
        Err(_) => {
            send_json(
                stream,
                "400 Bad Request",
                r#"{"error":{"code":"invalid_json","message":"Invalid JSON"}}"#,
            );
            return;
        }
    };

    if req.prompt.is_empty() {
        send_json(
            stream,
            "400 Bad Request",
            r#"{"error":{"code":"empty_prompt","message":"Empty prompt"}}"#,
        );
        return;
    }

    let request_id = req.request_id.unwrap_or_else(|| state.new_request_id());

    let request = nanortime_core::UserRequest {
        prompt: req.prompt,
        context: None,
        history: None,
    };

    // ── Non-streaming: single JSON response ──────────────────────────
    if !req.stream {
        let result = run_async(async { runtime.process_request(request).await });
        let json_body = match result {
            Ok(r) => serde_json::json!({
                "content": r.text,
                "stop": true,
                "request_id": request_id,
            })
            .to_string(),
            Err(e) => serde_json::json!({
                "error": {"code": "generation_failed", "message": format!("{}", e)},
                "request_id": request_id,
            })
            .to_string(),
        };
        send_json(stream, "200 OK", &json_body);
        return;
    }

    // ── Streaming: SSE frames with cancellation watch ─────────────────
    let mut cancel_rx = state.register(&request_id);

    // SSE headers — abort if client already disconnected
    if !write_all_or_log(
        stream,
        format!(
            "HTTP/1.1 200 OK\r\nContent-Type: text/event-stream\r\nCache-Control: no-cache\r\nAccess-Control-Allow-Origin: {}\r\nConnection: keep-alive\r\n\r\n",
            cors_origin()
        ).as_bytes()
    ) {
        state.unregister(&request_id);
        return; // Client disconnected before we could send headers
    }
    if let Err(e) = stream.flush() {
        tracing::warn!("SSE header flush failed: {}", e);
        state.unregister(&request_id);
        return;
    }

    let result: Result<bool, String> = run_async(async {
        // Race the stream start (model prefill + first token) against the
        // cancel watch — a cancel during prefill must cut the stream too,
        // not only after the first token arrives.
        tokio::pin! {
            let start = runtime.process_request_streaming(request);
        }
        let mut rx = tokio::select! {
            res = &mut start => match res {
                Ok((_, rx)) => rx,
                Err(e) => return Err(format!("{}", e)),
            },
            changed = cancel_rx.changed() => {
                if changed.is_ok() && *cancel_rx.borrow() {
                    // Cancelled during prefill: no tokens were sent.
                    return Ok(true);
                }
                // Sender dropped without a signal (registry cleanup raced):
                // fall through and await the start future normally.
                match start.await {
                    Ok((_, rx)) => rx,
                    Err(e) => return Err(format!("{}", e)),
                }
            }
        };
        // Break the loop on write failure (client disconnected) or on a
        // cancel signal (POST /cancel). Further token generation is wasted
        // compute in both cases.
        let mut cancelled = false;
        loop {
            tokio::select! {
                token = rx.recv() => {
                    match token {
                        Some((token, _prob)) => {
                            let json = serde_json::json!({"content": token, "stop": false});
                            if !write_all_or_log(stream, format!("data: {}\n\n", json).as_bytes()) {
                                break;
                            }
                            if let Err(e) = stream.flush() {
                                tracing::warn!("SSE token flush failed (client disconnected): {}", e);
                                break;
                            }
                        }
                        None => break,
                    }
                }
                changed = cancel_rx.changed() => {
                    if changed.is_ok() && *cancel_rx.borrow() {
                        cancelled = true;
                        break;
                    }
                    // Sender dropped (registered cleanup ran elsewhere):
                    // treat as no-cancel and keep streaming.
                }
            }
        }
        // Only send stop event if client is still connected
        let stop_json = serde_json::json!({
            "content": "",
            "stop": true,
            "request_id": request_id,
            "cancelled": cancelled,
        });
        if write_all_or_log(stream, format!("data: {}\n\n", stop_json).as_bytes()) {
            let _ = stream.flush(); // Best-effort flush for stop event
        }
        Ok(cancelled)
    });

    state.unregister(&request_id);

    if let Err(e) = result {
        let json = serde_json::json!({"content": format!("[Error: {}]", e), "stop": true});
        write_all_or_log(stream, format!("data: {}\n\n", json).as_bytes());
        let _ = stream.flush(); // Best-effort: client may already be gone
    }
}

/// POST /api/chat — Legacy JSON API.
fn handle_chat_json(stream: &mut TcpStream, body: &[u8], runtime: &NanoRuntime) {
    #[derive(serde::Deserialize)]
    #[allow(dead_code)]
    struct ChatReq {
        prompt: String,
        #[serde(default = "default_max_tokens")]
        max_tokens: usize,
    }
    fn default_max_tokens() -> usize {
        150
    }

    let req: ChatReq = match serde_json::from_slice(body) {
        Ok(r) => r,
        Err(_) => {
            send_json(stream, "400 Bad Request", r#"{"error":"Invalid JSON"}"#);
            return;
        }
    };

    let request = nanortime_core::UserRequest {
        prompt: req.prompt,
        context: None,
        history: None,
    };

    let response = run_async(async { runtime.process_request(request).await });

    let json_body = match response {
        Ok(r) => serde_json::json!({
            "response": r.text,
            "tier": r.tier_used,
            "confidence": r.confidence,
        })
        .to_string(),
        Err(e) => serde_json::json!({
            "response": format!("[Error: {}]", e),
            "tier": "error",
            "confidence": serde_json::Value::Null,
        })
        .to_string(),
    };

    send_json(stream, "200 OK", &json_body);
}

/// GET /api/status — Runtime info.
fn handle_status(stream: &mut TcpStream, _runtime: &NanoRuntime, state: &Arc<ServerState>) {
    let json = serde_json::json!({
        "status": "running",
        "version": env!("CARGO_PKG_VERSION"),
        "tier": "local",
        "uptime_seconds": state.started_at.elapsed().as_secs(),
        "message": "NanoAI HTTP+SSE server active",
    })
    .to_string();
    send_json(stream, "200 OK", &json);
}

/// `runtime` is `Option` only so tests can exercise model-independent routes
/// (`/health`, `/cancel`, `/api/status`, 404) without loading a GGUF.
/// Production always passes `Some`.
fn handle_http(mut stream: TcpStream, runtime: Option<&NanoRuntime>, state: &Arc<ServerState>) {
    tracing::info!("HTTP: connection accepted, reading request");
    // Single BufReader for request line + headers + body. Using a second
    // BufReader here would silently drop bytes the first one read ahead.
    let mut reader = BufReader::new(&mut stream);
    let mut request_line = String::new();
    if reader.read_line(&mut request_line).is_err() {
        return;
    }
    tracing::info!("HTTP: request line: {:?}", request_line.trim_end());

    let mut headers = HashMap::new();
    loop {
        let mut line = String::new();
        if reader.read_line(&mut line).is_err() || line == "\r\n" || line == "\n" || line.is_empty()
        {
            break;
        }
        if let Some((k, v)) = line.split_once(':') {
            headers.insert(k.trim().to_lowercase(), v.trim().to_string());
        }
    }
    tracing::info!("HTTP: {} headers read", headers.len());

    let parts: Vec<&str> = request_line.split_whitespace().collect();
    if parts.len() < 2 {
        return;
    }
    let method = parts[0];
    let path = parts[1];

    let body = read_body_bytes(&mut reader, &headers);
    drop(reader); // Release the &mut stream borrow before handlers use it

    match (method, path) {
        ("GET", "/health") => handle_health(&mut stream, state),
        ("POST", "/cancel") => handle_cancel(&mut stream, &body, state),
        ("GET", "/api/status") => match runtime {
            Some(rt) => handle_status(&mut stream, rt, state),
            None => send_json(
                &mut stream,
                "503 Service Unavailable",
                r#"{"error":{"code":"runtime_unavailable","message":"No runtime attached"}}"#,
            ),
        },
        ("POST", "/completion") => match runtime {
            Some(rt) => handle_completion_sse(&mut stream, &body, rt, state),
            None => send_json(
                &mut stream,
                "503 Service Unavailable",
                r#"{"error":{"code":"runtime_unavailable","message":"No runtime attached"}}"#,
            ),
        },
        ("POST", "/api/chat") => match runtime {
            Some(rt) => handle_chat_json(&mut stream, &body, rt),
            None => send_json(
                &mut stream,
                "503 Service Unavailable",
                r#"{"error":{"code":"runtime_unavailable","message":"No runtime attached"}}"#,
            ),
        },
        _ => {
            tracing::info!("HTTP: no route for {} {} → 404", method, path);
            write_all_or_log(
                &mut stream,
                b"HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n",
            );
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Builds a raw HTTP/1.1 request with correct Content-Length.
    fn http_request(method: &str, path: &str, body: &str) -> String {
        format!(
            "{} {} HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
            method,
            path,
            body.len(),
            body
        )
    }

    /// Sends the request through a real socket into `handle_http` (runtime
    /// `None`, so model-dependent routes answer 503) and returns
    /// (status line, body).
    fn drive(request: &str) -> (String, String) {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let addr = listener.local_addr().unwrap();
        let state = Arc::new(ServerState::new());
        let state2 = Arc::clone(&state);
        let handle = std::thread::spawn(move || {
            if let Ok((stream, _)) = listener.accept() {
                handle_http(stream, None, &state2);
            }
        });
        let mut client = TcpStream::connect(addr).unwrap();
        write_all_or_log(&mut client, request.as_bytes());
        client.shutdown(std::net::Shutdown::Write).unwrap();

        let mut reader = BufReader::new(&mut client);
        let mut status_line = String::new();
        reader.read_line(&mut status_line).unwrap();
        let mut content_length = 0usize;
        loop {
            let mut line = String::new();
            reader.read_line(&mut line).unwrap();
            if line == "\r\n" || line == "\n" || line.is_empty() {
                break;
            }
            if let Some((k, v)) = line.split_once(':') {
                if k.trim().to_lowercase() == "content-length" {
                    content_length = v.trim().parse().unwrap_or(0);
                }
            }
        }
        let mut buf = vec![0u8; content_length];
        if content_length > 0 {
            reader.read_exact(&mut buf).unwrap();
        }
        handle.join().unwrap();
        (status_line, String::from_utf8_lossy(&buf).to_string())
    }

    #[test]
    fn health_returns_ok_with_version_and_uptime() {
        let (status, body) = drive(&http_request("GET", "/health", ""));
        assert!(status.starts_with("HTTP/1.1 200"), "status was: {}", status);
        let json: serde_json::Value = serde_json::from_str(&body).unwrap();
        assert_eq!(json["status"], "ok");
        assert_eq!(json["version"], env!("CARGO_PKG_VERSION"));
        assert!(json["uptime_seconds"].is_u64());
        assert_eq!(json["active_requests"], 0);
    }

    #[test]
    fn cancel_unknown_request_returns_404() {
        let (status, body) = drive(&http_request("POST", "/cancel", r#"{"request_id":"nope"}"#));
        assert!(status.starts_with("HTTP/1.1 404"), "status was: {}", status);
        let json: serde_json::Value = serde_json::from_str(&body).unwrap();
        assert_eq!(json["error"]["code"], "unknown_request_id");
    }

    #[test]
    fn cancel_invalid_json_returns_400() {
        let (status, body) = drive(&http_request("POST", "/cancel", "not json!"));
        assert!(status.starts_with("HTTP/1.1 400"), "status was: {}", status);
        let json: serde_json::Value = serde_json::from_str(&body).unwrap();
        assert_eq!(json["error"]["code"], "invalid_json");
    }

    #[test]
    fn completion_without_runtime_returns_503() {
        let (status, body) = drive(&http_request("POST", "/completion", r#"{"prompt":"hola"}"#));
        assert!(status.starts_with("HTTP/1.1 503"), "status was: {}", status);
        let json: serde_json::Value = serde_json::from_str(&body).unwrap();
        assert_eq!(json["error"]["code"], "runtime_unavailable");
    }

    #[test]
    fn status_without_runtime_returns_503() {
        let (status, body) = drive(&http_request("GET", "/api/status", ""));
        assert!(status.starts_with("HTTP/1.1 503"), "status was: {}", status);
        let json: serde_json::Value = serde_json::from_str(&body).unwrap();
        assert_eq!(json["error"]["code"], "runtime_unavailable");
    }

    #[test]
    fn unknown_path_returns_404() {
        let (status, _) = drive(&http_request("GET", "/nope", ""));
        assert!(status.starts_with("HTTP/1.1 404"), "status was: {}", status);
    }

    #[test]
    fn drive_without_write_shutdown_like_curl() {
        // curl keeps the write side open while waiting for the response —
        // the server must answer from the buffered request alone.
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let addr = listener.local_addr().unwrap();
        let state = Arc::new(ServerState::new());
        let state2 = Arc::clone(&state);
        let handle = std::thread::spawn(move || {
            if let Ok((stream, _)) = listener.accept() {
                handle_http(stream, None, &state2);
            }
        });
        let mut client = TcpStream::connect(addr).unwrap();
        client
            .set_read_timeout(Some(std::time::Duration::from_secs(10)))
            .unwrap();
        write_all_or_log(&mut client, http_request("GET", "/health", "").as_bytes());
        // NOTE: no shutdown(Write) — exactly like curl
        let mut reader = BufReader::new(&mut client);
        let mut status_line = String::new();
        reader.read_line(&mut status_line).unwrap();
        assert!(
            status_line.starts_with("HTTP/1.1 200"),
            "status was: {}",
            status_line
        );
        handle.join().unwrap();
    }

    #[test]
    fn cancel_registry_roundtrip() {
        let state = ServerState::new();
        let rx = state.register("abc");
        assert_eq!(state.active_requests(), 1);
        assert!(state.signal_cancel("abc"));
        assert_eq!(state.active_requests(), 0);
        // watch::Receiver holds the last value even after the sender is
        // dropped (signal_cancel removes it from the registry)
        assert!(*rx.borrow());
        // Second cancel of same id: already consumed → not found
        assert!(!state.signal_cancel("abc"));
        state.unregister("abc");
        assert_eq!(state.active_requests(), 0);
    }
}
