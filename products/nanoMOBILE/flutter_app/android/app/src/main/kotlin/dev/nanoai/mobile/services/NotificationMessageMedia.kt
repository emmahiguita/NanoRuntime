package dev.nanoai.mobile.services

import android.app.Notification.MessagingStyle
import android.content.ContentResolver
import android.os.Bundle
import java.io.File
import java.security.MessageDigest

/** Adjunta únicamente archivos cuya URI pertenece al mensaje observado.
 * No usa la imagen global de la notificación: podría corresponder a otro evento.
 */
internal data class NotificationMessageMedia(
    val image: String? = null,
    val video: String? = null,
    val audio: String? = null,
    val pdf: String? = null,
) {
    /** Conserva el texto y añade una sola etiqueta por archivo realmente copiado. */
    fun appendTo(text: String): String {
        var result = text
        listOf("Imagen" to image, "Video" to video, "Audio" to audio, "PDF" to pdf)
            .forEach { (label, path) ->
                if (path != null && !result.contains("[$label:")) {
                    result = "$result\n[$label: $path]".trim()
                }
            }
        return result
    }

    companion object {
        /** La clave estable evita copiar de nuevo el mismo adjunto en cada replay.
         * Incluye paquete, URI y tiempo: dos chats no comparten archivo por hora.
         */
        fun capture(
            cacheDir: File,
            resolver: ContentResolver,
            packageName: String,
            message: MessagingStyle.Message?,
        ): NotificationMessageMedia {
            if (message?.dataUri == null) return NotificationMessageMedia()
            val identity = "$packageName|${message.timestamp}|${message.dataUri}"
            val digest = MessageDigest.getInstance("SHA-256")
                .digest(identity.toByteArray(Charsets.UTF_8))
            val key = digest.take(7).fold(0L) { value, byte ->
                (value shl 8) or (byte.toLong() and 255L)
            }
            val single = listOf(message)
            val mime = message.dataMimeType.orEmpty()
            return when {
                mime.startsWith("image/") -> NotificationMessageMedia(image =
                    NotificationMediaCache.saveImage(cacheDir, resolver, Bundle(), single, key))
                mime.startsWith("video/") -> NotificationMessageMedia(video =
                    NotificationMediaCache.saveVideo(cacheDir, resolver, single, key))
                mime.startsWith("audio/") -> NotificationMessageMedia(audio =
                    NotificationMediaCache.saveAudio(cacheDir, resolver, single, key))
                mime.equals("application/pdf", ignoreCase = true) -> NotificationMessageMedia(pdf =
                    NotificationMediaCache.savePdf(cacheDir, resolver, single, key))
                else -> NotificationMessageMedia()
            }
        }
    }
}
