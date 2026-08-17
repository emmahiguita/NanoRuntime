//! Benchmark Direct (decode plano) vs MTP speculative en el mismo modelo.
//!
//! Uso: cargo run -q --example mtp_bench -- <modelo.gguf> <n_gen> <n_max>
//!   n_gen: tokens a generar por modo (default 128)
//!   n_max: drafts por verificación MTP (default 3)
//!
//! Mide: Tok/s por modo, EffectiveSpeedup = Tok/s_MTP / Tok/s_Direct,
//! y tasa de aceptación MTP. El prefill NO se cronometra.

use std::num::NonZeroU32;
use std::path::PathBuf;
use std::time::Instant;

use encoding_rs::UTF_8;
use llama_cpp_2::context::params::LlamaContextParams;
use llama_cpp_2::context::params::LlamaContextType;
use llama_cpp_2::llama_backend::LlamaBackend;
use llama_cpp_2::llama_batch::LlamaBatch;
use llama_cpp_2::model::params::LlamaModelParams;
use llama_cpp_2::model::{AddBos, LlamaModel};
use llama_cpp_2::speculative::{MtpSpeculative, MtpSpeculativeParams};
use llama_cpp_2::token::LlamaToken;

/// Argmax greedy sobre logits (sin sampler chain: determinista).
fn greedy_argmax(logits: &[f32]) -> LlamaToken {
    let (idx, _) = logits
        .iter()
        .enumerate()
        .max_by(|(_, a), (_, b)| a.total_cmp(b))
        .expect("logits vacíos");
    LlamaToken(idx as i32)
}

fn piece_of(model: &LlamaModel, token: LlamaToken) -> String {
    let mut decoder = UTF_8.new_decoder();
    model
        .token_to_piece(token, &mut decoder, true, None)
        .unwrap_or_default()
}

// ── I/O del proceso (Windows): bytes leídos de disco vía GetProcessIoCounters.
// Incluye page-ins del mmap del GGUF → base para IOAmp = BytesRead/Token útil.
#[cfg(target_os = "windows")]
#[repr(C)]
struct IoCounters {
    read_operation_count: u64,
    write_operation_count: u64,
    other_operation_count: u64,
    read_transfer_count: u64,
    write_transfer_count: u64,
    other_transfer_count: u64,
}

#[cfg(target_os = "windows")]
#[link(name = "kernel32")]
extern "system" {
    fn GetCurrentProcess() -> *mut std::ffi::c_void;
    fn GetProcessIoCounters(process: *mut std::ffi::c_void, counters: *mut IoCounters) -> i32;
}

// IOAmp solo es medible en Windows (GetProcessIoCounters). En Linux/Android el
// ejemplo compila con stub: el link a kernel32 rompia el build en CI ubuntu.
#[cfg(target_os = "windows")]
fn io_bytes_read() -> u64 {
    let mut c = IoCounters {
        read_operation_count: 0,
        write_operation_count: 0,
        other_operation_count: 0,
        read_transfer_count: 0,
        write_transfer_count: 0,
        other_transfer_count: 0,
    };
    let ok = unsafe { GetProcessIoCounters(GetCurrentProcess(), &mut c) };
    if ok == 0 {
        0
    } else {
        c.read_transfer_count
    }
}

#[cfg(not(target_os = "windows"))]
fn io_bytes_read() -> u64 {
    0
}

/// Modo Direct: decode plano de 1 token por iteración.
fn run_direct(
    model: &LlamaModel,
    ctx: &mut llama_cpp_2::context::LlamaContext,
    prompt: &[LlamaToken],
    eos: LlamaToken,
    n_gen: usize,
) -> (f64, String) {
    // Prefill (fuera del timing).
    let mut n_past: i32 = 0;
    for chunk in prompt.chunks(64) {
        let mut batch = LlamaBatch::new(chunk.len(), 1);
        for (i, &tok) in chunk.iter().enumerate() {
            batch.add(tok, n_past + i as i32, &[0], false).expect("add");
        }
        ctx.decode(&mut batch).expect("decode prefill");
        n_past += chunk.len() as i32;
    }

    let t0 = Instant::now();
    let mut out = String::new();
    let mut n_emitted = 0usize;
    let mut last = prompt[prompt.len() - 1];

    while n_emitted < n_gen && last != eos {
        let mut batch = LlamaBatch::new(1, 1);
        batch.add(last, n_past, &[0], true).expect("add");
        ctx.decode(&mut batch).expect("decode");
        n_past += 1;
        let logits = ctx.get_logits_ith(0).to_vec();
        last = greedy_argmax(&logits);
        if last != eos {
            out.push_str(&piece_of(model, last));
        }
        n_emitted += 1;
    }
    let dt = t0.elapsed().as_secs_f64();
    (n_emitted as f64 / dt, out)
}

/// Modo MTP: loop speculativo (mismo flujo que mtp_drive).
fn run_mtp(
    model: &LlamaModel,
    mtp: &mut MtpSpeculative,
    tokens: &[LlamaToken],
    eos: LlamaToken,
    n_gen: usize,
) -> (f64, f64, String) {
    // Prefill (fuera del timing): todos los tokens excepto el último.
    let mut n_past: i32 = 0;
    let (prompt_tokens, last_tok) = tokens.split_at(tokens.len() - 1);
    for chunk in prompt_tokens.chunks(64) {
        let mut batch = LlamaBatch::new(chunk.len(), 1);
        for (i, &tok) in chunk.iter().enumerate() {
            batch.add(tok, n_past + i as i32, &[0], false).expect("add");
        }
        mtp.target_context_mut()
            .decode(&mut batch)
            .expect("decode prefill");
        mtp.process(&batch).expect("process prefill");
        n_past += chunk.len() as i32;
    }

    let mut last_token = last_tok[0];
    let t0 = Instant::now();
    let mut out = String::new();
    let mut n_emitted = 0usize;
    let mut n_proposals = 0usize;
    let mut n_accepted = 0usize;

    while n_emitted < n_gen && last_token != eos {
        let drafts = mtp.draft(n_past, last_token, tokens).unwrap_or_default();

        if drafts.is_empty() {
            let mut batch = LlamaBatch::new(1, 1);
            batch.add(last_token, n_past, &[0], true).expect("add");
            mtp.target_context_mut()
                .decode(&mut batch)
                .expect("decode plain");
            mtp.process(&batch).expect("process plain");
            n_past += 1;
            let logits = mtp.target_context().get_logits_ith(0).to_vec();
            last_token = greedy_argmax(&logits);
            if last_token != eos {
                out.push_str(&piece_of(model, last_token));
            }
            n_emitted += 1;
            continue;
        }

        n_proposals += drafts.len();
        let mut vbatch = LlamaBatch::new(drafts.len() + 1, 1);
        vbatch
            .add(last_token, n_past, &[0], true)
            .expect("add id_last");
        for (j, &d) in drafts.iter().enumerate() {
            vbatch
                .add(d, n_past + 1 + j as i32, &[0], true)
                .expect("add draft");
        }
        mtp.target_context_mut()
            .decode(&mut vbatch)
            .expect("decode verify");
        mtp.process(&vbatch).expect("process verify");

        let mut n_ok: usize = 0;
        for (j, &d) in drafts.iter().enumerate() {
            let logits = mtp.target_context().get_logits_ith(j as i32).to_vec();
            if greedy_argmax(&logits) == d {
                n_ok += 1;
            } else {
                break;
            }
        }
        n_accepted += n_ok;

        let real = greedy_argmax(mtp.target_context().get_logits_ith(n_ok as i32));
        mtp.accept(n_ok as u16).expect("accept");

        for &d in drafts.iter().take(n_ok) {
            if d != eos {
                out.push_str(&piece_of(model, d));
            }
        }
        if real != eos {
            out.push_str(&piece_of(model, real));
        }
        n_emitted += n_ok + 1;

        let rollback_from = n_past + 1 + n_ok as i32;
        mtp.target_context_mut()
            .kv_cache_seq_rm(0, Some(rollback_from as u32), None)
            .expect("rollback tgt");
        mtp.draft_context_mut()
            .kv_cache_seq_rm(0, Some(rollback_from as u32), None)
            .expect("rollback dft");
        n_past = rollback_from;
        last_token = real;
    }
    let dt = t0.elapsed().as_secs_f64();
    let rate = if n_proposals > 0 {
        n_accepted as f64 / n_proposals as f64
    } else {
        0.0
    };
    (n_emitted as f64 / dt, rate, out)
}

fn main() {
    tracing_subscriber::fmt::init();

    let mut args = std::env::args().skip(1);
    let path = PathBuf::from(
        args.next()
            .unwrap_or_else(|| "data/mtp/Qwen3.5-4B-MTP-Q4_K_M.gguf".to_string()),
    );
    let n_gen: usize = args.next().and_then(|s| s.parse().ok()).unwrap_or(128);
    let n_max: i32 = args.next().and_then(|s| s.parse().ok()).unwrap_or(3);

    if !path.exists() {
        eprintln!("ERROR: no existe {}", path.display());
        std::process::exit(1);
    }

    let backend = LlamaBackend::init().expect("backend");
    let model_params = LlamaModelParams::default()
        .with_use_mmap(true)
        .with_n_gpu_layers(0);
    let model =
        LlamaModel::load_from_file(&backend, path.as_path(), &model_params).expect("modelo");

    let prompt = "Hola, ¿cómo estás? Cuéntame sobre la inteligencia artificial.";
    let tokens = model
        .str_to_token(prompt, AddBos::Always)
        .expect("tokenize");
    let eos = model.token_eos();
    println!("prompt: {prompt}  ({} tokens, bos incluido)", tokens.len());

    // ── Direct ──
    let ctx_params = LlamaContextParams::default()
        .with_n_ctx(NonZeroU32::new(1024))
        .with_n_batch(64);
    let mut ctx = model.new_context(&backend, ctx_params).expect("ctx direct");
    let io0 = io_bytes_read();
    let (tps_direct, out_direct) = run_direct(&model, &mut ctx, &tokens, eos, n_gen);
    let io_direct = io_bytes_read().saturating_sub(io0);
    println!("\n[direct] {tps_direct:.2} tok/s  ({out_direct})");

    // ── MTP ──
    let tgt_params = LlamaContextParams::default()
        .with_n_ctx(NonZeroU32::new(1024))
        .with_n_batch(64)
        .with_n_rs_seq(n_max as u32 + 1);
    let dft_params = LlamaContextParams::default()
        .with_n_ctx(NonZeroU32::new(1024))
        .with_n_batch(64)
        .with_context_type(LlamaContextType::Mtp);
    let target = model.new_context(&backend, tgt_params).expect("ctx tgt");
    let draft = model.new_context(&backend, dft_params).expect("ctx dft");
    let mut mtp = MtpSpeculative::new(
        target,
        draft,
        MtpSpeculativeParams {
            n_max,
            n_min: 0,
            p_min: 0.0,
        },
    )
    .expect("init mtp");

    let io1 = io_bytes_read();
    let (tps_mtp, rate, out_mtp) = run_mtp(&model, &mut mtp, &tokens, eos, n_gen);
    let io_mtp = io_bytes_read().saturating_sub(io1);
    println!("\n[mtp] {tps_mtp:.2} tok/s  (aceptación {rate:.3})  ({out_mtp})");

    // IOAmp = bytes leídos de disco por token útil (tokens de salida).
    let amp_direct = io_direct as f64 / n_gen as f64;
    let amp_mtp = io_mtp as f64 / n_gen as f64;
    println!("\n=== RESUMEN BENCH ===");
    println!("direct: {tps_direct:.2} tok/s   I/O {io_direct} B  → IOAmp {amp_direct:.0} B/tok");
    println!(
        "mtp:    {tps_mtp:.2} tok/s   I/O {io_mtp} B  → IOAmp {amp_mtp:.0} B/tok  (n_max={n_max}, aceptación={rate:.3})"
    );
    println!("EffectiveSpeedup = {:.2}x", tps_mtp / tps_direct);
    println!("IOAmpRatio (direct/mtp) = {:.2}x", amp_direct / amp_mtp);
    let proj = 1.0 + rate * n_max as f64;
    println!("speedup proyectado (teórico) = {proj:.2}x  (ignora costo del draft)");
}
