package dev.nanoai.mobile.automation

import android.content.Context
import dev.nanoai.mobile.NanoApplication
import dev.nanoai.mobile.services.NotificationAutomationBridge
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** QUÉ: conserva el contrato durable claim/complete/heartbeat del runtime.
 * CÓMO: usa las mismas filas y notificaciones activas, sin inventar contenido.
 * POR QUÉ: separa persistencia/control del ciclo de vida del Service. */
internal class AutomationRuntimeControl(
    private val context: Context,
    private val heartbeat: () -> Unit,
    private val finish: () -> Unit,
) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isHeadless" -> result.success(true)
            "heartbeat" -> {
                heartbeat()
                result.success(null)
            }

            "claim" -> {
                if (NotificationAutomationBridge.service == null) {
                    result.error("SOURCE_UNAVAILABLE", "NotificationListenerService is not connected", null)
                    return
                }
                try {
                    val limit = call.argument<Number>("limit")?.toInt() ?: 10
                    result.success(claimInbox(limit))
                } catch (error: Exception) {
                    result.error("DB_ERROR", error.message, null)
                }
            }

            "complete" -> {
                val eventId = call.argument<String>("eventId")
                if (!eventId.isNullOrEmpty()) {
                    NanoApplication.from(context).durableInbox.complete(eventId)
                }
                result.success(true)
            }

            "markGenerated" -> {
                val eventId = call.argument<String>("eventId")
                val text = call.argument<String>("text") ?: ""
                if (!eventId.isNullOrEmpty()) {
                    NanoApplication.from(context).durableInbox.markGenerated(eventId, text)
                }
                result.success(true)
            }

            "markSending" -> {
                val eventId = call.argument<String>("eventId")
                if (!eventId.isNullOrEmpty()) {
                    NanoApplication.from(context).durableInbox.markSending(eventId)
                }
                result.success(true)
            }

            "markSent" -> {
                val eventId = call.argument<String>("eventId")
                if (!eventId.isNullOrEmpty()) {
                    NanoApplication.from(context).durableInbox.markSent(eventId)
                }
                result.success(true)
            }

            "recordFailure" -> {
                val eventId = call.argument<String>("eventId")
                val category = call.argument<String>("category") ?: "UNKNOWN"
                val message = call.argument<String>("message")
                if (!eventId.isNullOrEmpty()) {
                    NanoApplication.from(context).durableInbox.recordFailure(eventId, category, message)
                }
                result.success(true)
            }

            "isAlreadySent" -> {
                val eventId = call.argument<String>("eventId")
                if (!eventId.isNullOrEmpty()) {
                    result.success(NanoApplication.from(context).durableInbox.isAlreadySent(eventId))
                } else {
                    result.success(false)
                }
            }

            "pendingCount" -> result.success(NanoApplication.from(context).durableInbox.pendingCount())

            "finish" -> {
                result.success(true)
                finish()
            }

            else -> result.notImplemented()
        }
    }

    private fun claimInbox(limit: Int): List<Map<String, Any?>> {
        val service = NotificationAutomationBridge.service ?: return emptyList()
        val inbox = NanoApplication.from(context).durableInbox
        return inbox.claim(limit).mapNotNull { row ->
            val payload = service.byKey(row.notificationKey)
            if (payload == null) {
                // Notificación ya descartada o no activa: completamos la fila
                // para evitar re-claims huérfanos o loops en headless.
                inbox.complete(row.eventId)
                null
            } else {
                mapOf("eventId" to row.eventId, "notification" to payload)
            }
        }
    }
}
