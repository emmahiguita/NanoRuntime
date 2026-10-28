// ─────────────────────────────────────────────────────────────────────────────
// commonMain · dev.nanoai.core.agent · AgentLedger.kt
//
// QUÉ  : Memoria operativa del agente (historial de pasos podado).
//         Traducción directa de NanoTranscriptLedger.dart a Kotlin puro.
// CÓMO : Mantiene una lista doblemente enlazada (ArrayDeque) podada a
//         [maxSteps] pasos. Thread-safe mediante @Synchronized.
// POR QUÉ: La misma lógica de retención y poda se necesita en Android e iOS.
//           Un único archivo evita dos implementaciones que diverjan.
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core.agent

/** Un paso registrado en el ledger del agente. */
data class AgentStep(
    val role: String,          // "user" | "assistant" | "tool"
    val content: String,
    val timestampMs: Long,
)

/**
 * Historial podado con retención de los últimos [maxSteps] pasos.
 * Equivalente multiplataforma de NanoTranscriptLedger (Dart).
 */
class AgentLedger(private val maxSteps: Int = 2) {
    private val steps = ArrayDeque<AgentStep>(maxSteps + 1)

    @Synchronized
    fun append(step: AgentStep) {
        steps.addLast(step)
        while (steps.size > maxSteps) steps.removeFirst()
    }

    @Synchronized
    fun snapshot(): List<AgentStep> = steps.toList()

    @Synchronized
    fun clear() = steps.clear()
}
