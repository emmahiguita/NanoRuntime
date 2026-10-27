package dev.nanoai.mobile.services.whatsapp

import android.content.Context
import android.graphics.Rect
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityWindowInfo
import dev.nanoai.mobile.services.AgentAccessibilityBridge
import io.flutter.plugin.common.MethodChannel

/** Solicitud explícita de mini-ventana y observación acotada del resultado.
 * No envía mensajes, no utiliza APIs privadas y nunca relanza para reintentar. */
class NanoWhatsAppWindowRequest(private val context: Context) {
    private val handler = Handler(Looper.getMainLooper())
    private var callback: Runnable? = null
    private var pending: MethodChannel.Result? = null

    /** Devuelve soporte, solicitud o ventana reducida observada como estados
     * distintos. Sin capacidad pública no abre otra modalidad silenciosamente. */
    fun open(pkg: String, result: MethodChannel.Result) {
        if (pending != null) { result.success(report("busy", "Otra solicitud de ventana sigue activa.")); return }
        if (pkg !in setOf("com.whatsapp", "com.whatsapp.w4b")) {
            result.success(report("unsupported", "El paquete no es WhatsApp instalado.")); return
        }
        if (!WindowStrategySelector.supportsFloating(context)) {
            result.success(report("unsupported", "Android no anuncia soporte freeform. Usa la ventana del fabricante o abre WhatsApp normalmente con el búho encima.")); return
        }
        val intent = context.packageManager.getLaunchIntentForPackage(pkg)
        if (intent == null) { result.success(report("failed", "Esa versión de WhatsApp no está instalada.")); return }
        if (AgentAccessibilityBridge.isAutoSendArmed || WhatsAppReturnController.isReturning) {
            result.success(report("busy", "Espera a que termine la tarea actual de WhatsApp.")); return
        }
        try {
            val strategy = WindowStrategySelector.resolveBest(context, preferFloating = true)
            strategy.applyToIntent(intent, context)
            context.startActivity(intent, strategy.launchOptions(context))
        } catch (_: Exception) {
            result.success(report("failed", "Android rechazó abrir WhatsApp en esa modalidad.")); return
        }
        pending = result
        var attempt = 0
        val task = object : Runnable {
            /** Solo observa hasta ocho veces; no repite la apertura. */
            override fun run() {
                if (pending == null) return
                val bounds = observedBounds(pkg)
                val dm = context.resources.displayMetrics
                val reduced = bounds != null && bounds.width() < dm.widthPixels * .95f &&
                    bounds.height() < dm.heightPixels * .9f
                if (reduced) {
                    finish(report("reduced_window_observed", "Ventana de WhatsApp reducida observada por Android.")); return
                }
                if (++attempt >= 8) {
                    finish(report("launch_requested_unverified", "Android aceptó la apertura, pero no se observó una ventana reducida. No se forzó otra apertura.")); return
                }
                handler.postDelayed(this, 200)
            }
        }
        callback = task
        handler.post(task)
    }

    /** Solo considera ventanas de aplicación del paquete exacto. La mayor
     * evita confundir un diálogo pequeño con toda la ventana de WhatsApp. */
    private fun observedBounds(pkg: String): Rect? {
        val service = AgentAccessibilityBridge.service ?: return null
        return runCatching {
            service.windows.orEmpty().mapNotNull { window ->
                if (window.type != AccessibilityWindowInfo.TYPE_APPLICATION ||
                    (!window.isActive && !window.isFocused)) return@mapNotNull null
                val root = window.root ?: return@mapNotNull null
                try {
                    if (root.packageName?.toString() != pkg) null
                    else Rect().also { window.getBoundsInScreen(it) }.takeIf { !it.isEmpty }
                } finally { root.recycle() }
            }.maxByOrNull { it.width().toLong() * it.height() }
        }.getOrNull()
    }

    /** Completa una sola vez y retira callbacks para no mantener la Activity. */
    private fun finish(value: Map<String, String>) {
        val result = pending
        pending = null
        callback?.let(handler::removeCallbacks)
        callback = null
        result?.success(value)
    }

    /** Al destruir el canal se libera la observación; no revierte una apertura. */
    fun close() { finish(report("cancelled", "La observación se cerró; revisa el estado de WhatsApp.")) }

    /** Estado técnico factual, consumido por el adaptador del mismo motor. */
    private fun report(state: String, text: String) = mapOf("state" to state, "text" to text)
}
