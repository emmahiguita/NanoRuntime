//! NanoRuntime HTTP Server — Punto de entrada del servidor Web.
//!
//! Inicializa el estado compartido y arranca el listener TCP para peticiones
//! locales del navegador.

mod handlers;
mod state;

use std::net::TcpListener;
use std::path::PathBuf;
use std::sync::{
    mpsc::{self, TrySendError},
    Arc, Mutex,
};

use handlers::{handle_connection, send_response};
use state::ServerState;

const HTTP_WORKERS: usize = 8;
const HTTP_QUEUE_CAPACITY: usize = 32;

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let mut model = default_model_path();
    let mut port = 8080u16;

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "--model" | "-m" if i + 1 < args.len() => {
                model = args[i + 1].clone();
                i += 1;
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
    println!("  Modelo: {}", model);
    println!("  URL:    http://{}", bind_addr);
    if !std::path::Path::new(&model).is_file() {
        println!("  [Error] El archivo GGUF configurado no existe");
    }
    if bind_host == "0.0.0.0" {
        println!("  [Advertencia] Enlazado a 0.0.0.0 (accesible desde red externa)");
    }

    let state = Arc::new(ServerState::new(&model));
    let listener = TcpListener::bind(&bind_addr)
        .unwrap_or_else(|e| panic!("No se pudo bindear {}: {}", bind_addr, e));

    let (connection_tx, connection_rx) = mpsc::sync_channel(HTTP_QUEUE_CAPACITY);
    let connection_rx = Arc::new(Mutex::new(connection_rx));

    for worker_id in 0..HTTP_WORKERS {
        let worker_state = Arc::clone(&state);
        let worker_rx = Arc::clone(&connection_rx);
        std::thread::Builder::new()
            .name(format!("nanortime-web-http-{}", worker_id))
            .spawn(move || loop {
                let stream = match worker_rx.lock() {
                    Ok(receiver) => receiver.recv(),
                    Err(_) => return,
                };

                match stream {
                    Ok(stream) => handle_connection(stream, &worker_state),
                    Err(_) => return,
                }
            })
            .expect("No se pudo iniciar un worker HTTP");
    }

    for stream in listener.incoming() {
        match stream {
            Ok(stream) => match connection_tx.try_send(stream) {
                Ok(()) => {}
                Err(TrySendError::Full(stream)) => send_response(
                    stream,
                    "503 Service Unavailable",
                    "Servidor ocupado; intenta nuevamente",
                    "text/plain",
                ),
                Err(TrySendError::Disconnected(_)) => {
                    eprintln!("[nanortime-web] Pool HTTP detenido");
                    break;
                }
            },
            Err(e) => eprintln!("[nanortime-web] Error de conexión: {}", e),
        }
    }
}

fn default_model_path() -> String {
    if let Ok(configured) = std::env::var("NANO_MODEL_PATH") {
        if !configured.trim().is_empty() {
            return configured;
        }
    }

    let file_name = "qwen2.5-1.5b-instruct-q8_0.gguf";
    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let candidates = [
        PathBuf::from(file_name),
        manifest_dir.join("../../../").join(file_name),
    ];

    candidates
        .into_iter()
        .find(|candidate| candidate.is_file())
        .map(|candidate| {
            candidate
                .canonicalize()
                .unwrap_or(candidate)
                .to_string_lossy()
                .into_owned()
        })
        .unwrap_or_else(|| file_name.to_string())
}
