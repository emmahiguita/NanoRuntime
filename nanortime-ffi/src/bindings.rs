//! Bindings de C para el puente FFI.
//!
//! Expone las funciones del bridge como símbolos C planos
//! para que puedan ser llamados desde C/C++ o desde Rust via FFI.

// These extern "C" functions are implemented in bridge.cpp
// and linked statically.

extern "C" {
    /// Inicializa el backend de llama.cpp.
    pub fn nanortime_backend_init() -> i32;

    /// Libera recursos del backend.
    pub fn nanortime_backend_free();

    /// Carga un modelo GGUF desde disco.
    /// Retorna un puntero opaco al modelo, o null si falla.
    pub fn nanortime_load_model(
        path: *const std::os::raw::c_char,
        context_size: i32,
        gpu_layers: i32,
        use_mmap: i32,
    ) -> *mut std::os::raw::c_void;

    /// Libera un modelo cargado.
    pub fn nanortime_free_model(model: *mut std::os::raw::c_void);

    /// Crea un contexto de inferencia.
    pub fn nanortime_create_context(
        model: *mut std::os::raw::c_void,
        context_size: i32,
        threads: i32,
        batch_size: i32,
    ) -> *mut std::os::raw::c_void;

    /// Libera un contexto.
    pub fn nanortime_free_context(ctx: *mut std::os::raw::c_void);

    /// Tokeniza texto.
    /// Retorna el número de tokens; los IDs se escriben en `tokens_out`.
    pub fn nanortime_tokenize(
        ctx: *mut std::os::raw::c_void,
        text: *const std::os::raw::c_char,
        add_bos: i32,
        tokens_out: *mut i32,
        max_tokens: i32,
    ) -> i32;

    /// Ejecuta inferencia.
    /// Retorna 0 en éxito, código de error en fallo.
    pub fn nanortime_eval(
        ctx: *mut std::os::raw::c_void,
        tokens: *const i32,
        n_tokens: i32,
        n_past: i32,
        logits_out: *mut f32,
        logits_size: i32,
    ) -> i32;

    /// Obtiene el tamaño del vocabulario.
    pub fn nanortime_vocab_size(ctx: *mut std::os::raw::c_void) -> i32;
}

#[cfg(test)]
mod tests {
    // These tests would require the actual C++ bridge to be compiled.
    // For now, they're skipped in CI unless llama.cpp is present.

    #[test]
    #[ignore = "Requires compiled llama.cpp bridge"]
    fn test_backend_init() {
        let result = unsafe { super::nanortime_backend_init() };
        assert_eq!(result, 0); // 0 = success
    }
}
