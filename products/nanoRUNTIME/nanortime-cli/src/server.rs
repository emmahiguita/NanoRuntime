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
use std::sync::{Arc, Mutex, RwLock};
use std::time::{Duration, Instant};

use nanortime_core::NanoRuntime;
use tokio::sync::watch;

/// Shared server state. Single source of truth for in-flight generations.
pub struct ServerState {
    /// `request_id` → cancel switch. The generation loop watches this; a
    /// `true` send cuts the SSE stream. Entry removed when generation ends.
    cancel_registry: Mutex<HashMap<String, watch::Sender<bool>>>,
    /// `request_id` → `session_id`. Permite marcar el KV de la sesión
    /// correcta tras una cancelación (Gate R6). Entry eliminada al consumirse.
    session_registry: Mutex<HashMap<String, String>>,
    next_request_id: AtomicU64,
    started_at: Instant,
}

impl ServerState {
    pub fn new() -> Self {
        Self {
            cancel_registry: Mutex::new(HashMap::new()),
            session_registry: Mutex::new(HashMap::new()),
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

    /// Registra la sesión asociada a un request en vuelo.
    fn record_session(&self, request_id: &str, session_id: &str) {
        self.session_registry
            .lock()
            .map(|mut m| {
                m.insert(request_id.to_string(), session_id.to_string());
            })
            .unwrap_or_else(|poisoned| {
                poisoned
                    .into_inner()
                    .insert(request_id.to_string(), session_id.to_string());
            });
    }

    /// Toma (y elimina) la sesión asociada a un request_id, si existe.
    fn take_session(&self, request_id: &str) -> Option<String> {
        self.session_registry
            .lock()
            .map(|mut m| m.remove(request_id))
            .unwrap_or_else(|poisoned| poisoned.into_inner().remove(request_id))
    }
}

/// Estado del runtime visto por el server. Distingue explícitamente
/// "proceso vivo pero modelo cargando" de "modelo listo" y "carga fallida".
/// Gate R2 (liveness/readiness): /liveness es 200 siempre que el socket
/// responde; /readiness refleja este enum (503 LOADING / 200 READY / 500 FAILED).
#[derive(Clone)]
pub enum RuntimeSlot {
    /// Socket vivo, modelo aún cargando (readiness → 503 MODEL_LOADING).
    Loading,
    /// Modelo cargado y listo para inferir (readiness → 200 MODEL_READY).
    Ready(Arc<NanoRuntime>),
    /// La carga del modelo falló — causa real para diagnóstico (→ 500).
    Failed(String),
}

impl RuntimeSlot {
    fn runtime(&self) -> Option<Arc<NanoRuntime>> {
        match self {
            RuntimeSlot::Ready(rt) => Some(Arc::clone(rt)),
            _ => None,
        }
    }
    fn failure_reason(&self) -> Option<&str> {
        match self {
            RuntimeSlot::Failed(reason) => Some(reason),
            _ => None,
        }
    }
}

/// Starts the HTTP+SSE server. Blocks forever.
///
/// `runtime_slot` holds the runtime state. The socket binds IMMEDIATELY so
/// `/liveness` answers from second zero — the app never sees a dead engine
/// while a large GGUF is still loading on-device. `/readiness` reports the
/// explicit model state (LOADING/READY/FAILED). Model-dependent routes
/// (`/completion`, `/api/chat`) keep the SSE/connection open and emit
/// heartbeats while waiting (Gate R3), so a slow mobile load surfaces as
/// "esperando" on the client, not "desconectado".
pub fn run_server(runtime_slot: Arc<RwLock<RuntimeSlot>>, bind_addr: &str, port: u16) {
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
    println!("  Liveness:         GET  /liveness");
    println!("  Readiness:        GET  /readiness");
    println!("  Health:           GET  /health  (legacy alias de liveness)");
    println!("  Completion (SSE): POST /completion");
    println!("  Cancel:           POST /cancel");
    println!("  Chat API:         POST /api/chat");
    println!("  Status:           GET  /api/status");

    let state = Arc::new(ServerState::new());
    serve(listener, runtime_slot, &state);
}

/// Accept loop. Separated from `run_server` so tests can drive it on an
/// ephemeral port with the same code path as production.
fn serve(
    listener: TcpListener,
    runtime_slot: Arc<RwLock<RuntimeSlot>>,
    state: &Arc<ServerState>,
) {
    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                let runtime_slot = runtime_slot.clone();
                let state = Arc::clone(state);
                let _ = stream.set_read_timeout(Some(std::time::Duration::from_secs(30)));
                std::thread::spawn(move || {
                    handle_http(stream, &runtime_slot, &state);
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

/// Máximo tiempo que una ruta dependiente de modelo espera a que el GGUF
/// termine de cargar en el dispositivo antes de responder 503. Un móvil con
/// un GGUF de 2-3GB puede tardar 30-90s en cargar; el cliente Flutter lo ve
/// como "esperando" mientras tanto, nunca como "motor desconectado".
/// Sobrescribible vía NANO_MODEL_READY_TIMEOUT_SECS (usado por los tests
/// para forzar el 503 rápido sin cargar un GGUF).
fn model_ready_timeout() -> Duration {
    let secs = std::env::var("NANO_MODEL_READY_TIMEOUT_SECS")
        .ok()
        .and_then(|v| v.parse::<u64>().ok())
        .unwrap_or(180);
    Duration::from_secs(secs)
}

/// Espera a que el runtime esté disponible (modelo cargado) o devuelve el
/// error honesto de timeout/fallo. Se usa en /completion y /api/chat.
fn wait_runtime(
    slot: &RwLock<RuntimeSlot>,
    timeout: Duration,
) -> Result<Arc<NanoRuntime>, String> {
    let deadline = Instant::now() + timeout;
    loop {
        if let Ok(guard) = slot.read() {
            if let Some(rt) = guard.runtime() {
                return Ok(rt);
            }
            if let Some(reason) = guard.failure_reason() {
                return Err(format!(
                    "runtime_unavailable: la carga del modelo falló — {}",
                    reason
                ));
            }
        }
        if Instant::now() >= deadline {
            return Err(
                "runtime_unavailable: modelo no cargado (el motor sigue arrancando o no hay GGUF). Vuelve a intentar en unos segundos.".to_string(),
            );
        }
        std::thread::sleep(Duration::from_millis(100));
    }
}

/// Gate R2 — liveness: proceso/socket vivo. 200 siempre, sin dependencia
/// del modelo. El cliente Flutter lo usa para decidir si el motor existe.
fn handle_liveness(stream: &mut TcpStream, state: &Arc<ServerState>) {
    let json = serde_json::json!({
        "status": "ok",
        "version": env!("CARGO_PKG_VERSION"),
        "uptime_seconds": state.started_at.elapsed().as_secs(),
        "active_requests": state.active_requests(),
    })
    .to_string();
    send_json(stream, "200 OK", &json);
}

/// Gate R2 — readiness: modelo cargado? 503 LOADING / 200 READY / 500 FAILED.
/// Sin bloqueo: refleja el estado actual del slot (el modelo carga en
/// background; el cliente hace poll ligero o lee el evento SSE).
fn handle_readiness(
    stream: &mut TcpStream,
    runtime_slot: &RwLock<RuntimeSlot>,
    state: &Arc<ServerState>,
) {
    let guard = match runtime_slot.read() {
        Ok(g) => g,
        Err(_) => {
            send_json(
                stream,
                "500 Internal Server Error",
                r#"{"error":{"code":"lock_poisoned","message":"runtime slot poisoned"}}"#,
            );
            return;
        }
    };
    let uptime = state.started_at.elapsed().as_secs();
    match &*guard {
        RuntimeSlot::Loading => {
            let json = serde_json::json!({
                "status": "loading",
                "state": "MODEL_LOADING",
                "version": env!("CARGO_PKG_VERSION"),
                "uptime_seconds": uptime,
            })
            .to_string();
            send_json(stream, "503 Service Unavailable", &json);
        }
        RuntimeSlot::Ready(rt) => {
            let st = rt.status();
            let json = serde_json::json!({
                "status": "ok",
                "state": "MODEL_READY",
                "version": env!("CARGO_PKG_VERSION"),
                "uptime_seconds": uptime,
                "model_loaded": st.model_loaded,
                "model_size_mb": st.model_size_mb,
                "context_size": st.context_size,
            })
            .to_string();
            send_json(stream, "200 OK", &json);
        }
        RuntimeSlot::Failed(reason) => {
            let json = serde_json::json!({
                "status": "error",
                "state": "MODEL_FAILED",
                "version": env!("CARGO_PKG_VERSION"),
                "uptime_seconds": uptime,
                "reason": reason,
            })
            .to_string();
            send_json(stream, "500 Internal Server Error", &json);
        }
    }
}

/// GET /health — Liveness probe (legacy alias de /liveness). Model-independent:
/// answers as soon as the server is bound, regardless of model load state.
/// (Enrutado directamente a handle_liveness en handle_http.)
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

/// POST /cancel — Cancel an in-flight generation by `request_id`.
fn handle_cancel(
    stream: &mut TcpStream,
    body: &[u8],
    runtime_slot: &RwLock<RuntimeSlot>,
    state: &Arc<ServerState>,
) {
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
        // Gate R6 — marcar el KV de la sesión cancelada como dudoso para que
        // el siguiente turno de ESA sesión reconstruya el contexto. La
        // limpieza global inmediata (invalidate_session_kv) se mantiene como
        // fallback en el loop de streaming para desconexiones sin POST /cancel.
        if let Some(session_id) = state.take_session(&req.request_id) {
            if let Some(rt) = runtime_slot.read().ok().and_then(|g| g.runtime()) {
                run_async(async move {
                    rt.mark_session_cancelled(&session_id).await;
                });
            }
        }
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
    runtime_slot: &RwLock<RuntimeSlot>,
    state: &Arc<ServerState>,
) {
    #[derive(serde::Deserialize)]
    #[allow(dead_code)]
    struct CompletionReq {
        prompt: String,
        #[serde(default = "default_n_predict")]
        n_predict: usize,
        // Option: ausente → config del motor; presente (incl. 0.0 = greedy)
        temperature: Option<f32>,
        #[serde(default = "default_stream")]
        stream: bool,
        request_id: Option<String>,
        session_id: Option<String>,
        // System prompt / contexto del cliente (la app móvil envía su
        // system dinámico aquí: identidad, estilo y telemetría real).
        context: Option<String>,
        // Historial de turnos previos como lista role/content.
        history: Option<Vec<HistoryItem>>,
    }

    #[derive(serde::Deserialize)]
    struct HistoryItem {
        role: String,
        content: String,
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

    // Gate R6 — correlacionar request_id → session_id para que /cancel pueda
    // marcar el KV de la sesión correcta (no una limpieza global a ciegas).
    if let Some(ref sid) = req.session_id {
        if !sid.is_empty() {
            state.record_session(&request_id, sid);
        }
    }

    // El tope lo impone el motor (contexto + planificador); 2048 cubre el
    // móvil (256-512) y el desktop. Clamp honesto: si el cliente pide más,
    // se registra en log en vez de recortar en silencio.
    let max_tokens = if req.n_predict > 2048 {
        tracing::warn!("n_predict {} clamped to 2048 (engine limit)", req.n_predict);
        2048
    } else {
        req.n_predict.max(1)
    };

    let request = nanortime_core::UserRequest {
        prompt: req.prompt,
        context: req.context,
        history: req.history.map(|items| {
            items
                .into_iter()
                .map(|h| nanortime_core::ChatMessage {
                    role: h.role,
                    content: h.content,
                })
                .collect()
        }),
        session_id: req.session_id,
        max_tokens: Some(max_tokens),
        // temperature del request se respeta (antes se deserializaba y se
        // ignoraba). None = no especificada → config del motor.
        // Some(0.0) = greedy determinista.
        temperature: req.temperature,
    };

    // ── Non-streaming: single JSON response ──────────────────────────
    if !req.stream {
        // Espera al modelo si aún está cargando (tiempo de espera honesto).
        let runtime = match wait_runtime(runtime_slot, model_ready_timeout()) {
            Ok(rt) => rt,
            Err(msg) => {
                send_json(
                    stream,
                    "503 Service Unavailable",
                    &format!(r#"{{"error":{{"code":"runtime_unavailable","message":"{}"}}}}"#, msg),
                );
                return;
            }
        };
        let result = run_async(async {
            let (_, mut rx) = runtime.process_request_streaming(request).await?;
            let mut text = String::new();
            while let Some((token, _prob)) = rx.recv().await {
                text.push_str(&token);
            }
            Ok::<String, anyhow::Error>(text)
        });
        let json_body = match result {
            Ok(text) => serde_json::json!({
                "content": text,
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
        // Gate R3 — heartbeats: mientras el modelo carga o durante el prefill
        // (el primer token tarda), emitir pings periódicos para que el cliente
        // nunca vea la conexión como muerta. El cliente Flutter usa estos
        // frames para mostrar "cargando/esperando" en vez de "desconectado".
        let heartbeat_interval = Duration::from_secs(2);
        let mut heartbeat = tokio::time::interval(heartbeat_interval);
        heartbeat.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Delay);
        // Marca de tiempo del último frame enviado; el primer heartbeat se
        // emite SOLO si no hubo tokens durante el intervalo.
        let mut last_frame = Instant::now();

        // Espera al modelo con heartbeat (sin bloquear el stream). Deadline
        // honesto: si el modelo no carga en el timeout, el stream termina con
        // error SSE en vez de quedar abierto para siempre.
        let ready_deadline = Instant::now() + model_ready_timeout();
        let runtime = loop {
            let ready = {
                let guard = runtime_slot.read().map_err(|e| e.to_string())?;
                match &*guard {
                    RuntimeSlot::Ready(rt) => Some(Arc::clone(rt)),
                    RuntimeSlot::Failed(reason) => {
                        return Err(format!("runtime_unavailable: la carga del modelo falló — {}", reason));
                    }
                    RuntimeSlot::Loading => None,
                }
            };
            if let Some(rt) = ready {
                break rt;
            }
            if Instant::now() >= ready_deadline {
                return Err(
                    "runtime_unavailable: modelo no cargado (el motor sigue arrancando o no hay GGUF). Vuelve a intentar en unos segundos.".to_string(),
                );
            }
            tokio::select! {
                _ = heartbeat.tick() => {
                    if !write_all_or_log(stream, b"data: {\"heartbeat\":true,\"phase\":\"model_loading\"}\n\n") {
                        return Err("client disconnected during model load".to_string());
                    }
                    if let Err(e) = stream.flush() {
                        tracing::warn!("SSE heartbeat flush failed: {}", e);
                    }
                    last_frame = Instant::now();
                }
                changed = cancel_rx.changed() => {
                    if changed.is_ok() && *cancel_rx.borrow() {
                        return Ok(true); // cancelled during model load
                    }
                }
            }
        };

        // Race the stream start (model prefill + first token) against the
        // cancel watch — a cancel during prefill must cut the stream too,
        // not only after the first token arrives.
        tokio::pin! {
            let start = runtime.process_request_streaming(request);
        }
        let (result_rx, mut rx) = tokio::select! {
            res = &mut start => match res {
                Ok((result_rx, rx)) => (result_rx, rx),
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
                    Ok((result_rx, rx)) => (result_rx, rx),
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
                            last_frame = Instant::now();
                        }
                        None => break,
                    }
                }
                _ = heartbeat.tick() => {
                    // Heartbeat solo si hubo silencio (prefill largo, p. ej.
                    // modelo lento o contexto grande): el stream sigue vivo.
                    if last_frame.elapsed() >= heartbeat_interval {
                        if !write_all_or_log(stream, b"data: {\"heartbeat\":true,\"phase\":\"generating\"}\n\n") {
                            break;
                        }
                        if let Err(e) = stream.flush() {
                            tracing::warn!("SSE heartbeat flush failed: {}", e);
                        }
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
        // Gate R10 — timings reales del turno (TTFT, prefill, cache hit/miss,
        // tok/s). En cancel NO se espera el oneshot (el backend sigue
        // generando sin abort hook): los timings se omiten honestamente.
        let stats = if cancelled {
            None
        } else {
            result_rx.await.ok().and_then(|resp| resp.stats)
        };

        // Only send stop event if client is still connected
        let mut stop_json = serde_json::json!({
            "content": "",
            "stop": true,
            "request_id": request_id,
            "cancelled": cancelled,
        });
        if let Some(ref s) = stats {
            stop_json["timings"] = serde_json::json!({
                "ttft_ms": s.ttft_ms,
                "prefill_ms": s.prefill_ms,
                "cache_hit_tokens": s.cache_hit_tokens,
                "cache_miss_tokens": s.cache_miss_tokens,
                "total_tokens": s.total_tokens,
                "generated_tokens": s.generated_tokens,
                "decode_tok_s": s.decode_tok_s,
                "total_ms": s.total_ms,
            });
        }
        if write_all_or_log(stream, format!("data: {}\n\n", stop_json).as_bytes()) {
            let _ = stream.flush(); // Best-effort flush for stop event
        }
        // Gate R6 — cancel deja KV en estado conocido: invalidar el cache de
        // la sesión para que el siguiente turno haga prefill limpio, nunca
        // herede tokens a medias de la generación interrumpida.
        if cancelled {
            runtime.invalidate_session_kv().await;
        }
        Ok(cancelled)
    });

    state.unregister(&request_id);
    // Limpia la correlación request_id → session_id (evita leaks; si /cancel
    // ya la tomó, take_session es no-op).
    state.take_session(&request_id);

    if let Err(e) = result {
        let json = serde_json::json!({"content": format!("[Error: {}]", e), "stop": true});
        write_all_or_log(stream, format!("data: {}\n\n", json).as_bytes());
        let _ = stream.flush(); // Best-effort: client may already be gone
    }
}

/// POST /api/chat — Legacy JSON API.
fn handle_chat_json(
    stream: &mut TcpStream,
    body: &[u8],
    runtime_slot: &RwLock<RuntimeSlot>,
) {
    #[derive(serde::Deserialize)]
    #[allow(dead_code)]
    struct ChatReq {
        prompt: String,
        #[serde(default = "default_max_tokens")]
        max_tokens: usize,
        session_id: Option<String>,
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

    let max_tokens = if req.max_tokens > 2048 {
        tracing::warn!(
            "max_tokens {} clamped to 2048 (engine limit)",
            req.max_tokens
        );
        2048
    } else {
        req.max_tokens.max(1)
    };

    // Espera al modelo si aún se está cargando (mismo contrato que /completion).
    let runtime = match wait_runtime(runtime_slot, model_ready_timeout()) {
        Ok(rt) => rt,
        Err(msg) => {
            send_json(
                stream,
                "503 Service Unavailable",
                &format!(r#"{{"error":{{"code":"runtime_unavailable","message":"{}"}}}}"#, msg),
            );
            return;
        }
    };

    let request = nanortime_core::UserRequest {
        prompt: req.prompt,
        context: None,
        history: None,
        session_id: req.session_id,
        max_tokens: Some(max_tokens),
        temperature: None,
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

/// GET /api/status — Runtime info. Refleja el estado ACTUAL del slot sin
/// bloquear: el cliente hace poll ligero y ve loading:true mientras el GGUF
/// carga, telemetría real cuando Ready, y el fallo con causa cuando Failed.
fn handle_status(
    stream: &mut TcpStream,
    runtime_slot: &RwLock<RuntimeSlot>,
    state: &Arc<ServerState>,
) {
    let guard = match runtime_slot.read() {
        Ok(g) => g,
        Err(_) => {
            send_json(
                stream,
                "500 Internal Server Error",
                r#"{"error":{"code":"lock_poisoned","message":"runtime slot poisoned"}}"#,
            );
            return;
        }
    };
    let uptime = state.started_at.elapsed().as_secs();
    match &*guard {
        RuntimeSlot::Loading => {
            let json = serde_json::json!({
                "status": "loading",
                "version": env!("CARGO_PKG_VERSION"),
                "uptime_seconds": uptime,
                "model_loaded": false,
                "loading": true,
            })
            .to_string();
            send_json(stream, "200 OK", &json);
        }
        RuntimeSlot::Failed(reason) => {
            let json = serde_json::json!({
                "status": "error",
                "version": env!("CARGO_PKG_VERSION"),
                "uptime_seconds": uptime,
                "model_loaded": false,
                "loading": false,
                "error": reason,
            })
            .to_string();
            send_json(stream, "200 OK", &json);
        }
        RuntimeSlot::Ready(rt) => {
            let st = rt.status();
            let json = serde_json::json!({
                "status": "running",
                "version": env!("CARGO_PKG_VERSION"),
                "tier": "local",
                "uptime_seconds": uptime,
                "model_loaded": st.model_loaded,
                "model_size_mb": st.model_size_mb,
                "context_size": st.context_size,
                "fault_rate": st.fault_rate,
                "pss_mb": st.pss_mb,
                "pressure_ratio": st.pressure_ratio,
                "thrashing": st.thrashing,
                "resident_window": st.resident_window,
                "tok_s": st.tok_s,
                "viability": st.viability.map(|v| serde_json::json!({
                    "tier": v.tier,
                    "can_run": v.can_run,
                    "should_run_interactive": v.should_run_interactive,
                    "reason": v.reason,
                })),
            })
            .to_string();
            send_json(stream, "200 OK", &json);
        }
    }
}

/// `runtime_slot` is shared so the model can finish loading while the socket
/// already answers /health. Model-dependent routes wait via [wait_runtime].
fn handle_http(
    mut stream: TcpStream,
    runtime_slot: &RwLock<RuntimeSlot>,
    state: &Arc<ServerState>,
) {
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
        ("GET", "/liveness") => handle_liveness(&mut stream, state),
        ("GET", "/health") => handle_liveness(&mut stream, state),
        ("GET", "/readiness") => handle_readiness(&mut stream, runtime_slot, state),
        ("POST", "/cancel") => handle_cancel(&mut stream, &body, runtime_slot, state),
        ("GET", "/api/status") => handle_status(&mut stream, runtime_slot, state),
        ("POST", "/completion") => {
            handle_completion_sse(&mut stream, &body, runtime_slot, state)
        }
        ("POST", "/api/chat") => handle_chat_json(&mut stream, &body, runtime_slot),
        ("POST", "/debug/kill") => {
            // DEBUG/TEST: simula un crash real del server (proceso muere sin
            // aviso). El watchdog de la app debe detectarlo y reiniciar.
            tracing::warn!("DEBUG: /debug/kill — terminando proceso deliberadamente");
            std::process::exit(1);
        }
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
    /// slot empty, so model-dependent routes answer 503 after timeout) and
    /// returns (status line, body). The model-ready timeout is forced to 0
    /// so the 503 path is exercised fast without loading a GGUF.
    fn drive(request: &str) -> (String, String) {
        // Solo setea si no está definida para no pisar configs de otros tests.
        std::env::set_var("NANO_MODEL_READY_TIMEOUT_SECS", "0");
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let addr = listener.local_addr().unwrap();
        let state = Arc::new(ServerState::new());
        let state2 = Arc::clone(&state);
        let slot: Arc<RwLock<RuntimeSlot>> = Arc::new(RwLock::new(RuntimeSlot::Loading));
        let slot2 = Arc::clone(&slot);
        let handle = std::thread::spawn(move || {
            if let Ok((stream, _)) = listener.accept() {
                handle_http(stream, &slot2, &state2);
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
    fn liveness_returns_ok_with_version_and_uptime() {
        let (status, body) = drive(&http_request("GET", "/liveness", ""));
        assert!(status.starts_with("HTTP/1.1 200"), "status was: {}", status);
        let json: serde_json::Value = serde_json::from_str(&body).unwrap();
        assert_eq!(json["status"], "ok");
        assert_eq!(json["version"], env!("CARGO_PKG_VERSION"));
        assert!(json["uptime_seconds"].is_u64());
        assert_eq!(json["active_requests"], 0);
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
    fn readiness_loading_returns_503() {
        // Slot Loading → 503 MODEL_LOADING (Gate R2).
        let (status, body) = drive(&http_request("GET", "/readiness", ""));
        assert!(
            status.starts_with("HTTP/1.1 503"),
            "status was: {}",
            status
        );
        let json: serde_json::Value = serde_json::from_str(&body).unwrap();
        assert_eq!(json["state"], "MODEL_LOADING");
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
        // No-stream: la ruta bloquea con wait_runtime(timeout=0) → 503 JSON.
        let (status, body) = drive(&http_request(
            "POST",
            "/completion",
            r#"{"prompt":"hola","stream":false}"#,
        ));
        assert!(status.starts_with("HTTP/1.1 503"), "status was: {}", status);
        let json: serde_json::Value = serde_json::from_str(&body).unwrap();
        assert_eq!(json["error"]["code"], "runtime_unavailable");
    }

    #[test]
    fn status_without_runtime_reports_loading() {
        // Sin modelo cargado (slot vacío), /api/status responde 200 con
        // loading:true — el cliente nunca ve el motor como caído durante el
        // arranque del GGUF (contrato de estabilidad de mensajería).
        let (status, body) = drive(&http_request("GET", "/api/status", ""));
        assert!(status.starts_with("HTTP/1.1 200"), "status was: {}", status);
        let json: serde_json::Value = serde_json::from_str(&body).unwrap();
        assert_eq!(json["model_loaded"], false);
        assert_eq!(json["loading"], true);
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
        let slot: Arc<RwLock<RuntimeSlot>> = Arc::new(RwLock::new(RuntimeSlot::Loading));
        let slot2 = Arc::clone(&slot);
        let handle = std::thread::spawn(move || {
            if let Ok((stream, _)) = listener.accept() {
                handle_http(stream, &slot2, &state2);
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

    #[test]
    fn session_registry_roundtrip() {
        let state = ServerState::new();

        // Sin registro previo: no hay sesión asociada.
        assert_eq!(state.take_session("req-1"), None);

        // Registro request_id → session_id y consumo (take elimina).
        state.record_session("req-1", "chat-42");
        assert_eq!(state.take_session("req-1"), Some("chat-42".to_string()));
        // Ya consumida: no vuelve a aparecer (sin leak).
        assert_eq!(state.take_session("req-1"), None);

        // Múltiples sesiones concurrentes no se pisan entre sí.
        state.record_session("req-2", "chat-a");
        state.record_session("req-3", "chat-b");
        assert_eq!(state.take_session("req-2"), Some("chat-a".to_string()));
        assert_eq!(state.take_session("req-3"), Some("chat-b".to_string()));
    }

    // ── Gate R10: timings en el frame SSE final (solo con feature simulated) ──

    /// Crea un runtime simulado con un GGUF dummy (sin llama.cpp real).
    /// El backend simulated emite `GenerationStats` deterministas (ceros),
    /// suficientes para verificar la FORMA del frame SSE, no los valores.
    #[cfg(feature = "simulated")]
    fn simulated_runtime() -> Arc<NanoRuntime> {
        let runtime = run_async(async {
            let dir = std::env::temp_dir().join(format!(
                "nano-simulated-test-{}",
                std::process::id()
            ));
            std::fs::create_dir_all(&dir).expect("crear dir temporal");
            let model_path = dir.join("dummy.gguf");
            std::fs::write(&model_path, b"dummy gguf content").expect("escribir dummy");
            let mut config = nanortime_core::Config::default_config();
            config.local_model.path = model_path.to_string_lossy().to_string();
            nanortime_core::NanoRuntime::new(config).await.expect("runtime simulado")
        });
        Arc::new(runtime)
    }

    /// Envía un request a través de un socket real contra `handle_http` con un
    /// runtime YA cargado y lee la respuesta completa hasta EOF (el server
    /// cierra la conexión al terminar el handler — SSE sin Content-Length).
    #[cfg(feature = "simulated")]
    fn drive_sse_with_runtime(request: &str, runtime: Arc<NanoRuntime>) -> (String, String) {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let addr = listener.local_addr().unwrap();
        let state = Arc::new(ServerState::new());
        let state2 = Arc::clone(&state);
        let slot: Arc<RwLock<RuntimeSlot>> =
            Arc::new(RwLock::new(RuntimeSlot::Ready(runtime)));
        let slot2 = Arc::clone(&slot);
        let handle = std::thread::spawn(move || {
            if let Ok((stream, _)) = listener.accept() {
                handle_http(stream, &slot2, &state2);
            }
        });
        let mut client = TcpStream::connect(addr).unwrap();
        client
            .set_read_timeout(Some(std::time::Duration::from_secs(30)))
            .unwrap();
        write_all_or_log(&mut client, request.as_bytes());
        client.shutdown(std::net::Shutdown::Write).unwrap();

        let mut buf = Vec::new();
        let mut reader = BufReader::new(&mut client);
        reader.read_to_end(&mut buf).expect("leer respuesta completa");
        handle.join().unwrap();

        let raw = String::from_utf8_lossy(&buf).to_string();
        let status_line = raw.lines().next().unwrap_or("").to_string();
        let body = raw.split("\r\n\r\n").nth(1).unwrap_or("").to_string();
        (status_line, body)
    }

    #[cfg(feature = "simulated")]
    #[test]
    fn completion_sse_final_frame_includes_timings() {
        let runtime = simulated_runtime();
        let (status, body) = drive_sse_with_runtime(
            &http_request(
                "POST",
                "/completion",
                r#"{"prompt":"hola","stream":true,"n_predict":4}"#,
            ),
            runtime,
        );
        assert!(status.starts_with("HTTP/1.1 200"), "status was: {}", status);

        // Último frame `stop:true` debe traer el objeto `timings`.
        let mut last_stop: Option<serde_json::Value> = None;
        for line in body.lines() {
            if let Some(data) = line.strip_prefix("data: ") {
                if let Ok(v) = serde_json::from_str::<serde_json::Value>(data) {
                    if v["stop"].as_bool() == Some(true) {
                        last_stop = Some(v);
                    }
                }
            }
        }
        let last = last_stop.expect("frame stop:true presente en el SSE");
        let timings = last["timings"].as_object().expect("timings presentes");
        assert!(timings.contains_key("ttft_ms"));
        assert!(timings.contains_key("prefill_ms"));
        assert!(timings.contains_key("cache_hit_tokens"));
        assert!(timings.contains_key("cache_miss_tokens"));
        assert!(timings.contains_key("total_tokens"));
        assert!(timings.contains_key("generated_tokens"));
        assert!(timings.contains_key("decode_tok_s"));
        assert!(timings.contains_key("total_ms"));
    }
}
