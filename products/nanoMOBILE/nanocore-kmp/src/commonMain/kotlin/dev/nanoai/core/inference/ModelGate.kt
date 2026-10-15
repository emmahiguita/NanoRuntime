// ─────────────────────────────────────────────────────────────────────────────
// commonMain · dev.nanoai.core.inference · ModelGate.kt
//
// QUÉ  : Barrera de propiedad del motor de inferencia activo.
//         Garantiza que nunca haya dos motores cargados simultáneamente y que
//         el motor anterior se cierre antes de cargar uno nuevo.
// POR QUÉ: La lógica de sincronización (mutex + callbacks) es idéntica en
//           Android (LiteRT/MNN) y en iOS (CoreML). Compartirla elimina bugs
//           de duplicación.
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core.inference

import kotlinx.coroutines.sync.Mutex

/**
 * Singleton de alcance de proceso que protege el motor de inferencia.
 * Thread-safe mediante [Mutex] de coroutines (100 % Kotlin puro).
 */
object ModelGate {
    val mutex = Mutex()

    @Volatile private var engineId: String? = null
    @Volatile private var modelPath: String? = null
    private var closeCallback: (() -> Unit)? = null
    @Volatile private var cancelCallback: (() -> Unit)? = null

    /**
     * Cancela el motor activo si el nuevo motor o path difieren.
     * No toma el mutex: el decoder lo mantiene hasta salir.
     */
    fun cancelForReplacement(engine: String, path: String) {
        if (engineId != engine || modelPath != path) cancelCallback?.invoke()
    }

    /**
     * Registra el nuevo propietario del motor (debe llamarse con [mutex] adquirido).
     * Si el engine o path cambian, cierra el anterior primero.
     */
    fun claimLocked(engine: String, path: String, close: () -> Unit, cancel: () -> Unit) {
        if (engineId != engine || modelPath != path) {
            closeCallback?.invoke()
            engineId = engine
            modelPath = path
        }
        closeCallback = close
        cancelCallback = cancel
    }

    /** Libera el motor (debe llamarse con [mutex] adquirido). */
    fun releaseLocked(engine: String) {
        if (engineId != engine) return
        engineId = null
        modelPath = null
        closeCallback = null
        cancelCallback = null
    }
}
