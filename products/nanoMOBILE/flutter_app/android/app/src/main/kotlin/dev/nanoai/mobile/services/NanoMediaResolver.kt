package dev.nanoai.mobile.services

import android.content.Context

/**
 * NanoMediaResolver — Resolvedor universal de enlaces multimedia (YouTube, X, Insta, FB, TikTok).
 *
 * QUÉ: Convierte enlaces de redes sociales o web a streams directos MP4 (video) y MP3 (audio).
 * CÓMO: 1) Si la URL ya es un archivo directo (.mp4/.mp3), la retorna inmediatamente.
 *       2) Para YouTube y redes sociales, delega en NanoSnaptubeSniffer para interceptar
 *          el stream real del reproductor móvil mediante shouldInterceptRequest.
 * POR QUÉ: Permite descargas reales y autónomas estilo Snaptube sin servidores externos (SOLID-S).
 * LIMPIO: Limpia el sniffer al terminar para evitar retención de memoria.
 */
internal class NanoMediaResolver(private val context: Context) {

    private val sniffer = NanoSnaptubeSniffer(context)

    data class MediaResult(
        val downloadUrl: String,
        val filename: String,
        val isAudioOnly: Boolean,
        val sourceService: String,
    )

    companion object {
        private val SOCIAL_DOMAINS = listOf(
            "youtube.com", "youtu.be", "twitter.com", "x.com",
            "instagram.com", "tiktok.com", "facebook.com", "fb.watch", "reddit.com"
        )

        fun isSupportedSocialUrl(url: String): Boolean =
            SOCIAL_DOMAINS.any { url.contains(it, ignoreCase = true) }

        fun extractUrlFromText(text: String): String? {
            val words = text.split(Regex("\\s+"))
            return words.firstOrNull { it.startsWith("http://") || it.startsWith("https://") }
        }
    }

    /**
     * Resuelve una URL a un stream descargable directo.
     * @param inputUrl URL de YouTube, X, Instagram, TikTok o enlace directo.
     * @param audioOnly true para MP3, false para MP4 (video + audio).
     * @param callback Callback (MediaResult?, errorMsg?) despachado en el main thread.
     */
    fun resolveMedia(
        inputUrl: String,
        audioOnly: Boolean,
        callback: (MediaResult?, String?) -> Unit
    ) {
        val cleanUrl = inputUrl.trim()
        if (!cleanUrl.startsWith("http://") && !cleanUrl.startsWith("https://")) {
            callback(null, "URL no válida. Debe comenzar con http:// o https://")
            return
        }

        // 1. Enlace directo a archivo multimedia
        if (NanoMediaDownloader.isMediaUrl(cleanUrl)) {
            val name = cleanUrl.substringAfterLast("/").substringBefore("?")
            callback(MediaResult(cleanUrl, name, audioOnly, "Directo"), null)
            return
        }

        // 2. Extracción mediante Sniffer de streams de reproductor web
        val serviceName = when {
            cleanUrl.contains("youtu") -> "YouTube"
            cleanUrl.contains("twitter") || cleanUrl.contains("x.com") -> "X / Twitter"
            cleanUrl.contains("instagram") -> "Instagram"
            cleanUrl.contains("tiktok") -> "TikTok"
            cleanUrl.contains("facebook") || cleanUrl.contains("fb.watch") -> "Facebook"
            else -> "Web Media"
        }

        sniffer.sniffStream(cleanUrl, audioOnly) { stream, error ->
            if (stream != null) {
                val ext = if (audioOnly) "mp3" else "mp4"
                val filename = "${serviceName.lowercase().replace(" ", "_")}_${System.currentTimeMillis()}.$ext"
                callback(MediaResult(stream.url, filename, audioOnly, serviceName), null)
            } else {
                callback(null, error ?: "No se pudo extraer el stream de $serviceName.")
            }
        }
    }

    fun destroy() {
        sniffer.destroy()
    }
}
