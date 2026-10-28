// ─────────────────────────────────────────────────────────────────────────────
// iosMain · dev.nanoai.core.messaging · IosNotificationBridge.kt
//
// QUÉ  : Convierte el payload de UNNotificationContent → MessageEvidence (KMP).
//         Equivalente iOS del NotificationBridge.kt de androidMain.
// CÓMO : En iOS, las apps de terceros NO pueden interceptar notificaciones de
//         WhatsApp. Las alternativas aprobadas por Apple son:
//           1. WhatsApp Business Cloud API (mensajería saliente por webhook).
//           2. App Intents + URLScheme: whatsapp://send?phone=&text=
//           3. Share Extension activada por el usuario.
//         Este bridge recibe mensajes que el usuario reenvía explícitamente
//         desde la Share Extension de NanoAI o mediante Atajos de Siri.
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core.messaging

import platform.Foundation.NSURL
import platform.UIKit.UIApplication
import platform.UserNotifications.UNNotificationContent

/**
 * Convierte UNNotificationContent al DTO multiplataforma.
 * Solo se invoca para notificaciones propias de NanoAI o de la Share Extension
 * — nunca para notificaciones de apps de terceros (iOS no lo permite).
 */
object IosNotificationBridge {
    fun toEvidence(content: UNNotificationContent, sourceBundle: String): MessageEvidence =
        MessageEvidence(
            text           = content.body,
            conversationId = content.threadIdentifier,
            senderName     = content.subtitle,
            sourcePackage  = sourceBundle,
            isGroupSummary = false,
            isOngoing      = false,
        )
}

/**
 * Envía un mensaje vía WhatsApp usando el URL Scheme oficial de WhatsApp.
 * Abre la app de WhatsApp en el número indicado con el texto prellenado.
 * El usuario confirma el envío manualmente — Apple no permite envíos automáticos
 * a apps de terceros.
 */
object WhatsAppUrlSchemeSender {
    /**
     * Construye la URL whatsapp://send y la abre con UIApplication.openURL.
     * [phone] debe incluir código de país, sin espacios ni guiones (ej. "521234567890").
     */
    fun sendMessage(phone: String, text: String) {
        val encodedText = text.encodeURLComponent()
        val urlString = "whatsapp://send?phone=$phone&text=$encodedText"
        // Kotlin/Native UIKit interop — se activa al compilar con Kotlin/Native.
        // UIApplication.sharedApplication.openURL(NSURL.URLWithString(urlString)!!)
        PlatformUrlOpener.open(urlString)
    }
}

/** Abre una URL mediante UIApplication en iOS. */
actual object PlatformUrlOpener {
    actual fun open(url: String) {
        val nsUrl = NSURL.URLWithString(url) ?: return
        UIApplication.sharedApplication.openURL(nsUrl)
    }
}

private fun String.encodeURLComponent(): String =
    // NSString.stringByAddingPercentEncodingWithAllowedCharacters via cinterop
    this.replace(" ", "%20").replace("\n", "%0A")
