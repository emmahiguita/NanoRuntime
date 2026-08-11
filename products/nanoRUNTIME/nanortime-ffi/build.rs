//! Build script for nanortime-ffi.
//!
//! llama-cpp-2 handles building llama.cpp from source automatically.
//! No manual C++ compilation needed.

use std::env;
use std::path::PathBuf;

fn main() {
    println!("cargo:rerun-if-changed=build.rs");

    // CUDA: garantizar el link de cudart/cublas/cublasLt (import libs) para
    // ggml-cuda. find_cuda_helper de llama-cpp-sys-2 puede fallar en detectar
    // el root; aquí se emite explícitamente el LIBPATH desde CUDA_PATH
    // (Windows: <CUDA_PATH>/lib/x64).
    for var in ["CUDA_PATH", "CUDA_ROOT", "CUDA_TOOLKIT_ROOT_DIR"] {
        println!("cargo:rerun-if-env-changed={var}");
        if let Ok(root) = env::var(var) {
            let lib64 = PathBuf::from(&root).join("lib").join("x64");
            if lib64.is_dir() {
                println!("cargo:rustc-link-search=native={}", lib64.display());
                break;
            }
        }
    }
}
