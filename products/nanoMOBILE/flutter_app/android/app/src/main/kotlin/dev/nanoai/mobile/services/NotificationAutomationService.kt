package dev.nanoai.mobile.services

import android.app.Notification
import android.app.Person
import android.content.Context
import android.app.Notification.MessagingStyle
import android.app.RemoteInput
import android.content.ComponentName
import android.os.Build
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import dev.nanoai.mobile.NanoApplication
import dev.nanoai.mobile.automation.AutomationRuntimeService
import dev.nanoai.mobile.channels.AutomationBackgroundChannelHandler
import java.util.Locale

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
        if (NanoApplication.from(this).durableInbox.pendingCount() > 0 &&
            AutomationBackgroundChannelHandler.isBackgroundEnabled(this)) {
            AutomationRuntimeService.request(this, "nls_reconnect")
        }
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
        if (sink == null && !AutomationBackgroundChannelHandler.isBackgroundEnabled(this)) return

        // NATIVE-ADMISSION-01: Si no hay sink UI vivo, verificar que el paquete tenga reglas
        // activas antes de persistir en DurableInbox o despertar el runtime headless.
        if (sink == null && !isPackageEligible(sbn.packageName)) {
            android.util.Log.d("NanoNotifications", "Skipping background wake for non-automated package: ${sbn.packageName}")
            return
        }

        try {
            NanoApplication.from(this).durableInbox.insert(sbn.packageName, sbn.key, sbn.postTime)
        } catch (error: Exception) {
            android.util.Log.e("NanoNotifications", "Inbox persistence failed; delivery deferred", error)
            return
        }
        if (sink != null) {
            sink.success(toMap(sbn))
        } else {
            AutomationRuntimeService.request(this)
        }
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification?) {
        super.onNotificationRemoved(sbn)
        if (sbn == null) return
        val pkg = sbn.packageName ?: return
        if (pkg == packageName) return
        val key = sbn.key ?: return
        
        try {
            val eventId = dev.nanoai.mobile.automation.DurableInbox.eventId(pkg, key, sbn.postTime)
            NanoApplication.from(this).durableInbox.complete(eventId)
        } catch (error: Exception) {
            android.util.Log.e("NanoNotifications", "Failed to remove event from inbox", error)
        }
    }

    private fun isPackageEligible(pkg: String): Boolean {
        return try {
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val raw = prefs.getString("flutter.automation.eligible_packages", null)
            if (raw == null) {
                pkg == "com.whatsapp" || pkg == "com.whatsapp.w4b" ||
                    pkg == "org.telegram.messenger" || pkg == "com.telegram.messenger"
            } else if (raw == "*" || raw.contains("*")) {
                true
            } else {
                val allowed = raw.split(",").map { it.trim() }.filter { it.isNotEmpty() }.toSet()
                pkg in allowed
            }
        } catch (e: Exception) {
            pkg == "com.whatsapp" || pkg == "com.whatsapp.w4b" ||
                pkg == "org.telegram.messenger" || pkg == "com.telegram.messenger"
        }
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
        expectedPostTime: Long = 0L,
    ): ReplyResult {
        val cleanText = text.trim()
        if (cleanText.isEmpty() || cleanText.length > MAX_REPLY_CHARS) {
            return ReplyResult(false, "INVALID_TEXT")
        }
        val source = (activeNotifications ?: emptyArray()).firstOrNull { it.key == key }
            ?: return ReplyResult(false, "NOTIFICATION_GONE")

        // WA-TOCTOU: si el postTime cambió, WhatsApp actualizó la notificación a un
        // turno nuevo dentro del mismo chat; responder con el borrador viejo es stale.
        if (expectedPostTime > 0L && source.postTime != expectedPostTime) {
            return ReplyResult(false, "CONTEXT_CHANGED")
        }

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

        val dispatch = RemoteInputReplySender.send(this, action, cleanText)
        // PendingIntent.send sin excepción prueba que Android entregó la
        // acción a la app origen; no demuestra lectura del destinatario.
        return ReplyResult(dispatch.ok, dispatch.code)
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

        val userPerson = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            extras.getParcelable(Notification.EXTRA_MESSAGING_PERSON) as? Person
        } else {
            null
        }
        val isSelfMessage = if (lastMessage != null) {
            isSelfSender(lastMessage.sender, senderPerson, userPerson)
        } else {
            isSelfSender(sender, senderPerson, userPerson)
        }

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
            "isTruncated" to (messageText.length > MAX_FIELD_CHARS || text.length > MAX_FIELD_CHARS),
            "isSelf" to isSelfMessage,
            // Preserve the individual MessagingStyle events on live updates
            // and cold replay. Dart deduplicates each original timestamp.
            "messages" to messages.map { message ->
                val person = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    message.senderPerson
                } else null
                mapOf(
                    "messageText" to message.text?.toString().orEmpty().take(MAX_FIELD_CHARS),
                    "text" to message.text?.toString().orEmpty().take(MAX_FIELD_CHARS),
                    "messageTimestamp" to message.timestamp,
                    "isTruncated" to ((message.text?.length ?: 0) > MAX_FIELD_CHARS),
                    "sender" to message.sender?.toString().orEmpty().take(200),
                    "senderKey" to person?.key.orEmpty().take(200),
                    "senderUri" to person?.uri.orEmpty().take(500),
                    "isSelf" to isSelfSender(message.sender, person, userPerson),
                )
            },
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

    private fun isSelfSender(
        senderStr: CharSequence?,
        person: Any?,
        userPerson: Any?,
    ): Boolean {
        if (senderStr == null || senderStr.isBlank()) return true
        val clean = senderStr.trim().toString().lowercase(Locale.ROOT)
        if (clean in setOf("tú", "tu", "you", "yo", "me", "moi", "io", "eu", "ich")) {
            return true
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val p = person as? Person
            val up = userPerson as? Person
            if (p != null) {
                if (p.key == "self") return true
                if (up != null) {
                    if (p.key != null && p.key == up.key) return true
                    if (p.name != null && p.name == up.name) return true
                    if (p.uri != null && p.uri == up.uri) return true
                }
            }
            if (up != null && up.name != null) {
                if (clean == up.name.toString().trim().lowercase(Locale.ROOT)) {
                    return true
                }
            }
        }
        return false
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
