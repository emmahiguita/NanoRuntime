// ─────────────────────────────────────────────────────────────────────────────
// androidMain · dev.nanoai.core.inference · InferenceEngine.kt
//
// QUÉ  : `actual class InferenceEngine` para Android.
//         Delega internamente al LiteRtEngineOwner / LiteRtGeneration
//         que ya existen en el módulo flutter_app.
// CÓMO : Al construir la clase se registra en ModelGate (commonMain).
//         generate() aplica ThermalPolicy.checkAdmission() antes de decodear.
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core.inference

import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.sync.withLock

// Estos tipos viven en el módulo flutter_app/android; se importan vía
// dependencia de proyecto (:nanoMOBILE:flutter_app:android).
import dev.nanoai.mobile.channels.LiteRtEngineOwner
import dev.nanoai.mobile.channels.LiteRtGeneration

actual class InferenceEngine actual constructor(
    private val modelPath: String,
    private val backend: String,
    private val threads: Int,
) {
    @Volatile private var owner: LiteRtEngineOwner? = null
    @Volatile private var generation: LiteRtGeneration? = null

    actual suspend fun load() {
        ModelGate.cancelForReplacement("litert", modelPath)
        ModelGate.mutex.withLock {
            ThermalPolicy.checkAdmission()
            // Reutiliza el motor si ya está cargado con el mismo path/backend.
            if (owner?.engine != null && owner?.modelPath == modelPath &&
                owner?.backend == backend && generation != null) return

            // LiteRtEngineOwner.load() es la función JNI existente.
            val newOwner = LiteRtEngineOwner.load(modelPath, backend, threads)
            val newGen   = LiteRtGeneration.create(newOwner)
            ModelGate.claimLocked("litert", modelPath,
                close  = { newGen.close(); newOwner.close() },
                cancel = { newGen.cancel() },
            )
            owner = newOwner
            generation = newGen
        }
    }

    actual fun generate(prompt: String): Flow<TokenResult> = flow {
        ThermalPolicy.checkAdmission()
        val gen = checkNotNull(generation) { "Motor no cargado — llama load() primero" }
        gen.streamTokens(prompt).collect { (token, isEnd) ->
            if (ThermalPolicy.warmIdleTimeoutMs(90_000L) == 0L) {
                throw ThermalAbortException("THERMAL_PAUSED: generación cancelada por temperatura")
            }
            emit(TokenResult(token, isEnd))
        }
    }

    actual fun close() {
        generation?.close()
        owner?.close()
        owner = null
        generation = null
    }
}
