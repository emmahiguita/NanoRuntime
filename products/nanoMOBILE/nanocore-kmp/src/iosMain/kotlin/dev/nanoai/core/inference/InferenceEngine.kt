// ─────────────────────────────────────────────────────────────────────────────
// iosMain · dev.nanoai.core.inference · InferenceEngine.kt
//
// QUÉ  : `actual class InferenceEngine` para iOS.
//         Usa llama.cpp compilado con Metal como backend de inferencia local.
// CÓMO : llama.cpp expone una API en C. Kotlin/Native la consume a través del
//         cinterop definido en nanocore-kmp/src/nativeInterop/cinterop/llama.def.
//         CoreML puede activarse pasando backend = "coreml".
// POR QUÉ: El contrato (load/generate/close) es idéntico al Android; toda la
//           orquestación de ThermalPolicy y ModelGate viene de commonMain.
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core.inference

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.sync.withLock

// llama.cpp cinterop — bindings generados por Kotlin/Native desde llama.def
// import llama.*    // <-- activo cuando el cinterop esté configurado

actual class InferenceEngine actual constructor(
    private val modelPath: String,
    private val backend: String,    // "metal" | "coreml" | "cpu"
    private val threads: Int,
) {
    // Handle nativo del modelo llama.cpp (Long es suficiente para un puntero C).
    @Volatile private var nativeHandle: Long = 0L

    actual suspend fun load() {
        ModelGate.cancelForReplacement("llama_ios", modelPath)
        ModelGate.mutex.withLock {
            ThermalPolicy.checkAdmission()
            if (nativeHandle != 0L) return   // ya cargado

            // TODO: sustituir por llamada cinterop real cuando llama.def esté generado.
            // nativeHandle = llama_load_model(modelPath, backend, threads)
            nativeHandle = NativeLlamaBridge.load(modelPath, backend, threads)

            ModelGate.claimLocked(
                engine = "llama_ios",
                path   = modelPath,
                close  = { NativeLlamaBridge.close(nativeHandle); nativeHandle = 0L },
                cancel = { NativeLlamaBridge.cancelGeneration(nativeHandle) },
            )
        }
    }

    actual fun generate(prompt: String): Flow<TokenResult> = flow {
        ThermalPolicy.checkAdmission()
        check(nativeHandle != 0L) { "Motor no cargado — llama load() primero" }

        NativeLlamaBridge.streamTokens(nativeHandle, prompt) { token, isEnd ->
            if (ThermalPolicy.warmIdleTimeoutMs(90_000L) == 0L) {
                throw ThermalAbortException("THERMAL_PAUSED: generación cancelada por temperatura")
            }
            emit(TokenResult(token, isEnd))
        }
    }

    actual fun close() {
        if (nativeHandle != 0L) {
            NativeLlamaBridge.close(nativeHandle)
            nativeHandle = 0L
        }
    }
}

/**
 * Stub del bridge nativo hacia llama.cpp para iOS.
 * Cada función se implementará con llamadas cinterop al compilar con Kotlin/Native.
 *
 * Estas funciones apuntan a los símbolos del archivo llama.h que llama.cpp
 * ya expone; el archivo llama.def le indica al compilador cómo generarlas.
 */
internal object NativeLlamaBridge {
    fun load(modelPath: String, backend: String, threads: Int): Long {
        // Implementación real: llama_model_load_from_file() + llama_new_context_with_model()
        TODO("Implementar cinterop con llama.cpp/Metal")
    }
    fun streamTokens(handle: Long, prompt: String, emit: suspend (String, Boolean) -> Unit) {
        // Implementación real: llama_decode() loop → emit token por token
        TODO("Implementar cinterop con llama.cpp/Metal")
    }
    fun cancelGeneration(handle: Long) { /* llama_decode_abort si disponible */ }
    fun close(handle: Long) { /* llama_free */ }
}
