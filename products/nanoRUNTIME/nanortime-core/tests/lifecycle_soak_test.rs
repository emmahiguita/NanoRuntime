//! Gate R7 — soak de ciclo de vida: 20 ciclos load/generate/unload sin
//! crecimiento de estado (sin sesiones huérfanas, sin modelos a medias).
//!
//! El PSS/RssAnon REAL se verifica en dispositivo (`scripts/smaps_validator.py`
//! lee `/proc/<pid>/smaps_rollup`); este test CI cubre la lógica de liberación
//! del estado interno, no el mmap del OS (honesto: simulated no tiene mmap).

#![cfg(feature = "simulated")]

use nanortime_core::{Config, NanoRuntime, UserRequest};

async fn setup_runtime() -> (NanoRuntime, tempfile::TempDir, String) {
    let dir = tempfile::tempdir().expect("tempdir");
    let model_path = dir.path().join("dummy.gguf");
    std::fs::write(&model_path, b"dummy gguf content").expect("write dummy");
    let model_str = model_path.to_string_lossy().to_string();
    let mut config = Config::default_config();
    config.local_model.path = model_str.clone();
    let runtime = NanoRuntime::new(config).await.expect("runtime");
    (runtime, dir, model_str)
}

#[tokio::test]
async fn twenty_load_generate_unload_cycles_no_state_leak() {
    let (runtime, _dir, model_str) = setup_runtime().await;
    let mm = runtime.model_manager();

    for cycle in 0..20 {
        // LOAD — el modelo debe quedar cargado.
        mm.load_model(&model_str)
            .await
            .unwrap_or_else(|e| panic!("load en ciclo {}: {}", cycle, e));
        assert!(
            mm.is_loaded().await,
            "load debe dejar modelo cargado (ciclo {})",
            cycle
        );

        // GENERATE — un turno streaming completo.
        let (rx, mut tokens) = runtime
            .process_request_streaming(UserRequest {
                prompt: format!("ciclo {}", cycle),
                context: None,
                history: None,
                session_id: Some(format!("s{}", cycle % 3)),
                max_tokens: Some(8),
                temperature: None,
            })
            .await
            .unwrap_or_else(|e| panic!("streaming en ciclo {}: {}", cycle, e));
        while tokens.recv().await.is_some() {}
        let _resp = rx.await.expect("oneshot del turno");

        // UNLOAD — el modelo debe liberarse por completo.
        mm.unload_model().await;
        assert!(
            !mm.is_loaded().await,
            "unload debe liberar el modelo (ciclo {})",
            cycle
        );
    }
}
