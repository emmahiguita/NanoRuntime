//! Probe: cantidad de capas MTP (nextn) del modelo.
//! Decide si el modelo habilita speculative MTP.
//!
//! Uso:
//!   cargo run -p nanortime-core --example mtp_probe -- [ruta.gguf]

use llama_cpp_2::llama_backend::LlamaBackend;
use llama_cpp_2::model::params::LlamaModelParams;
use llama_cpp_2::model::LlamaModel;
use std::path::PathBuf;

fn main() {
    let default = concat!(env!("CARGO_MANIFEST_DIR"), "/../../data/qwen_tmp.gguf");
    let path = std::env::args()
        .nth(1)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(default));
    if !path.exists() {
        eprintln!("ERROR: no existe {}", path.display());
        std::process::exit(1);
    }

    let backend = LlamaBackend::init().expect("backend init");
    let params = LlamaModelParams::default()
        .with_use_mmap(true)
        .with_n_gpu_layers(0);
    let model =
        LlamaModel::load_from_file(&backend, path.as_path(), &params).expect("cargar modelo");

    let n_layer = unsafe { llama_cpp_sys_2::llama_model_n_layer_nextn(model.as_ptr()) };
    let n_embd = model.n_embd();
    let n_ctx = model.n_ctx_train();
    println!(
        "modelo: {}  n_layer={}  n_layer_nextn(MTP)={}  n_embd_out={}  n_ctx_train={}",
        path.display(),
        unsafe { llama_cpp_sys_2::llama_model_n_layer(model.as_ptr()) },
        n_layer,
        n_embd,
        n_ctx
    );
    if n_layer > 0 {
        println!("RESULTADO: modelo CON cabezas MTP ({n_layer}) — speculative draft-mtp viable");
    } else {
        println!(
            "RESULTADO: modelo SIN cabezas MTP — draft-mtp inviable, requerir modelo MTP-trained"
        );
    }
}
