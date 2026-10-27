package dev.nanoai.mobile.runtime

import kotlinx.coroutines.sync.Mutex

/** QUÉ: una frontera de propiedad para LiteRT y MNN en todo el proceso.
 * CÓMO: carga, generación y cierre comparten mutex; el cierre previo ocurre dentro.
 * POR QUÉ: UI/headless no pueden conservar dos motores ni cerrar JNI durante decode. */
object LocalModelGate {
    val mutex = Mutex()
    @Volatile private var engineId: String? = null
    @Volatile private var path: String? = null
    private var closeOwner: (() -> Unit)? = null
    @Volatile private var cancelOwner: (() -> Unit)? = null

    // Cancelar no toma el mutex: el decoder lo mantiene hasta salir.
    fun cancelForReplacement(engine: String, modelPath: String) {
        if (engineId != engine || path != modelPath) cancelOwner?.invoke()
    }

    // Solo se invoca con mutex adquirido; primero Conversation y después Engine.
    fun claimLocked(engine: String, modelPath: String, close: () -> Unit, cancel: () -> Unit) {
        if (engineId != engine || path != modelPath) {
            closeOwner?.invoke()
            engineId = engine
            path = modelPath
        }
        closeOwner = close
        cancelOwner = cancel
    }

    fun releaseLocked(engine: String) {
        if (engineId != engine) return
        engineId = null
        path = null
        closeOwner = null
        cancelOwner = null
    }
}
