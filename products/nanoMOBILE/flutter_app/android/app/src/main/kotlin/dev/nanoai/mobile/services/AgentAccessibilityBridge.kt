package dev.nanoai.mobile.services

import android.util.Log
import dev.nanoai.mobile.services.whatsapp.WhatsAppReturnController
import dev.nanoai.mobile.services.whatsapp.WhatsAppSendProgress

/** Único propietario del intento automático. Publica clic y retorno por separado,
 * limita la espera y cancela callbacks al perder el servicio. No acredita entrega. */
object AgentAccessibilityBridge {
    @Volatile
    var service: AgentAccessibilityService? = null
        private set

    @Volatile
    var lastEvent: WindowEventSnapshot? = null
        private set

    @Volatile
    var isAutoSendArmed: Boolean = false
        private set

    @Volatile
    private var autoSendDeadlineMs: Long = 0L

    @Volatile
    private var autoSendTargetPkg: String? = null

    @Volatile
    private var autoSendTargetContact: String? = null

    @Volatile
    private var autoSendExpectedAlias: String? = null

    private var autoSendExpectedText: String? = null
    private var autoSendDocumentName: String? = null
    private var tickScheduled = false

    // Devuelve el resultado del click a quien programó el envío; abrir WhatsApp no basta.
    private var autoSendResult: ((Boolean, String) -> Unit)? = null

    private val autoSendRunnable = object : Runnable {
        override fun run() {
            tickScheduled = false
            if (!isAutoSendArmed) return
            val s = service
            if (s == null || android.os.SystemClock.elapsedRealtime() > autoSendDeadlineMs) {
                completeAutoSend(false, if (s == null) "Accesibilidad se desconectó." else "No se confirmó el clic de envío.")
                return
            }

            val executed = s.performAutoSendAndReturn(autoSendTargetPkg, autoSendTargetContact, autoSendExpectedAlias, autoSendExpectedText, autoSendDocumentName)
            if (executed) {
                completeAutoSend(true, "Acción de envío pulsada; entrega no confirmada por WhatsApp.")
            } else {
                // Intervalo acotado para que WhatsApp monte la vista sin consultar el árbol cada 120 ms.
                scheduleTick(s, 220)
            }
        }
    }

    private val listeners = java.util.concurrent.CopyOnWriteArrayList<AccessibilityEventListener>()

    fun addListener(listener: AccessibilityEventListener) {
        listeners.add(listener)
    }

    fun removeListener(listener: AccessibilityEventListener) {
        listeners.remove(listener)
    }

    fun onConnected(s: AgentAccessibilityService) {
        service = s
    }

    fun onDisconnected(disconnected: AgentAccessibilityService) {
        // Un onDestroy tardío de la instancia anterior no puede cancelar al
        // servicio nuevo que Android ya reconectó durante una actualización.
        if (service !== disconnected) return
        // BUG-01 FIX: Cancelar el runnable ANTES de nulificar service.
        // El Handler pertenece al main looper y vive después del Service.
        // Sin removeCallbacks aquí, autoSendRunnable sigue disparándose cada 120ms
        // con service=null → loop zombi en main looper → degradación de ANR.
        val s = service
        if (s != null) {
            s.mainThreadHandler.removeCallbacks(autoSendRunnable)
        }
        WhatsAppReturnController.cancel()
        completeAutoSend(false, "Accesibilidad desconectada antes del envío.")
        service = null
        lastEvent = null
        listeners.clear()
    }

    fun armAutoSendAndReturn(
        targetPkg: String? = null,
        targetContact: String? = null,
        expectedAlias: String? = null,
        timeoutMs: Long = 12_000L,
        expectedText: String? = null,
        documentName: String? = null,
        onResult: ((Boolean, String) -> Unit)? = null,
    ): Boolean {
        val s = service ?: return false
        // Otra tarea no puede reemplazar el destinatario de una acción pendiente.
        if (isAutoSendArmed || WhatsAppReturnController.isReturning) return false
        WhatsAppSendProgress.begin()
        isAutoSendArmed = true
        dev.nanoai.mobile.services.whatsapp.WhatsAppAutoSendController.resetSession()
        autoSendDeadlineMs = android.os.SystemClock.elapsedRealtime() + timeoutMs
        autoSendTargetPkg = targetPkg
        autoSendTargetContact = targetContact
        autoSendExpectedAlias = expectedAlias
        autoSendExpectedText = expectedText
        autoSendDocumentName = documentName
        autoSendResult = onResult
        s.mainThreadHandler.removeCallbacks(autoSendRunnable)
        // Revisar tras un breve lapso para que la ventana de WhatsApp inicie
        scheduleTick(s, 150)
        return true
    }

    // Cierra una sola vez el ciclo y libera Handler/destinatario incluso ante timeout.
    private fun completeAutoSend(success: Boolean, message: String) {
        val wasArmed = isAutoSendArmed
        val s = service
        s?.mainThreadHandler?.removeCallbacks(autoSendRunnable)
        isAutoSendArmed = false
        val callback = autoSendResult
        autoSendResult = null
        autoSendTargetContact = null
        autoSendExpectedAlias = null
        autoSendExpectedText = null
        autoSendDocumentName = null
        tickScheduled = false
        autoSendTargetPkg = null
        dev.nanoai.mobile.services.whatsapp.WhatsAppAutoSendController.resetSession()
        if (wasArmed) {
            WhatsAppSendProgress.finishClick(success, message)
            val levelMessage = "Autoenvío finalizado: success=$success, detalle=$message"
            if (success) Log.i("nanoagent_autosend", levelMessage)
            else Log.w("nanoagent_autosend", levelMessage)
        }
        if (wasArmed && callback != null) {
            try {
                callback(success, message)
            } catch (error: Exception) {
                Log.e("nanoagent", "No se pudo registrar el resultado de autoenvío", error)
            }
        }
    }

    fun disarmAutoSend(reason: String = "Envío cancelado antes del clic.") {
        if (WhatsAppReturnController.isReturning) WhatsAppSendProgress.finishReturn(false)
        WhatsAppReturnController.cancel()
        completeAutoSend(false, reason)
    }

    /** Agrupa eventos ruidosos en un solo tick; leer el árbol también genera
     * eventos. Sin esta barrera se formaba una cola creciente en el hilo UI. */
    private fun scheduleTick(s: AgentAccessibilityService, delayMs: Long) {
        if (tickScheduled || !isAutoSendArmed) return
        tickScheduled = true
        s.mainThreadHandler.postDelayed(autoSendRunnable, delayMs)
    }

    fun notifyEvent(eventType: Int, packageName: String, className: String, timestamp: Long) {
        val snapshot = WindowEventSnapshot(eventType, packageName, className, timestamp)
        lastEvent = snapshot

        if (isAutoSendArmed && packageName.contains("whatsapp", ignoreCase = true)) {
            service?.let { scheduleTick(it, 80) }

        }

        for (listener in listeners) {
            try {
                listener.onEvent(snapshot)
            } catch (e: Exception) {
                Log.w("nanoagent", "Error notificando listener de a11y: ${e.message}")
            }
        }
    }
}
