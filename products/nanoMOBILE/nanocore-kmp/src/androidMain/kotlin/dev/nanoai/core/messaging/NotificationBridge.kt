// ─────────────────────────────────────────────────────────────────────────────
// androidMain · dev.nanoai.core.messaging · NotificationBridge.kt
//
// QUÉ  : Convierte StatusBarNotification → MessageEvidence (KMP).
//         Permite que MessageClassifier (commonMain) opere sin imports Android.
// CÓMO : Lee los extras de la notificación y rellena el DTO compartido.
//         La política de admisión definitiva sigue en WhatsAppConversation-
//         NotificationClassifier.kt para compatibilidad con el código existente;
//         este puente se usa en los nuevos flujos donde se necesita
//         la evidencia normalizada.
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core.messaging

import android.app.Notification
import android.os.Build
import android.service.notification.StatusBarNotification
import dev.nanoai.core.messaging.MessageEvidence

/** Convierte la notificación Android al DTO multiplataforma. */
object NotificationBridge {
    fun toEvidence(sbn: StatusBarNotification): MessageEvidence {
        val extras = sbn.notification.extras
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text  = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()

        val conversationId = listOfNotNull(
            extras.getString("android.conversationId"),
            sbn.notification.shortcutId,
            if (Build.VERSION.SDK_INT >= 29) sbn.notification.locusId?.id else null,
            sbn.tag,
        ).firstOrNull { it.isNotBlank() }.orEmpty()

        return MessageEvidence(
            text            = text,
            conversationId  = "${sbn.key} $conversationId",
            senderName      = title,
            sourcePackage   = sbn.packageName,
            isGroupSummary  = sbn.notification.flags and Notification.FLAG_GROUP_SUMMARY != 0,
            isOngoing       = sbn.isOngoing,
        )
    }
}
