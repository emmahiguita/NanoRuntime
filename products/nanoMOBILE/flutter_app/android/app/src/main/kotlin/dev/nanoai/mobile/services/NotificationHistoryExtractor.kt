package dev.nanoai.mobile.services

import android.app.Notification
import android.app.Notification.MessagingStyle
import android.app.Person
import android.os.Build
import android.service.notification.StatusBarNotification
import dev.nanoai.mobile.automation.NotificationHistoryEvent
import java.util.Locale

/** Convierte solo evidencia de conversación Android en filas locales de historial. */
internal object NotificationHistoryExtractor {
    private val supportedPackages = setOf(
        "com.whatsapp", "com.whatsapp.w4b", "org.telegram.messenger", "org.telegram.plus",
        "com.instagram.android", "com.facebook.orca", "com.facebook.katana", "com.slack",
        "com.google.android.gm", "com.twitter.android", "com.linkedin.android",
    )

    fun extract(source: StatusBarNotification): List<NotificationHistoryEvent> {
        val pkg = source.packageName
        if (pkg !in supportedPackages) return emptyList()
        if (!WhatsAppConversationNotificationClassifier.allows(source)) return emptyList()
        val notification = source.notification
        if (notification.flags and Notification.FLAG_GROUP_SUMMARY != 0) return emptyList()
        val extras = notification.extras ?: return emptyList()
        val rawMessages = MessagingStyle.Message.getMessagesFromBundleArray(
            extras.getParcelableArray(Notification.EXTRA_MESSAGES),
        ).takeLast(MAX_MESSAGES)
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty().trim()
        val conversationTitle = extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)
            ?.toString().orEmpty().trim()
        val conversationId = extras.getString("android.conversationId").orEmpty().ifBlank {
            notification.shortcutId.orEmpty().ifBlank { conversationTitle.ifBlank { title } }
        }
        if (conversationId.isBlank() || isInvalidConversationId(conversationId)) return emptyList()
        val hasConversationEvidence = rawMessages.isNotEmpty() ||
            notification.category == Notification.CATEGORY_MESSAGE ||
            extras.containsKey("android.conversationId") || notification.shortcutId != null
        if (!hasConversationEvidence) return emptyList()

        val group = extras.getBoolean("android.isGroupConversation") || conversationTitle.isNotBlank()
        var displayName = conversationTitle.ifBlank { title }.ifBlank { "Conversación" }
        if (isInvalidConversationId(displayName)) return emptyList()
        val userPerson = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            extras.getParcelable(Notification.EXTRA_MESSAGING_PERSON) as? Person
        } else null
        if (!group && (displayName.equals("Tú", ignoreCase = true) || displayName.equals("Tu", ignoreCase = true))) {
            val contact = rawMessages.firstOrNull { msg ->
                val p = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) msg.senderPerson else null
                !isSelfSender(msg.sender, p, userPerson)
            }?.let { msg ->
                val p = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) msg.senderPerson else null
                msg.sender?.toString()?.trim().orEmpty().ifBlank { p?.name?.toString().orEmpty() }
            }
            if (!contact.isNullOrBlank() && !contact.equals("Tú", ignoreCase = true)) displayName = contact
        }
        val events = rawMessages.mapNotNull { message ->
            val body = message.text?.toString()?.trim().orEmpty()
            if (body.isBlank()) return@mapNotNull null
            val senderPerson = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                message.senderPerson
            } else null
            NotificationHistoryEvent(
                packageName = pkg,
                conversationId = conversationId,
                displayName = displayName,
                notificationKey = source.key,
                sender = message.sender?.toString()?.trim().orEmpty()
                    .ifBlank { senderPerson?.name?.toString().orEmpty().ifBlank { title } },
                body = body,
                atMs = message.timestamp.takeIf { it > 0 } ?: source.postTime,
                isGroup = group,
                // Usa datos MessagingStyle del autor y el usuario que Android expone.
                isSelf = isSelfSender(message.sender, senderPerson, userPerson),
            )
        }
        if (events.isNotEmpty()) return events

        // Algunas apps publican texto sin MessagingStyle; se guarda solo con evidencia de conversación.
        val body = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim()
            .orEmpty().ifBlank { extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim().orEmpty() }
        if (body.isBlank()) return emptyList()
        return listOf(NotificationHistoryEvent(
            packageName = pkg, conversationId = conversationId,
            displayName = displayName, notificationKey = source.key,
            sender = if (group) "" else title, body = body,
            atMs = source.postTime, isGroup = group, isSelf = false,
        ))
    }

    private const val MAX_MESSAGES = 30

    /** Marca saliente solo si MessagingStyle identifica al usuario, nunca por heurística textual. */
    private fun isSelfSender(sender: CharSequence?, person: Person?, user: Person?): Boolean {
        if (sender.isNullOrBlank()) return true
        if (person?.key == "self") return true
        if (user == null || person == null) return false
        return (person.key != null && person.key == user.key) ||
            (person.name != null && person.name == user.name) ||
            (person.uri != null && person.uri == user.uri) ||
            sender.toString().trim().lowercase(Locale.ROOT) ==
                user.name?.toString()?.trim()?.lowercase(Locale.ROOT)
    }

    /** Descarta identificadores y títulos de servicio, números sueltos no telefónicos o difusiones. */
    private fun isInvalidConversationId(id: String): Boolean {
        val trimmed = id.trim().lowercase(Locale.ROOT)
        if (trimmed == "0" || trimmed.isEmpty()) return true
        if (trimmed.length <= 4 && trimmed.all(Char::isDigit)) return true
        if (trimmed == "comprobando si hay mensajes..." || trimmed == "buscando mensajes nuevos") return true
        if (trimmed == "actualizaciones de estado" || trimmed == "status updates") return true
        if (trimmed.contains("status@broadcast") || trimmed.contains("@newsletter")) return true
        return false
    }
}
