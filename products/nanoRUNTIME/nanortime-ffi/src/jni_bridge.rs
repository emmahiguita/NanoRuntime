//! jni_bridge.rs — JNI exports matching NanoRuntimeBridge.kt declarations.
//!
//! Feature-gated behind `android-jni`. Compile with:
//!   cargo build --lib --features android-jni --target aarch64-linux-android --release
//!
//! Kotlin declarations in NanoRuntimeBridge.kt:
//!   private external fun nativeInitBackend(): Int
//!   private external fun nativeLoadModel(path: String, gpuLayers: Int): Long
//!   private external fun nativeFreeModel(handle: Long)
//!   private external fun nativeGenerateText(modelPath, prompt, maxTokens, temperature): String

#[cfg(feature = "android-jni")]
mod exports {
    use jni::objects::{JClass, JString};
    use jni::sys::{jfloat, jint, jlong, jstring};
    use jni::JNIEnv;
    use std::sync::Mutex;

    static BACKEND_READY: Mutex<bool> = Mutex::new(false);

    fn init_backend_jni() -> jint {
        let mut ready = match BACKEND_READY.lock() {
            Ok(g) => g,
            Err(_) => return -1,
        };
        if *ready {
            return 0;
        }
        // SAFETY: init_backend is idempotent. First call initializes.
        let res = unsafe { crate::nano_backend_init() };
        if res == 0 {
            *ready = true;
        }
        res
    }

    fn load_model_jni(mut env: JNIEnv, path: JString, gpu_layers: jint) -> jlong {
        let path_str: String = match env.get_string(&path) {
            Ok(s) => s.into(),
            Err(_) => return 0,
        };
        let c_path = match std::ffi::CString::new(path_str.as_str()) {
            Ok(c) => c,
            Err(_) => return 0,
        };
        // SAFETY: c_path valid for the duration of the call.
        unsafe { crate::nano_model_load(c_path.as_ptr(), gpu_layers) as jlong }
    }

    fn create_context_jni(model_handle: jlong, context_size: jint) -> jlong {
        if model_handle == 0 {
            return 0;
        }
        let size = if context_size <= 0 {
            2048
        } else {
            context_size as u32
        };
        // SAFETY: handle must come from nativeLoadModel and remain alive.
        unsafe {
            crate::nano_context_create(model_handle as *const crate::NanoModel, size) as jlong
        }
    }

    fn free_model_jni(handle: jlong) {
        if handle != 0 {
            // SAFETY: handle from nativeLoadModel, not yet freed, and all contexts freed first.
            unsafe {
                crate::nano_model_free(handle as *mut crate::NanoModel);
            }
        }
    }

    fn free_context_jni(handle: jlong) {
        if handle != 0 {
            // SAFETY: handle from nativeCreateContext, not yet freed.
            unsafe {
                crate::nano_context_free(handle as *mut crate::NanoContext);
            }
        }
    }

    fn generate_jni(
        mut env: JNIEnv,
        ctx_handle: jlong,
        model_handle: jlong,
        prompt: JString,
        max_tokens: jint,
        temperature: jfloat,
        top_p: jfloat,
    ) -> jstring {
        if ctx_handle == 0 || model_handle == 0 {
            return std::ptr::null_mut();
        }
        let prompt_str: String = match env.get_string(&prompt) {
            Ok(s) => s.into(),
            Err(_) => return std::ptr::null_mut(),
        };
        let c_prompt = match std::ffi::CString::new(prompt_str.as_str()) {
            Ok(c) => c,
            Err(_) => return std::ptr::null_mut(),
        };

        // SAFETY: handles come from this library and C string lives through the call.
        unsafe {
            let out = crate::nano_generate(
                ctx_handle as *mut crate::NanoContext,
                model_handle as *const crate::NanoModel,
                c_prompt.as_ptr(),
                max_tokens.max(1) as u32,
                temperature,
                top_p,
            );
            if out.is_null() {
                return std::ptr::null_mut();
            }
            let text = std::ffi::CStr::from_ptr(out).to_string_lossy().into_owned();
            crate::nano_string_free(out);
            env.new_string(&text)
                .map(|s| s.into_raw())
                .unwrap_or(std::ptr::null_mut())
        }
    }

    fn supports_mtp_jni(model_handle: jlong) -> jboolean {
        if model_handle == 0 {
            return 0;
        }
        // SAFETY: handle from nativeLoadModel, alive for the call.
        unsafe { crate::nano_model_supports_mtp(model_handle as *const crate::NanoModel) as jboolean }
    }

    fn generate_mtp_jni(
        mut env: JNIEnv,
        ctx_handle: jlong,
        model_handle: jlong,
        prompt: JString,
        max_tokens: jint,
        temperature: jfloat,
        top_p: jfloat,
        n_max: jint,
    ) -> jstring {
        if ctx_handle == 0 || model_handle == 0 {
            return std::ptr::null_mut();
        }
        let prompt_str: String = match env.get_string(&prompt) {
            Ok(s) => s.into(),
            Err(_) => return std::ptr::null_mut(),
        };
        let c_prompt = match std::ffi::CString::new(prompt_str.as_str()) {
            Ok(c) => c,
            Err(_) => return std::ptr::null_mut(),
        };

        // SAFETY: handles from this library, C string lives through the call.
        unsafe {
            let out = crate::nano_context_generate_mtp(
                ctx_handle as *mut crate::NanoContext,
                model_handle as *const crate::NanoModel,
                c_prompt.as_ptr(),
                max_tokens.max(1) as u32,
                temperature,
                top_p,
                n_max.max(1),
            );
            if out.is_null() {
                return std::ptr::null_mut();
            }
            let text = std::ffi::CStr::from_ptr(out).to_string_lossy().into_owned();
            crate::nano_string_free(out);
            env.new_string(&text)
                .map(|s| s.into_raw())
                .unwrap_or(std::ptr::null_mut())
        }
    }

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_data_runtime_NanoRuntimeBridge_nativeInitBackend(
        _env: JNIEnv,
        _class: JClass,
    ) -> jint {
        init_backend_jni()
    }

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_data_runtime_NanoRuntimeBridge_nativeLoadModel(
        mut env: JNIEnv,
        _class: JClass,
        path: JString,
        gpu_layers: jint,
    ) -> jlong {
        load_model_jni(env, path, gpu_layers)
    }

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_data_runtime_NanoRuntimeBridge_nativeFreeModel(
        _env: JNIEnv,
        _class: JClass,
        handle: jlong,
    ) {
        free_model_jni(handle)
    }

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_data_runtime_NanoRuntimeBridge_nativeGenerateText(
        mut env: JNIEnv,
        _class: JClass,
        model_path: JString,
        prompt: JString,
        max_tokens: jint,
        temperature: jfloat,
    ) -> jstring {
        // Extract JNI strings
        let (path_str, prompt_str): (String, String) = {
            let p: String = match env.get_string(&model_path) {
                Ok(s) => s.into(),
                Err(_) => {
                    return env
                        .new_string("Error: invalid model path")
                        .map(|s| s.into_raw())
                        .unwrap_or(std::ptr::null_mut());
                }
            };
            let pr: String = match env.get_string(&prompt) {
                Ok(s) => s.into(),
                Err(_) => {
                    return env
                        .new_string("Error: invalid prompt")
                        .map(|s| s.into_raw())
                        .unwrap_or(std::ptr::null_mut());
                }
            };
            (p, pr)
        };

        let c_path = match std::ffi::CString::new(path_str.as_str()) {
            Ok(c) => c,
            Err(_) => return std::ptr::null_mut(),
        };
        let c_prompt = match std::ffi::CString::new(prompt_str.as_str()) {
            Ok(c) => c,
            Err(_) => return std::ptr::null_mut(),
        };

        // SAFETY: CStrings valid, load-generate-free pattern.
        unsafe {
            let model = crate::nano_model_load(c_path.as_ptr(), -1);
            if model.is_null() {
                return env
                    .new_string("Error: model load failed")
                    .map(|s| s.into_raw())
                    .unwrap_or(std::ptr::null_mut());
            }
            let ctx = crate::nano_context_create(model, 2048);
            if ctx.is_null() {
                crate::nano_model_free(model);
                return env
                    .new_string("Error: context creation failed")
                    .map(|s| s.into_raw())
                    .unwrap_or(std::ptr::null_mut());
            }
            let out = crate::nano_generate(
                ctx,
                model,
                c_prompt.as_ptr(),
                max_tokens as u32,
                temperature,
                0.9,
            );
            crate::nano_context_free(ctx);
            crate::nano_model_free(model);

            if out.is_null() {
                return env
                    .new_string("Error: generation failed")
                    .map(|s| s.into_raw())
                    .unwrap_or(std::ptr::null_mut());
            }
            let text = std::ffi::CStr::from_ptr(out).to_string_lossy().into_owned();
            crate::nano_string_free(out);
            env.new_string(&text)
                .map(|s| s.into_raw())
                .unwrap_or(std::ptr::null_mut())
        }
    }

    // Compatibility exports for nanortime-ffi/bindings/kotlin/NanoRuntime.kt
    // package com.nanoai.runtime. Kotlin companion-object natives may resolve
    // either to the containing class when @JvmStatic is used or to Companion.
    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_runtime_NanoRuntime_nativeInitBackend(
        _env: JNIEnv,
        _class: JClass,
    ) -> jint {
        init_backend_jni()
    }

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_runtime_NanoRuntime_00024Companion_nativeInitBackend(
        _env: JNIEnv,
        _class: JClass,
    ) -> jint {
        init_backend_jni()
    }

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_runtime_NanoRuntime_nativeLoadModel(
        env: JNIEnv,
        _class: JClass,
        path: JString,
        gpu_layers: jint,
    ) -> jlong {
        load_model_jni(env, path, gpu_layers)
    }

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_runtime_NanoRuntime_00024Companion_nativeLoadModel(
        env: JNIEnv,
        _class: JClass,
        path: JString,
        gpu_layers: jint,
    ) -> jlong {
        load_model_jni(env, path, gpu_layers)
    }

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_runtime_NanoRuntime_nativeCreateContext(
        _env: JNIEnv,
        _class: JClass,
        model_handle: jlong,
        context_size: jint,
    ) -> jlong {
        create_context_jni(model_handle, context_size)
    }

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_runtime_NanoRuntime_00024Companion_nativeCreateContext(
        _env: JNIEnv,
        _class: JClass,
        model_handle: jlong,
        context_size: jint,
    ) -> jlong {
        create_context_jni(model_handle, context_size)
    }

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_runtime_NanoRuntime_00024Model_nativeFreeModel(
        _env: JNIEnv,
        _class: JClass,
        handle: jlong,
    ) {
        free_model_jni(handle)
    }

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_runtime_NanoRuntime_00024Model_00024Companion_nativeFreeModel(
        _env: JNIEnv,
        _class: JClass,
        handle: jlong,
    ) {
        free_model_jni(handle)
    }

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_runtime_NanoRuntime_00024Context_nativeFreeContext(
        _env: JNIEnv,
        _class: JClass,
        handle: jlong,
    ) {
        free_context_jni(handle)
    }

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_runtime_NanoRuntime_00024Context_00024Companion_nativeFreeContext(
        _env: JNIEnv,
        _class: JClass,
        handle: jlong,
    ) {
        free_context_jni(handle)
    }

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_runtime_NanoRuntime_00024Context_nativeGenerate(
        env: JNIEnv,
        _class: JClass,
        ctx_handle: jlong,
        model_handle: jlong,
        prompt: JString,
        max_tokens: jint,
        temperature: jfloat,
        top_p: jfloat,
    ) -> jstring {
        generate_jni(
            env,
            ctx_handle,
            model_handle,
            prompt,
            max_tokens,
            temperature,
            top_p,
        )
    }

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_runtime_NanoRuntime_00024Context_00024Companion_nativeGenerate(
        env: JNIEnv,
        _class: JClass,
        ctx_handle: jlong,
        model_handle: jlong,
        prompt: JString,
        max_tokens: jint,
        temperature: jfloat,
        top_p: jfloat,
    ) -> jstring {
        generate_jni(
            env,
            ctx_handle,
            model_handle,
            prompt,
            max_tokens,
            temperature,
            top_p,
        )
    }

    // ── MTP exports ────────────────────────────────────────────────────────

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_data_runtime_NanoRuntimeBridge_nativeSupportsMtp(
        _env: JNIEnv,
        _class: JClass,
        model_handle: jlong,
    ) -> jboolean {
        supports_mtp_jni(model_handle)
    }

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_data_runtime_NanoRuntimeBridge_nativeGenerateMtp(
        mut env: JNIEnv,
        _class: JClass,
        ctx_handle: jlong,
        model_handle: jlong,
        prompt: JString,
        max_tokens: jint,
        temperature: jfloat,
        top_p: jfloat,
        n_max: jint,
    ) -> jstring {
        generate_mtp_jni(
            env,
            ctx_handle,
            model_handle,
            prompt,
            max_tokens,
            temperature,
            top_p,
            n_max,
        )
    }

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_runtime_NanoRuntime_00024Context_nativeSupportsMtp(
        _env: JNIEnv,
        _class: JClass,
        model_handle: jlong,
    ) -> jboolean {
        supports_mtp_jni(model_handle)
    }

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_runtime_NanoRuntime_00024Context_00024Companion_nativeSupportsMtp(
        _env: JNIEnv,
        _class: JClass,
        model_handle: jlong,
    ) -> jboolean {
        supports_mtp_jni(model_handle)
    }

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_runtime_NanoRuntime_00024Context_nativeGenerateMtp(
        mut env: JNIEnv,
        _class: JClass,
        ctx_handle: jlong,
        model_handle: jlong,
        prompt: JString,
        max_tokens: jint,
        temperature: jfloat,
        top_p: jfloat,
        n_max: jint,
    ) -> jstring {
        generate_mtp_jni(
            env,
            ctx_handle,
            model_handle,
            prompt,
            max_tokens,
            temperature,
            top_p,
            n_max,
        )
    }

    #[no_mangle]
    pub extern "system" fn Java_com_nanoai_runtime_NanoRuntime_00024Context_00024Companion_nativeGenerateMtp(
        mut env: JNIEnv,
        _class: JClass,
        ctx_handle: jlong,
        model_handle: jlong,
        prompt: JString,
        max_tokens: jint,
        temperature: jfloat,
        top_p: jfloat,
        n_max: jint,
    ) -> jstring {
        generate_mtp_jni(
            env,
            ctx_handle,
            model_handle,
            prompt,
            max_tokens,
            temperature,
            top_p,
            n_max,
        )
    }
}
