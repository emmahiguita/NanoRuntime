//! Minimal llama-cpp-2 test to verify the batch/decode API works.

use std::path::Path;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let path = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "C:\\llama-cpp-server\\models\\qwen2.5-1.5b-instruct-q4_k_m.gguf".to_string());

    println!("Loading model: {}", path);
    let backend = llama_cpp_2::llama_backend::LlamaBackend::init()?;
    let model = llama_cpp_2::model::LlamaModel::load_from_file(
        &backend,
        Path::new(&path),
        &Default::default(),
    )?;
    println!("Model loaded. Vocab: {}", model.n_vocab());

    let ctx_params = llama_cpp_2::context::params::LlamaContextParams::default()
        .with_n_ctx(std::num::NonZeroU32::new(2048))
        .with_n_batch(512);
    let mut ctx = model.new_context(&backend, ctx_params)?;
    println!("Context created.");

    // Tokenize
    let tokens = model.str_to_token("Hello, world!", llama_cpp_2::model::AddBos::Always)?;
    println!("Tokens: {:?} ({} tokens)", tokens, tokens.len());

    // Try single-token decode
    let mut batch = llama_cpp_2::llama_batch::LlamaBatch::new(1, 1);
    println!("Batch created: n_tokens={}", batch.n_tokens());

    batch.add(tokens[0], 0, &[0], true)?;
    println!("After add: n_tokens={}", batch.n_tokens());

    ctx.decode(&mut batch)?;
    println!("Decode OK!");

    // Sample
    let mut sampler = llama_cpp_2::sampling::LlamaSampler::greedy();
    let token = sampler.sample(&ctx, 0);
    println!("Sampled token: {:?}", token);

    let mut decoder = encoding_rs::UTF_8.new_decoder();
    let text = model.token_to_piece(token, &mut decoder, false, None)?;
    println!("Text: '{}'", text);

    Ok(())
}
