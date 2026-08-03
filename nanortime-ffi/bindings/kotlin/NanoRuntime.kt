package com.nanoai.runtime

/**
 * Kotlin JNI / FFI Wrapper for NanoAI Engine on Android (libnanortime_ffi.so).
 *
 * Provides a clean, idiomatic Kotlin API for loading GGUF LLM models locally on Android devices,
 * managing memory context, and executing local text generation.
 *
 * Example Usage:
 * ```kotlin
 * NanoRuntime.initBackend()
 * val model = NanoRuntime.loadModel("/sdcard/Download/qwen2.5-1.5b-instruct-q4_k_m.gguf", gpuLayers = 0)
 * val context = model.createContext(contextSize = 2048)
 * val response = context.generate("Explain quantum computing in 2 sentences.", maxTokens = 200)
 * println(response)
 * context.close()
 * model.close()
 * ```
 */
class NanoRuntime private constructor() {

    class Model private constructor(internal val handle: Long) : AutoCloseable {
        companion object {
            @JvmStatic
            private external fun nativeFreeModel(handle: Long)
        }

        fun createContext(contextSize: Int = 2048): Context {
            require(handle != 0L) { "Model handle is closed or invalid." }
            val ctxHandle = nativeCreateContext(handle, contextSize)
            check(ctxHandle != 0L) { "Failed to create NanoContext with size $contextSize" }
            return Context(ctxHandle, this)
        }

        override fun close() {
            if (handle != 0L) {
                nativeFreeModel(handle)
            }
        }
    }

    class Context internal constructor(
        internal val handle: Long,
        private val model: Model
    ) : AutoCloseable {
        companion object {
            @JvmStatic
            private external fun nativeFreeContext(handle: Long)
            @JvmStatic
            private external fun nativeGenerate(
                ctxHandle: Long,
                modelHandle: Long,
                prompt: String,
                maxTokens: Int,
                temperature: Float,
                topP: Float
            ): String?
        }

        fun generate(
            prompt: String,
            maxTokens: Int = 512,
            temperature: Float = 0.7f,
            topP: Float = 0.9f
        ): String {
            require(handle != 0L) { "Context handle is closed or invalid." }
            require(model.handle != 0L) { "Model handle is closed or invalid." }
            val result = nativeGenerate(handle, model.handle, prompt, maxTokens, temperature, topP)
            return result ?: throw RuntimeException("NanoAI generation failed or returned null")
        }

        override fun close() {
            if (handle != 0L) {
                nativeFreeContext(handle)
            }
        }
    }

    companion object {
        init {
            System.loadLibrary("nanortime_ffi")
        }

        @JvmStatic
        private external fun nativeInitBackend(): Int

        @JvmStatic
        private external fun nativeLoadModel(path: String, gpuLayers: Int): Long

        @JvmStatic
        private external fun nativeCreateContext(modelHandle: Long, contextSize: Int): Long

        fun initBackend() {
            val code = nativeInitBackend()
            check(code == 0) { "Failed to initialize llama.cpp backend on Android" }
        }

        fun loadModel(modelPath: String, gpuLayers: Int = 0): Model {
            val handle = nativeLoadModel(modelPath, gpuLayers)
            check(handle != 0L) { "Failed to load GGUF model from path: $modelPath" }
            return Model(handle)
        }
    }
}
