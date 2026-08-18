//! Gate R6 — cancelación de sesión y reconstrucción del contexto.
//!
//! En build `simulated` no hay KV cache real de llama.cpp, así que el
//! observable honesto es el contrato de comportamiento: tras
//! `mark_session_cancelled`, el siguiente turno de la MISMA sesión funciona
//! sin heredar estado corrupto. La verificación del KV REAL (clear_kv_cache +
//! kv_dirty) es manual en dispositivo — aquí se cubre la lógica de estado.

#![cfg(feature = "simulated")]

use nanortime_core::{Config, NanoRuntime, UserRequest};

async fn setup_runtime() -> NanoRuntime {
    let dir = tempfile::tempdir().expect("tempdir");
    let model_path = dir.path().join("dummy.gguf");
    std::fs::write(&model_path, b"dummy gguf content").expect("write dummy model");
    let mut config = Config::default_config();
    config.local_model.path = model_path.to_string_lossy().to_string();
    NanoRuntime::new(config).await.expect("runtime")
}

fn req(prompt: &str, session: &str) -> UserRequest {
    UserRequest {
        prompt: prompt.into(),
        context: None,
        history: None,
        session_id: Some(session.into()),
        max_tokens: Some(16),
        temperature: None,
    }
}

#[tokio::test]
async fn cancel_then_next_turn_same_session_works() {
    let runtime = setup_runtime().await;
    let session = "chat-1";

    // Primer turno: streaming completo y oneshot resuelto.
    let (rx, mut tokens) = runtime
        .process_request_streaming(req("primer turno", session))
        .await
        .expect("primer turno");
    while tokens.recv().await.is_some() {}
    let resp = rx.await.expect("oneshot");
    assert!(!resp.text.is_empty(), "el primer turno debe emitir texto");

    // El server HTTP llama a esto tras POST /cancel.
    runtime.mark_session_cancelled(session).await;

    // Segundo turno del MISMO session: no debe corromperse ni colgar.
    let (rx2, mut tokens2) = runtime
        .process_request_streaming(req("segundo turno", session))
        .await
        .expect("segundo turno tras cancel");
    while tokens2.recv().await.is_some() {}
    let resp2 = rx2.await.expect("oneshot2");
    assert!(!resp2.text.is_empty(), "el turno tras cancel debe emitir texto");
}

#[tokio::test]
async fn cancel_other_session_does_not_affect_current() {
    let runtime = setup_runtime().await;

    // Cancelar una sesión que NO está activa no debe romper nada.
    runtime.mark_session_cancelled("sesion-inexistente").await;

    let (rx, mut tokens) = runtime
        .process_request_streaming(req("turno aislado", "chat-a"))
        .await
        .expect("turno aislado");
    while tokens.recv().await.is_some() {}
    let resp = rx.await.expect("oneshot");
    assert!(!resp.text.is_empty());
}
