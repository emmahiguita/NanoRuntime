package dev.nanoai.mobile.services

import android.app.Notification
import android.app.RemoteInput
import android.content.Intent
import android.content.ComponentName
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Listener local de notificaciones. No persiste contenido ni lo envía por
 * red: conserva únicamente referencias activas que Android ya entregó al
 * proceso y permite responder mediante la acción RemoteInput de la app origen.
 */
class NotificationAutomationService : NotificationListenerService() {

    override fun onListenerConnected() {
        super.onListenerConnected()
        NotificationAutomationBridge.service = this
    }

    override fun onListenerDisconnected() {
        NotificationAutomationBridge.service = null
        requestRebind(ComponentName(this, NotificationAutomationService::class.java))
        super.onListenerDisconnected()
    }

    override fun onDestroy() {
        if (NotificationAutomationBridge.service === this) {
            NotificationAutomationBridge.service = null
        }
        super.onDestroy()
    }

    fun snapshot(limit: Int = 30): List<Map<String, Any?>> =
        (activeNotifications ?: emptyArray())
            .asSequence()
            .filter { it.packageName != packageName }
            .filterNot { it.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0 }
            .sortedByDescending(StatusBarNotification::getPostTime)
            .take(limit.coerceIn(1, MAX_NOTIFICATIONS))
            .map(::toMap)
            .toList()

    fun reply(key: String, text: String): ReplyResult {
        val cleanText = text.trim()
        if (cleanText.isEmpty() || cleanText.length > MAX_REPLY_CHARS) {
            return ReplyResult(false, "INVALID_TEXT")
        }
        val source = (activeNotifications ?: emptyArray()).firstOrNull { it.key == key }
            ?: return ReplyResult(false, "NOTIFICATION_GONE")
        val action = replyAction(source.notification)
            ?: return ReplyResult(false, "REPLY_UNAVAILABLE")
        val remoteInputs = textRemoteInputs(action)
        if (remoteInputs.isEmpty()) return ReplyResult(false, "REPLY_UNAVAILABLE")

        return try {
            val intent = Intent()
            val results = Bundle()
            remoteInputs.forEach { input ->
                results.putCharSequence(input.resultKey, cleanText)
            }
            RemoteInput.addResultsToIntent(remoteInputs, intent, results)
            action.actionIntent.send(this, 0, intent)
            // PendingIntent.send sin excepción prueba que Android entregó la
            // acción a la app origen; no demuestra lectura del destinatario.
            ReplyResult(true, "REMOTE_INPUT_ACCEPTED")
        } catch (_: android.app.PendingIntent.CanceledException) {
            ReplyResult(false, "ACTION_EXPIRED")
        } catch (_: SecurityException) {
            ReplyResult(false, "ACTION_DENIED")
        }
    }

    private fun toMap(source: StatusBarNotification): Map<String, Any?> {
        val notification = source.notification
        val extras = notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = (
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)
                ?: extras.getCharSequence(Notification.EXTRA_TEXT)
            )?.toString().orEmpty()
        return mapOf(
            "key" to source.key,
            "package" to source.packageName,
            "title" to title.take(MAX_FIELD_CHARS),
            "text" to text.take(MAX_FIELD_CHARS),
            "postTime" to source.postTime,
            "canReply" to (replyAction(notification) != null),
            "ongoing" to source.isOngoing,
        )
    }

    private fun replyAction(notification: Notification): Notification.Action? =
        notification.actions?.firstOrNull { action ->
            textRemoteInputs(action).isNotEmpty()
        }

    /** Sólo RemoteInput que admite texto libre. Los data-only inputs no son
     * un canal de respuesta textual y no deben marcar canReply=true. */
    private fun textRemoteInputs(action: Notification.Action): Array<RemoteInput> =
        action.remoteInputs
            ?.filter(RemoteInput::getAllowFreeFormInput)
            ?.toTypedArray()
            ?: emptyArray()

    data class ReplyResult(val ok: Boolean, val code: String)

    private companion object {
        const val MAX_NOTIFICATIONS = 100
        const val MAX_FIELD_CHARS = 4_000
        const val MAX_REPLY_CHARS = 2_000
    }
}

object NotificationAutomationBridge {
    @Volatile
    var service: NotificationAutomationService? = null
}
