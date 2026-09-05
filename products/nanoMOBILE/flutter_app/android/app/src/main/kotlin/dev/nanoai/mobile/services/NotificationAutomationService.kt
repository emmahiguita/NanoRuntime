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
import dev.nanoai.mobile.NanoApplication
import dev.nanoai.mobile.automation.AutomationRuntimeService
import dev.nanoai.mobile.channels.AutomationBackgroundChannelHandler

/**
 * Listener local de notificaciones. WA-PROD-01: persiste SOLO la identidad
 * del evento (package + notificationKey + tiempos) en el DurableInbox; el
 * CONTENIDO nunca se persiste ni se envía por red — se rehidrata de las
 * notificaciones activas que Android ya entregó al proceso al momento de
 * procesar. Responde mediante la acción RemoteInput de la app origen.
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
     * WA-PROD-01 — sensor, no cerebro: normaliza y persiste el evento en el
     * inbox durable (<10ms) y sale rápido. Si hay un engine Dart escuchando
     * (UI o headless) reenvía el evento vivo por el EventChannel; si no, pide
     * al AutomationRuntimeService que arranque el runtime headless que drenará
     * la fila. El contenido NO se persiste ni se envía por red (solo se
     * rehidrata de las notificaciones activas al procesar). No dispara para
     * la propia app ni para resúmenes de grupo.
     */
    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        super.onNotificationPosted(sbn)
        if (sbn == null) return
        if (sbn.packageName == packageName) return
        if (sbn.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return

        val sink = NotificationAutomationBridge.notificationEventsSink
        if (sink != null) {
            sink.success(toMap(sbn))
            return
        }
        // Sin consumidor Dart: persistir para el próximo wake. La puerta de
        // usuario ("procesar en segundo plano") corta también la inserción:
        // desactivada = comportamiento histórico (solo con la app abierta).
        if (!AutomationBackgroundChannelHandler.isBackgroundEnabled(this)) return
        val inserted = NanoApplication.from(this).durableInbox.insert(
            sbn.packageName,
            sbn.key,
            sbn.postTime,
        )
        if (inserted) AutomationRuntimeService.request(this)
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

    /** WA-PROD-01 — rehidratación por key para el drenado del inbox: devuelve
     *  el mapa del evento SOLO si la notificación sigue activa (sin contenido
     *  persistido no hay otra fuente honesta). */
    fun byKey(key: String): Map<String, Any?>? =
        (activeNotifications ?: emptyArray())
            .firstOrNull { it.key == key }
            ?.let(::toMap)

    /**
     * WA-RI-05 — reply con revalidación EXACTA de la capacidad observada.
     *
     * Cuando el caller observó la notificación antes (candidato grounded) y
     * conoce su capacidad, envía los campos esperados (actionIndex,
     * remoteInputKey, contextFingerprint). El servicio RECOMPUTA esos valores
     * contra la notificación ACTIVA en este instante; cualquier desviación =
     * CONTEXT_CHANGED y NO se envía: la misma key puede seguir viva mientras
     * su contenido cambió a OTRA conversación, y responder ahí iría al chat
     * equivocado.
     *
     * Campos con default vacío = el caller no observó capacidad (flujos
     * legacy/@comando): conservan la revalidación por key existente.
     */
    fun reply(
        key: String,
        text: String,
        expectedActionIndex: Int = -1,
        expectedRemoteInputKey: String = "",
        expectedContextFingerprint: String = "",
    ): ReplyResult {
        val cleanText = text.trim()
        if (cleanText.isEmpty() || cleanText.length > MAX_REPLY_CHARS) {
            return ReplyResult(false, "INVALID_TEXT")
        }
        val source = (activeNotifications ?: emptyArray()).firstOrNull { it.key == key }
            ?: return ReplyResult(false, "NOTIFICATION_GONE")
        val notification = source.notification
        val action = replyAction(notification)
            ?: return ReplyResult(false, "REPLY_UNAVAILABLE")
        val remoteInputs = textRemoteInputs(action)
        if (remoteInputs.isEmpty()) return ReplyResult(false, "REPLY_UNAVAILABLE")

        // WA-RI-05: exigir la MISMA capacidad observada (índice, resultKey y
        // contexto de conversación), no "cualquier acción con RemoteInput".
        val currentActionIndex = notification.actions?.indexOf(action) ?: -1
        if (expectedActionIndex >= 0 && currentActionIndex != expectedActionIndex) {
            return ReplyResult(false, "CONTEXT_CHANGED")
        }
        val currentRemoteInputKey = remoteInputs
            .firstOrNull(RemoteInput::getAllowFreeFormInput)
            ?.resultKey
            .orEmpty()
        if (expectedRemoteInputKey.isNotEmpty() &&
            currentRemoteInputKey != expectedRemoteInputKey
        ) {
            return ReplyResult(false, "CONTEXT_CHANGED")
        }
        val currentFingerprint = contextFingerprint(notification)
        if (expectedContextFingerprint.isNotEmpty() &&
            currentFingerprint != expectedContextFingerprint
        ) {
            return ReplyResult(false, "CONTEXT_CHANGED")
        }

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

    /**
     * WA-RI-05 — fingerprint factual del contexto de conversación, MISMO
     * orden y separador que ReplyCapabilityRef._contextFingerprint (Dart):
     * conversationId | shortcutId | locusId | senderKey | conversationTitle |
     * sender | group/direct, unidos por \u0000. Vacio = la app origen no
     * expone esa evidencia (honesto: el fingerprint solo difiere si la
     * evidencia REAL difiere).
     */
    private fun contextFingerprint(notification: Notification): String {
        val extras = notification.extras
        val messages = MessagingStyle.Message.getMessagesFromBundleArray(
            extras.getParcelableArray(Notification.EXTRA_MESSAGES),
        )
        val lastMessage = messages.lastOrNull()
        val senderPerson = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            lastMessage?.senderPerson
        } else {
            null
        }
        val isGroup = extras.getBoolean(
            Notification.EXTRA_IS_GROUP_CONVERSATION,
            false,
        )
        val shortcutId = notification.shortcutId.orEmpty()
        val locusId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            notification.locusId?.id.orEmpty()
        } else {
            ""
        }
        return listOf(
            extras.getString("android.conversationId").orEmpty(),
            shortcutId,
            locusId,
            senderPerson?.key.orEmpty(),
            extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)
                ?.toString()
                .orEmpty(),
            lastMessage?.sender?.toString().orEmpty(),
            if (isGroup) "group" else "direct",
        ).joinToString(separator = "\u0000")
    }

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

    /** WA-PROD-01 — dueño del sink: solo UN engine (UI o headless) escucha
     *  eventos vivos. La UI que se abre destrona al headless (single consumer)
     *  y pide al runtime headless que se detenga. */
    private val lock = Any()
    @Volatile
    private var sinkOwner: Any? = null

    fun setSink(owner: Any, sink: io.flutter.plugin.common.EventChannel.EventSink?) {
        val replaced = synchronized(lock) {
            val previous = sinkOwner
            sinkOwner = owner
            notificationEventsSink = sink
            previous
        }
        if (replaced !== owner && replaced != null) {
            // Otro engine tomó el sink: el headless debe retirarse.
            dev.nanoai.mobile.automation.AutomationRuntimeService.onUiEngineAttached()
        }
    }

    fun clearSink(owner: Any) {
        synchronized(lock) {
            if (sinkOwner === owner) {
                sinkOwner = null
                notificationEventsSink = null
            }
        }
    }
}
