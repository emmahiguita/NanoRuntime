package dev.nanoai.mobile.services

/**
 * Quita una notificación de mensajería actualmente activa en Android.
 *
 * La operación no elimina ni archiva el chat dentro de la aplicación de
 * origen; solo usa la capacidad real del NotificationListenerService.
 */
internal fun NotificationAutomationService.dismissMessagingNotification(
    key: String,
): Boolean {
    if (key.isBlank()) return false
    return try {
        val target = (activeNotifications ?: emptyArray()).firstOrNull {
            it.key == key && WhatsAppConversationNotificationClassifier.allows(it)
        } ?: return false
        cancelNotification(target.key)
        true
    } catch (_: Exception) {
        false
    }
}
