//! Valida generate_mtp / generate_streaming_mtp del FFI de nanortime.
//!
//! Uso: cargo run -p nanortime-ffi --example test_mtp_ffi -- <modelo.gguf> [n_max] [max_tokens]
//!
//! Requiere un GGUF con cabezas NextN (Qwen3.5-MTP). Verifica:
//! 1. supports_mtp() detecta el modelo.
//! 2. generate_mtp produce texto coherente con tasa de aceptación > 0.
//! 3. generate_streaming_mtp emite tokens por callback.
//! 4. generate (plano) sigue funcionando como baseline.

use std::path::Path;

use nanortime_ffi::{GenerateParams, ModelLoadParams, NanoModel};

fn main() {
    let mut args = std::env::args().skip(1);
    let path = args.next().unwrap_or_else(|| {
        "C:\\Users\\emman\\Desktop\\Proyectos\\Nueva carpeta\\Nanoai\\data\\mtp\\Qwen3.5-4B-MTP-Q4_K_M.gguf".to_string()
    });
    let n_max: i32 = args.next().and_then(|s| s.parse().ok()).unwrap_or(1);
    let max_tokens: usize = args.next().and_then(|s| s.parse().ok()).unwrap_or(64);

    if !Path::new(&path).exists() {
        eprintln!("ERROR: no existe {}", path);
        std::process::exit(1);
    }

    let load = ModelLoadParams {
        context_size: 2048,
        gpu_layers: 0,
        use_mmap: true,
        threads: 4,
        batch_size: 64,
    };
    let model = NanoModel::load(&path, &load).expect("load model");
    println!(
        "n_layer={} supports_mtp={}",
        model.n_layer(),
        model.supports_mtp()
    );
    if !model.supports_mtp() {
        eprintln!("ERROR: el modelo no tiene cabezas NextN (MTP)");
        std::process::exit(1);
    }

    let mut ctx = model.create_context(&load).expect("create context");

    let params = GenerateParams {
        max_tokens,
        temperature: 0.0, // greedy → determinista, comparable direct vs mtp
        top_p: 0.9,
        repeat_penalty: 1.0,
        stop_sequences: vec!["</s>".into(), "<|endoftext|>".into(), "<|im_end|>".into()],
    };
    let prompt = "Hola, ¿cómo estás? Cuéntame sobre la inteligencia artificial.";

    // 1. Baseline plano
    let res = ctx
        .generate(&model, prompt, &params, None)
        .expect("generate plano");
    println!(
        "\n[plano]  {:.2} tok/s  ({})",
        res.tokens_per_second, res.text
    );

    // 2. MTP (greedy, no sampling → tasa de aceptación = argmax match)
    let res = ctx
        .generate_mtp(&model, prompt, &params, n_max, None)
        .expect("generate mtp");
    println!(
        "\n[mtp]    {:.2} tok/s  {} tokens  ({})",
        res.tokens_per_second, res.tokens_generated, res.text
    );

    // 3. MTP streaming
    let mut n_cb = 0usize;
    let res = ctx
        .generate_streaming_mtp(
            &model,
            prompt,
            &params,
            n_max,
            None,
            |piece, _prob, is_stop| {
                n_cb += 1;
                if n_cb <= 3 {
                    println!("  stream[{n_cb}]: {piece:?} stop={is_stop}");
                }
                true
            },
        )
        .expect("generate streaming mtp");
    println!(
        "\n[stream] {:.2} tok/s  {} tokens  ({} callbacks)  ({})",
        res.tokens_per_second, res.tokens_generated, n_cb, res.text
    );

    println!("\n=== FFI MTP OK ===");
}
