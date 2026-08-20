package dev.nanoai.mobile.channels

import android.app.Activity
import android.content.Intent
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import dev.nanoai.mobile.services.NotificationAutomationBridge
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Puente Flutter ↔ NotificationListenerService. Todas las acciones son locales. */
class NotificationAutomationChannelHandler(
    private val activity: Activity,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.nanoai/notifications"
        val CAPABILITIES = listOf("notification-read", "notification-reply")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(
                mapOf(
                    "accessGranted" to NotificationManagerCompat
                        .getEnabledListenerPackages(activity)
                        .contains(activity.packageName),
                    "connected" to (NotificationAutomationBridge.service != null),
                ),
            )

            "requestAccess" -> {
                try {
                    activity.startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                    result.success(true)
                } catch (_: android.content.ActivityNotFoundException) {
                    try {
                        activity.startActivity(Intent(Settings.ACTION_SETTINGS))
                        result.success(true)
                    } catch (_: android.content.ActivityNotFoundException) {
                        result.success(false)
                    }
                }
            }

            "list" -> {
                val limit = call.argument<Number>("limit")?.toInt() ?: 30
                result.success(NotificationAutomationBridge.service?.snapshot(limit) ?: emptyList<Any>())
            }

            "reply" -> {
                val key = call.argument<String>("key")
                val text = call.argument<String>("text")
                val confirmed = call.argument<Boolean>("confirmed") == true
                if (!confirmed) {
                    result.error("CONFIRMATION_REQUIRED", "la respuesta requiere confirmación", null)
                    return
                }
                if (key.isNullOrBlank() || text.isNullOrBlank()) {
                    result.error("BAD_ARG", "key y text requeridos", null)
                    return
                }
                val service = NotificationAutomationBridge.service
                if (service == null) {
                    result.error("LISTENER_UNAVAILABLE", "listener no conectado", null)
                    return
                }
                val reply = service.reply(key, text)
                result.success(mapOf("ok" to reply.ok, "code" to reply.code))
            }

            else -> result.notImplemented()
        }
    }
}
