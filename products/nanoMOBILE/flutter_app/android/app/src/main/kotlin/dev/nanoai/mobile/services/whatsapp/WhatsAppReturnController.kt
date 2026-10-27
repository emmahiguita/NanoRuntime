package dev.nanoai.mobile.services.whatsapp

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import dev.nanoai.mobile.MainActivity

/** Regresa a la tarea existente de Nano, sin enviar Atrás a WhatsApp. Mantiene
 * un único callback acotado y verifica la ventana de destino. No conserva nodos. */
object WhatsAppReturnController {
    private val handler = Handler(Looper.getMainLooper())
    private var pending: Runnable? = null
    var isReturning = false
        private set

    fun schedule(service: AccessibilityService) {
        cancel()
        isReturning = true
        var launched = false
        var attempts = 0
        val task = object : Runnable {
            override fun run() {
                if (!isReturning) return
                try {
                    if (!launched) {
                        launched = true
                        service.startActivity(Intent(service, MainActivity::class.java).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                        })
                    }
                    // La burbuja también pertenece a Nano: su foco no acredita
                    // que MainActivity haya vuelto. Exigir una ventana de aplicación.
                    val inNano = service.windows.orEmpty().any { window ->
                        if (window.type != android.view.accessibility.AccessibilityWindowInfo.TYPE_APPLICATION ||
                            !window.isFocused) return@any false
                        val root = window.root
                        try { root?.packageName?.toString() == service.packageName }
                        finally { root?.recycle() }
                    }
                    if (inNano || ++attempts >= 10) {
                        WhatsAppSendProgress.finishReturn(inNano)
                        Log.i("nanoagent_autosend", "Regreso verificado a Nano: $inNano")
                        cancel()
                    } else handler.postDelayed(this, 150)
                } catch (_: Exception) {
                    WhatsAppSendProgress.finishReturn(false)
                    cancel()
                }
            }
        }
        pending = task
        // Permite que WhatsApp procese su clic. El retraso no prueba entrega.
        handler.postDelayed(task, 350)
    }

    /** Se llama al cancelar o desconectar el servicio para no robar el foco después. */
    fun cancel() {
        pending?.let(handler::removeCallbacks)
        pending = null
        isReturning = false
    }
}
