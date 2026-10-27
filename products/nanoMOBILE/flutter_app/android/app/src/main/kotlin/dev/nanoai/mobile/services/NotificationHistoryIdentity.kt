package dev.nanoai.mobile.services

import android.app.Notification
import android.app.Notification.MessagingStyle
import android.os.Build
import android.service.notification.StatusBarNotification
import org.json.JSONObject

/** Preserva la misma evidencia pública que usa el resolver Dart, sin almacenar secretos. */
internal object NotificationHistoryIdentity {
    /** No convierte el nombre en ID: shortcut, locus, Person y cuenta conservan su origen. */
    fun capture(source: StatusBarNotification, messages: List<MessagingStyle.Message>): String {
        val notification = source.notification
        val extras = notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val conversationTitle = extras.getCharSequence(Notification.EXTRA_CONVERSATION_TITLE)
            ?.toString().orEmpty().trim()
            .replace(Regex("""\s*\(\d+[^)]*\)"""), "")
        val person = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            messages.lastOrNull()?.senderPerson
        } else null
        val locus = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            notification.locusId?.id.orEmpty()
        } else ""
        val values = mapOf(
            "key" to source.key, "packageName" to source.packageName,
            "accountHint" to extras.getCharSequence(Notification.EXTRA_SUB_TEXT)?.toString().orEmpty(),
            "locusId" to locus, "shortcutId" to notification.shortcutId.orEmpty(),
            "senderKey" to person?.key.orEmpty(),
            "conversationId" to extras.getString("android.conversationId").orEmpty(),
            "conversationTitle" to conversationTitle, "title" to title,
        )
        return JSONObject(values.mapValues { it.value.take(200) }).toString()
    }
}
