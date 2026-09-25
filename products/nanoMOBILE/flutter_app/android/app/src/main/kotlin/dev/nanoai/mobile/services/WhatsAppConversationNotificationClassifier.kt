package dev.nanoai.mobile.services

import android.app.Notification
import android.app.Notification.MessagingStyle
import android.app.RemoteInput
import android.os.Build
import android.os.Bundle
import android.service.notification.StatusBarNotification
import java.util.Locale

/** Evidencia técnica usada para admitir una notificación como chat real. */
internal data class WhatsAppConversationEvidence(
    val applies: Boolean,
    val isConversationEvent: Boolean,
    val hasMessagingStyle: Boolean,
    val category: String,
    val reason: String,
)

/**
 * Separa mensajes reales de estados, canales y avisos internos de WhatsApp.
 * La decisión principal usa estructura Android; el texto solo es una defensa
 * adicional para variantes de reacciones que WhatsApp no identifica por JID.
 */
internal object WhatsAppConversationNotificationClassifier {
    private val packages = setOf("com.whatsapp", "com.whatsapp.w4b")
    private val statusReaction = Regex(
        """((reaccion[oó]|respondi[oó]|le gusta|dio me gusta|liked|reacted|replied).{0,48}(tu estado|your status|seu status)|(tu estado|your status|seu status).{0,48}(le gusta|liked|reacted))""",
        setOf(RegexOption.IGNORE_CASE),
    )
    private val systemNotice = Regex(
        """buscando mensajes nuevos|checking for new messages|whatsapp web|copia de seguridad|backup in progress""",
        setOf(RegexOption.IGNORE_CASE),
    )

    /** Evalúa una sola vez todos los indicios públicos de la notificación. */
    fun inspect(source: StatusBarNotification): WhatsAppConversationEvidence {
        val notification = source.notification
        val category = notification.category.orEmpty()
        val applies = source.packageName in packages
        val messages = MessagingStyle.Message.getMessagesFromBundleArray(
            messageBundles(notification),
        ).orEmpty()
        val hasMessagingStyle = messages.any {
            !it.text.isNullOrBlank() || it.dataUri != null
        }
        val hasTextMessage = !notification.extras.getCharSequence(Notification.EXTRA_TEXT).isNullOrBlank() ||
            !notification.extras.getCharSequence(Notification.EXTRA_BIG_TEXT).isNullOrBlank()
        val hasContent = hasMessagingStyle || hasTextMessage

        if (!applies) {
            return WhatsAppConversationEvidence(
                applies = false,
                isConversationEvent = hasContent,
                hasMessagingStyle = hasMessagingStyle,
                category = category,
                reason = "not_whatsapp",
            )
        }

        if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) {
            return rejected(hasMessagingStyle, category, "group_summary")
        }
        if (source.isOngoing) return rejected(hasMessagingStyle, category, "ongoing")
        if (hasStatusOrSystemSignal(source)) {
            return rejected(hasMessagingStyle, category, "status_or_service")
        }

        val hasIdentity = hasStableConversationIdentity(source, messages)
        val admitted = hasContent && hasIdentity
        val reason = when {
            !hasContent -> "missing_message_content"
            !hasIdentity -> "missing_stable_identity"
            else -> "conversation"
        }
        return WhatsAppConversationEvidence(true, admitted, hasMessagingStyle, category, reason)
    }

    /** Permite apps ajenas a WhatsApp; su política continúa en Flutter. */
    fun allows(source: StatusBarNotification): Boolean {
        val evidence = inspect(source)
        return !evidence.applies || evidence.isConversationEvent
    }

    /** Lee EXTRA_MESSAGES con la API tipada en Android 13+ y compatibilidad 26+. */
    @Suppress("DEPRECATION")
    private fun messageBundles(notification: Notification): Array<out android.os.Parcelable>? {
        val extras = notification.extras ?: return null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            try {
                val typed = extras.getParcelableArray(
                    Notification.EXTRA_MESSAGES,
                    Bundle::class.java,
                )
                if (!typed.isNullOrEmpty()) return typed
            } catch (_: Exception) {
            }
        }
        return extras.getParcelableArray(Notification.EXTRA_MESSAGES)
    }

    /** Exige identidad de plataforma, no un título humano que puede repetirse. */
    private fun hasStableConversationIdentity(
        source: StatusBarNotification,
        messages: List<MessagingStyle.Message>,
    ): Boolean {
        val notification = source.notification
        val extras = notification.extras
        val conversationId = extras.getString("android.conversationId").orEmpty()
        val shortcutId = notification.shortcutId.orEmpty()
        val locusId = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            notification.locusId?.id.orEmpty()
        } else ""
        val person = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            messages.lastOrNull()?.senderPerson
        } else null
        val platformIdentity = listOf(
            conversationId,
            shortcutId,
            locusId,
            person?.key.orEmpty(),
            person?.uri.orEmpty(),
        ).any { it.isNotBlank() }
        val technicalSource = "${source.key} ${source.tag.orEmpty()}".lowercase(Locale.ROOT)
        return platformIdentity || listOf("@s.whatsapp.net", "@c.us", "@g.us", "@lid")
            .any(technicalSource::contains) ||
            source.tag?.isNotBlank() == true ||
            extras.getCharSequence(Notification.EXTRA_TITLE)?.isNotBlank() == true
    }

    /** Rechaza JID de estado/canal y frases inequívocas de reacción o servicio. */
    private fun hasStatusOrSystemSignal(source: StatusBarNotification): Boolean {
        val notification = source.notification
        val extras = notification.extras
        val title = extras
            .getCharSequence(Notification.EXTRA_TITLE)
            ?.toString()
            .orEmpty()
            .trim()
            .lowercase(Locale.ROOT)
        if (title in setOf(
                "actualizaciones de estado",
                "status updates",
                "actualizaciones",
                "novedades",
            )
        ) return true
        val searchable = listOf(
            source.key,
            source.tag.orEmpty(),
            extras.getString("android.conversationId").orEmpty(),
            notification.shortcutId.orEmpty(),
            extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty(),
            extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty(),
            extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString().orEmpty(),
        ).joinToString(" ").lowercase(Locale.ROOT)
        if ("status@broadcast" in searchable || "@newsletter" in searchable) return true
        if (statusReaction.containsMatchIn(searchable) || systemNotice.containsMatchIn(searchable)) return true
        return false
    }

    /** Construye un rechazo uniforme sin registrar contenido sensible. */
    private fun rejected(
        hasMessagingStyle: Boolean,
        category: String,
        reason: String,
    ) = WhatsAppConversationEvidence(true, false, hasMessagingStyle, category, reason)
}
