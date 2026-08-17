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

    class Model private constructor(internal var handle: Long) : AutoCloseable {
        private val contexts = LinkedHashSet<Context>()

        companion object {
            @JvmStatic
            private external fun nativeFreeModel(handle: Long)
        }

        @Synchronized
        fun createContext(contextSize: Int = 2048): Context {
            require(handle != 0L) { "Model handle is closed or invalid." }
            val ctxHandle = nativeCreateContext(handle, contextSize)
            check(ctxHandle != 0L) { "Failed to create NanoContext with size $contextSize" }
            return Context(ctxHandle, this).also { contexts.add(it) }
        }

        @Synchronized
        override fun close() {
            // Contexts hold native pointers into model-owned llama.cpp memory.
            // Free them first so Model.close() is safe even if callers forget
            // to close every child Context explicitly.
            val openContexts = contexts.toList()
            contexts.clear()
            openContexts.forEach { it.closeFromModel() }

            val currentHandle = handle
            if (currentHandle != 0L) {
                handle = 0L
                nativeFreeModel(currentHandle)
            }
        }

        @Synchronized
        internal fun unregister(context: Context) {
            contexts.remove(context)
        }

        @Synchronized
        internal fun currentHandle(): Long {
            require(handle != 0L) { "Model handle is closed or invalid." }
            return handle
        }
    }

    class Context internal constructor(
        internal var handle: Long,
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
            @JvmStatic
            private external fun nativeSupportsMtp(modelHandle: Long): Boolean
            @JvmStatic
            private external fun nativeGenerateMtp(
                ctxHandle: Long,
                modelHandle: Long,
                prompt: String,
                maxTokens: Int,
                temperature: Float,
                topP: Float,
                nMax: Int
            ): String?
        }

        fun generate(
            prompt: String,
            maxTokens: Int = 512,
            temperature: Float = 0.7f,
            topP: Float = 0.9f
        ): String {
            // Lock order is always Model -> Context. This prevents races where
            // Model.close() frees model-owned memory while nativeGenerate() is
            // using both handles, and avoids deadlocks with Model.close().
            val result = synchronized(model) {
                synchronized(this) {
                    require(handle != 0L) { "Context handle is closed or invalid." }
                    val modelHandle = model.currentHandle()
                    nativeGenerate(handle, modelHandle, prompt, maxTokens, temperature, topP)
                }
            }
            return result ?: throw RuntimeException("NanoAI generation failed or returned null")
        }

        /**
         * True si el GGUF cargado tiene cabezas NextN (MTP). Los modelos
         * Qwen3.5-MTP lo exponen; usarlo antes de [generateMtp] para evitar
         * crear el engine MTP con un modelo sin soporte (error nativo).
         */
        fun supportsMtp(): Boolean {
            synchronized(model) {
                require(handle != 0L) { "Context handle is closed or invalid." }
                return nativeSupportsMtp(model.currentHandle())
            }
        }

        /**
         * Genera con speculative MTP (drafts del mismo modelo vía NextN).
         *
         * Requiere un modelo con cabezas NextN (ver [supportsMtp]). `nMax` =
         * drafts por verificación: 1 es el óptimo medido en CPU (1.2-1.4x);
         * valores >3 degradan. La salida es distribuicionalmente idéntica a
         * [generate] (lossless).
         */
        fun generateMtp(
            prompt: String,
            maxTokens: Int = 512,
            temperature: Float = 0.7f,
            topP: Float = 0.9f,
            nMax: Int = 1
        ): String {
            val result = synchronized(model) {
                synchronized(this) {
                    require(handle != 0L) { "Context handle is closed or invalid." }
                    val modelHandle = model.currentHandle()
                    nativeGenerateMtp(handle, modelHandle, prompt, maxTokens, temperature, topP, nMax)
                }
            }
            return result ?: throw RuntimeException("NanoAI MTP generation failed or returned null")
        }

        override fun close() {
            synchronized(model) {
                closeFromModel()
                model.unregister(this)
            }
        }

        internal fun closeFromModel() {
            synchronized(this) {
                val currentHandle = handle
                if (currentHandle != 0L) {
                    handle = 0L
                    nativeFreeContext(currentHandle)
                }
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
