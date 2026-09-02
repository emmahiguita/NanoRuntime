package dev.nanoai.mobile.services

import android.app.Notification
import android.app.Notification.MessagingStyle
import android.app.RemoteInput
import android.content.Intent
import android.content.ComponentName
import android.os.Build
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

    /**
     * Notificación entrante → evento en vivo al bridge (EventChannel). El
     * contenido NO se persiste ni se envía por red: solo se retransmite al
     * proceso Flutter para triggers/reglas. No dispara para la propia app ni
     * para resúmenes de grupo.
     */
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return
        if (sbn.packageName == packageName) return
        if (sbn.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return
        NotificationAutomationBridge.notificationEventsSink?.success(toMap(sbn))
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

        // A14.6 — Notification Capability Graph: extrae identidad/estructura
        // real de la conversación desde el MessagingStyle (sender, isGroup,
        // conversationTitle, mensaje individual). Vía extras + getMessagesFromBundleArray
        // (público; extractMessagingStyleFromNotification no está en la API 36).
        // Apps sin MessagingStyle quedan con campos vacíos (honesto).
        val messages = MessagingStyle.Message.getMessagesFromBundleArray(
            extras.getParcelableArray(Notification.EXTRA_MESSAGES),
        )
        val lastMessage = messages.lastOrNull()
        val sender = lastMessage?.sender?.toString().orEmpty()
        val messageText = lastMessage?.text?.toString().orEmpty()
        val isGroup = extras.getBoolean(
            Notification.EXTRA_IS_GROUP_CONVERSATION,
            false,
        )
        val conversationTitle = extras
            .getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)
            ?.toString().orEmpty()
        val conversationId = extras.getString("android.conversationId").orEmpty()

        // WA-ID-02 — evidencia adicional de identidad. Sólo metadata PÚBLICA de
        // la plataforma; vacío = la app origen no la expone (honesto, jamás se
        // fabrica). senderPerson existe desde API 28 y locusId desde API 29:
        // ambos van con guard de versión para minSdk 26.
        val messageTimestamp = lastMessage?.timestamp ?: 0L
        val senderPerson = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lastMessage?.senderPerson
        } else {
            null
        }
        val senderKey = senderPerson?.key.orEmpty()
        val senderUri = senderPerson?.uri.orEmpty()
        val shortcutId = notification.shortcutId.orEmpty()
        val locusId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            notification.locusId?.id.orEmpty()
        } else {
            ""
        }
        val subText = extras
            .getCharSequence(Notification.EXTRA_SUB_TEXT)
            ?.toString()
            .orEmpty()

        val reply = replyAction(notification)
        val remoteInputKey = reply
            ?.remoteInputs
            ?.firstOrNull(RemoteInput::getAllowFreeFormInput)
            ?.resultKey
            .orEmpty()
        val replyActionIndex = if (reply == null) {
            -1
        } else {
            notification.actions?.indexOf(reply) ?: -1
        }

        return mapOf(
            "key" to source.key,
            "package" to source.packageName,
            "title" to title.take(MAX_FIELD_CHARS),
            "text" to text.take(MAX_FIELD_CHARS),
            "messageText" to messageText.take(MAX_FIELD_CHARS),
            "messageTimestamp" to messageTimestamp,
            "sender" to sender.take(200),
            "senderKey" to senderKey.take(200),
            "senderUri" to senderUri.take(500),
            "conversationTitle" to conversationTitle.take(200),
            "conversationId" to conversationId.take(200),
            "shortcutId" to shortcutId.take(200),
            "locusId" to locusId.take(200),
            "accountHint" to subText.take(200),
            "isGroup" to isGroup,
            "isSummary" to (
                notification.flags and Notification.FLAG_GROUP_SUMMARY != 0
            ),
            "postTime" to source.postTime,
            "canReply" to (reply != null),
            "remoteInputKey" to remoteInputKey,
            "actionIndex" to replyActionIndex,
            "actions" to notification.actions
                .orEmpty()
                .map { it.title?.toString().orEmpty() }
                .filter { it.isNotEmpty() },
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

    /** Sink del EventChannel de eventos en vivo (null = nadie escuchando). */
    @Volatile
    var notificationEventsSink: io.flutter.plugin.common.EventChannel.EventSink? = null
}
