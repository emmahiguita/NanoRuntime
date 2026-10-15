// ─────────────────────────────────────────────────────────────────────────────
// commonMain · dev.nanoai.core.inference · InferenceEngine.kt
//
// QUÉ  : `expect class` que representa el motor de inferencia local.
//         Android  → LiteRT / MNN a través de JNI.
//         iOS      → CoreML + llama.cpp compilado con Metal.
// POR QUÉ: Toda la lógica de orquestación (timeout, throttling térmico,
//           cancelación) vive una sola vez en commonMain. Solo la llamada
//           nativa al motor varía por plataforma.
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core.inference

import kotlinx.coroutines.flow.Flow

/** Resultado de un token generado por el motor. */
data class TokenResult(
    val token: String,
    /** true cuando este es el último token del turno. */
    val isEnd: Boolean,
)

/**
 * Motor de inferencia local multiplataforma.
 *
 * Cada plataforma provee una implementación `actual`:
 * - **androidMain** : delega a [LiteRtEngineOwner] / MNN vía JNI ya existente.
 * - **iosMain**     : llama a llama.cpp con Metal o al proveedor CoreML.
 */
expect class InferenceEngine(modelPath: String, backend: String, threads: Int) {
    /** Carga los pesos del modelo en memoria. Idempotente si ya está cargado. */
    suspend fun load()

    /**
     * Genera tokens de forma reactiva dada una secuencia de prompt.
     * Emite [TokenResult] uno a uno hasta el token de fin de turno.
     * Lanza [ThermalAbortException] si el nivel térmico sube a SEVERE.
     */
    fun generate(prompt: String): Flow<TokenResult>

    /** Libera los pesos y cierra el handle nativo. */
    fun close()
}

/** Indica que la generación fue cancelada por sobrecalentamiento. */
class ThermalAbortException(message: String) : IllegalStateException(message)
