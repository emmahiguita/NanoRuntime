//! MTP drive — valida el loop COMPLETO de speculative MTP (draft-mtp) contra un
//! modelo real con cabezas NextN.
//!
//! Requiere un GGUF convertido CON MTP (convert_hf_to_gguf.py sin --no-mtp).
//! Verifica: begin → prefill (process por cada decode) → draft → verify →
//! accept/reject (argmax greedy) → KV rollback → siguiente iteración.
//!
//! Uso:
//!   cargo run -p nanortime-core --example mtp_drive -- [ruta.gguf] [n_max] [max_tokens]

use std::num::NonZeroU32;
use std::path::PathBuf;

use encoding_rs::UTF_8;

use llama_cpp_2::context::params::LlamaContextParams;
use llama_cpp_2::llama_backend::LlamaBackend;
use llama_cpp_2::llama_batch::LlamaBatch;
use llama_cpp_2::model::params::LlamaModelParams;
use llama_cpp_2::model::{AddBos, LlamaModel};
use llama_cpp_2::speculative::{MtpSpeculative, MtpSpeculativeParams};
use llama_cpp_2::token::LlamaToken;

fn greedy_argmax(logits: &[f32]) -> LlamaToken {
    let (idx, _) = logits
        .iter()
        .enumerate()
        .max_by(|a, b| a.1.partial_cmp(b.1).unwrap_or(std::cmp::Ordering::Equal))
        .expect("logits vacíos");
    LlamaToken(idx as i32)
}

fn piece_of(model: &LlamaModel, token: LlamaToken) -> String {
    let mut decoder = UTF_8.new_decoder();
    model
        .token_to_piece(token, &mut decoder, true, None)
        .unwrap_or_default()
}

fn main() {
    tracing_subscriber::fmt::init();

    let mut args = std::env::args().skip(1);
    let path = PathBuf::from(
        args.next()
            .unwrap_or_else(|| "data/mtp/Qwen3-4B-Q4_K_M.gguf".to_string()),
    );
    let n_max: i32 = args.next().and_then(|s| s.parse().ok()).unwrap_or(3);
    let max_tokens: usize = args.next().and_then(|s| s.parse().ok()).unwrap_or(32);

    if !path.exists() {
        eprintln!("ERROR: no existe {}", path.display());
        std::process::exit(1);
    }

    let backend = LlamaBackend::init().expect("backend init");
    let model_params = LlamaModelParams::default()
        .with_use_mmap(true)
        .with_n_gpu_layers(0);
    let model = LlamaModel::load_from_file(&backend, path.as_path(), &model_params)
        .expect("cargar modelo");

    let n_nextn = model.n_layer_nextn();
    println!("n_layer_nextn(MTP) = {n_nextn}");
    if n_nextn <= 0 {
        eprintln!("ERROR: modelo sin cabezas MTP — convertir con MTP habilitado");
        std::process::exit(1);
    }

    // Target context (trunk) + draft context (MTP-only KV).
    // n_rs_seq>0: el target es híbrido (attn + recurrente); el rollback del KV
    // tras un draft rechazado restaura el estado recurrente desde snapshots.
    // El rollback borra hasta n_max tokens → profundidad de snapshots = n_max+1.
    let tgt_params = LlamaContextParams::default()
        .with_n_ctx(NonZeroU32::new(1024))
        .with_n_batch(64)
        .with_n_rs_seq(n_max as u32 + 1);
    let dft_params = LlamaContextParams::default()
        .with_n_ctx(NonZeroU32::new(1024))
        .with_n_batch(64)
        .with_context_type(llama_cpp_2::context::params::LlamaContextType::Mtp);

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
    .expect("init MtpSpeculative");

    let eos = model.token_eos();
    let prompt = "Hola, ¿cómo estás? Cuéntame sobre la inteligencia artificial.";
    let tokens = model
        .str_to_token(prompt, AddBos::Always)
        .expect("tokenize");
    println!("prompt: {prompt}  ({} tokens)", tokens.len());

    mtp.begin(&tokens).expect("begin");

    // ── Prefill del target (chunks), alimentando process() por decode ──
    // NOTA: el ÚLTIMO token del prompt NO se decodifica aquí — queda como
    // id_last y entra en el batch verify (flujo de speculative-simple.cpp).
    // Así el batch verify empieza en Y = n_past = X+1 y el check M-RoPE pasa.
    let mut n_past: i32 = 0;
    let prefill_batch = 64usize;

    let (prompt_tokens, last_tok) = tokens.split_at(tokens.len() - 1);
    for chunk in prompt_tokens.chunks(prefill_batch) {
        let mut batch = LlamaBatch::new(chunk.len(), 1);
        for (i, &token) in chunk.iter().enumerate() {
            batch
                .add(token, n_past + i as i32, &[0], false)
                .expect("batch add");
        }
        mtp.target_context_mut().decode(&mut batch).expect("decode prefill");
        mtp.process(&batch).expect("process prefill");
        n_past += chunk.len() as i32;
    }

    // id_last = último token del prompt (aún NO en KV del target).
    // n_past = su posición = tokens.len()-1.
    let mut last_token = last_tok[0];

    // ── Loop speculativo ──
    // Flujo canónico (speculative-simple.cpp:222-258):
    //   draft(n_past, id_last) → drafts para posiciones n_past+1..n_past+K
    //   verify batch = [id_last @ n_past, drafts @ n_past+1+j] (decode + process)
    //   aceptar draft[j] si argmax(logits_ith(j)) == draft[j]
    //   real = argmax(logits_ith(n_accepted))
    //   KV tras verify: id_last + drafts en n_past..n_past+K
    //   aceptados: id_last + drafts[..n_accepted] → borrar desde n_past+1+n_accepted
    let mut n_emitted: usize = 0;
    let mut n_draft_proposals: usize = 0;
    let mut n_draft_accepted: usize = 0;
    let mut n_verify_steps: usize = 0;

    while n_emitted < max_tokens && last_token != eos {
        if n_past as u32 >= 1024 {
            println!("[context limit]");
            break;
        }

        let drafts = mtp.draft(n_past, last_token, &tokens).unwrap_or_default();

        if drafts.is_empty() {
            // Camino plano: decode de un token.
            let mut batch = LlamaBatch::new(1, 1);
            batch
                .add(last_token, n_past, &[0], true)
                .expect("batch add");
            mtp.target_context_mut().decode(&mut batch).expect("decode plain");
            mtp.process(&batch).expect("process plain");
            n_past += 1;
            let logits = mtp.target_context().get_logits_ith(0).to_vec();
            last_token = greedy_argmax(&logits);
            let piece = piece_of(&model, last_token);
            print!("{piece}");
            n_emitted += 1;
            continue;
        }

        // Verificación: decodificar id_last + drafts en el target.
        n_draft_proposals += drafts.len();
        n_verify_steps += 1;
        let mut vbatch = LlamaBatch::new(drafts.len() + 1, 1);
        vbatch
            .add(last_token, n_past, &[0], true)
            .expect("batch add id_last");
        for (j, &d) in drafts.iter().enumerate() {
            vbatch
                .add(d, n_past + 1 + j as i32, &[0], true)
                .expect("batch add verify");
        }
        mtp.target_context_mut().decode(&mut vbatch).expect("decode verify");
        mtp.process(&vbatch).expect("process verify");

        // Aceptar mientras el draft sea el argmax greedy.
        // logits_ith(j) = predicción del target DESPUÉS de la fila j del batch
        // (id_last es la fila 0) → se compara contra draft[j].
        let mut n_accepted: usize = 0;
        for (j, &d) in drafts.iter().enumerate() {
            let logits = mtp.target_context().get_logits_ith(j as i32).to_vec();
            if greedy_argmax(&logits) == d {
                n_accepted += 1;
            } else {
                break;
            }
        }
        n_draft_accepted += n_accepted;

        // Token real: predicción en la primera posición de desacuerdo
        // (o tras el último draft si todos fueron aceptados).
        let real = greedy_argmax(
            &mtp
                .target_context()
                .get_logits_ith(n_accepted as i32)
                .to_vec(),
        );

        mtp.accept(n_accepted as u16).expect("accept");

        // Emitir aceptados + real.
        for &d in drafts.iter().take(n_accepted) {
            print!("{}", piece_of(&model, d));
        }
        print!("{}", piece_of(&model, real));
        n_emitted += n_accepted + 1;

        // El primer token no válido tras id_last + aceptados está en
        // n_past + 1 + n_accepted → borrarlo de target y draft ctx.
        let rollback_from = n_past + 1 + n_accepted as i32;
        mtp.target_context_mut()
            .kv_cache_seq_rm(0, Some(rollback_from as u32), None)
            .expect("kv rollback tgt");
        mtp.draft_context_mut()
            .kv_cache_seq_rm(0, Some(rollback_from as u32), None)
            .expect("kv rollback dft");
        n_past = rollback_from;
        last_token = real;

        if n_emitted >= max_tokens {
            println!();
            break;
        }
    }

    // ── Resumen ──
    let rate = if n_draft_proposals > 0 {
        n_draft_accepted as f32 / n_draft_proposals as f32
    } else {
        0.0
    };
    println!("\n=== RESUMEN MTP ===");
    println!(
        "tokens emitidos={n_emitted}  verify_steps={n_verify_steps}  drafts propuestos={n_draft_proposals}  aceptados={n_draft_accepted}"
    );
    println!("tasa aceptación={rate:.3}");
    // Mismo modelo que speculative_decoder::projected_speedup: cada verificación
    // del target produce 1 + p·K tokens (costo del draft ignorado).
    let p = 1.0 + rate * n_max as f32;
    println!("speedup proyectado (n_max={n_max}, p={rate:.3}) = {p:.2}x");
    println!("RESULTADO: loop MTP OK");
}