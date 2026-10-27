package dev.nanoai.mobile.services

import android.app.Notification
import android.service.notification.StatusBarNotification

/** Distingue mensajes de actividad social usando capacidades públicas de Android. */
internal object SocialConversationNotificationClassifier {
    private val packages = setOf(
        "com.instagram.android", "com.facebook.katana", "com.facebook.lite",
        "com.facebook.orca", "com.facebook.mlite",
    )

    /** No interpreta el texto humano: un corazón o la palabra comentario siguen siendo válidos. */
    fun inspect(
        source: StatusBarNotification,
        hasMessagingStyle: Boolean,
        hasContent: Boolean,
    ): WhatsAppConversationEvidence? {
        if (source.packageName !in packages) return null
        val notification = source.notification
        val category = notification.category.orEmpty()
        val summary = notification.flags and Notification.FLAG_GROUP_SUMMARY != 0
        // RemoteInput con texto libre pertenece al hilo, no al botón de reaccionar a un post.
        val hasReply = notification.actions.orEmpty().any { action ->
            action.actionIntent != null && action.remoteInputs.orEmpty().any {
                it.allowFreeFormInput && it.resultKey.isNotBlank()
            }
        }
        // Facebook principal también notifica comentarios: un estilo de burbuja
        // por sí solo no prueba mensajería. Exige categoría de mensaje y respuesta.
        val facebookFeed = source.packageName in setOf("com.facebook.katana", "com.facebook.lite")
        val instagramDirect = source.packageName == "com.instagram.android" &&
            source.key.contains("|direct|") && source.key.contains("thread_id:")
        val messageEvidence = if (facebookFeed) {
            category == Notification.CATEGORY_MESSAGE && hasReply
        } else {
            instagramDirect || (category == Notification.CATEGORY_MESSAGE &&
                (hasMessagingStyle || hasReply))
        }
        val admitted = !summary && !source.isOngoing && hasContent && messageEvidence
        val reason = when {
            summary -> "social_group_summary"
            source.isOngoing -> "social_service"
            !hasContent -> "social_missing_content"
            !messageEvidence -> "social_not_direct_message"
            else -> "social_direct_message"
        }
        // Reutiliza el contrato del listener para filtrar antes de SQLite, IPC y automatización.
        return WhatsAppConversationEvidence(true, admitted, hasMessagingStyle, category, reason)
    }
}
