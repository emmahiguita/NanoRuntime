package dev.nanoai.mobile.services.whatsapp

import android.os.SystemClock

/** Registro efímero del intento actual. Distingue apertura, clic y retorno:
 * ninguna de estas señales acredita entrega al destinatario ni lectura.
 * El contador evita que un observador atribuya la siguiente tarea a la anterior. */
object WhatsAppSendProgress {
    private var sequence = 0L
    private var state = "idle"
    private var clicked = false
    private var returned = false
    private var startedAt = 0L
    private var detail = ""

    @Synchronized fun begin() {
        sequence++
        state = "waiting"
        clicked = false
        returned = false
        startedAt = SystemClock.elapsedRealtime()
        detail = "Esperando la interfaz de WhatsApp."
    }
    @Synchronized fun finishClick(ok: Boolean, message: String) {
        if (clicked) return
        clicked = ok
        state = if (ok) "clicked" else "stopped"
        detail = message
    }
    @Synchronized fun finishReturn(ok: Boolean) {
        returned = ok
        state = if (ok) "returned" else "return_unverified"
        detail = if (ok) "Clic y regreso a Nano observados; entrega no confirmada."
            else "Clic observado; no se confirmó el regreso a Nano."
    }
    @Synchronized fun snapshot(): Map<String, Any> = mapOf(
        "operationId" to sequence, "state" to state, "clicked" to clicked,
        "returned" to returned, "detail" to detail,
        "elapsedMs" to if (startedAt == 0L) 0L else SystemClock.elapsedRealtime() - startedAt,
    )
}
