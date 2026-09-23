package dev.nanoai.mobile.services

import android.annotation.SuppressLint
import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient

/**
 * NanoSnaptubeSniffer — Extractor real de streams multimedia mediante interceptación de red.
 *
 * QUÉ: Carga URLs de YouTube, X, Instagram, Facebook y TikTok en un WebView headless
 *      e intercepta las peticiones de red del reproductor para capturar el stream real.
 * CÓMO: WebViewClient.shouldInterceptRequest captura URLs de googlevideo.com, twimg, fbcdn, etc.
 * POR QUÉ: No depende de APIs de terceros que se caen o requieren suscripción; usa el reproductor
 *          oficial de la plataforma exactamente como lo hace Snaptube (SOLID-S).
 * ZOMBI: Timeout estricto de 12s y destroy() limpian el WebView y callbacks huérfanos.
 */
@SuppressLint("SetJavaScriptEnabled")
internal class NanoSnaptubeSniffer(private val context: Context) {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var webView: WebView? = null
    private var isCapturing = false
    private var timeoutRunnable: Runnable? = null

    data class SniffedStream(
        val url: String,
        val isAudioOnly: Boolean,
        val mimeType: String,
    )

    private fun ensureWebView(): WebView {
        if (webView == null) {
            webView = WebView(context).apply {
                settings.apply {
                    javaScriptEnabled = true
                    domStorageEnabled = true
                    mediaPlaybackRequiresUserGesture = false
                    mixedContentMode = WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
                    userAgentString = "Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 " +
                            "(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36"
                }
            }
        }
        return webView!!
    }

    /**
     * Intercepta el stream multimedia de la URL dada.
     * @param targetUrl URL de YouTube, X, Instagram, Facebook o TikTok.
     * @param audioOnly true si se prefiere solo audio; false para video completo.
     * @param onFound Callback (SniffedStream?, errorMsg?) despachado en el main thread.
     */
    fun sniffStream(
        targetUrl: String,
        audioOnly: Boolean,
        onFound: (SniffedStream?, String?) -> Unit
    ) {
        val wv = ensureWebView()
        isCapturing = true

        timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        timeoutRunnable = Runnable {
            if (isCapturing) {
                isCapturing = false
                wv.stopLoading()
                onFound(null, "Tiempo de espera agotado al capturar el video.")
            }
        }
        mainHandler.postDelayed(timeoutRunnable!!, 12000L)

        wv.webViewClient = object : WebViewClient() {
            override fun shouldInterceptRequest(view: WebView?, request: WebResourceRequest?): WebResourceResponse? {
                val reqUrl = request?.url?.toString().orEmpty()
                if (isCapturing && isStreamUrl(reqUrl)) {
                    val isAudio = reqUrl.contains("mime=audio") || reqUrl.contains(".mp3") || reqUrl.contains(".m4a")
                    if (!audioOnly || isAudio || reqUrl.contains("googlevideo.com")) {
                        isCapturing = false
                        mainHandler.removeCallbacks(timeoutRunnable!!)
                        mainHandler.post {
                            wv.stopLoading()
                            onFound(SniffedStream(reqUrl, isAudio, if (isAudio) "audio/mp4" else "video/mp4"), null)
                        }
                    }
                }
                return super.shouldInterceptRequest(view, request)
            }
        }

        // Transformar URLs cortas de YouTube a m.youtube.com para carga móvil rápida
        val effectiveUrl = when {
            targetUrl.contains("youtu.be/") -> {
                val id = targetUrl.substringAfter("youtu.be/").substringBefore("?")
                "https://m.youtube.com/watch?v=$id"
            }
            targetUrl.contains("youtube.com/watch") -> {
                targetUrl.replace("www.youtube.com", "m.youtube.com")
            }
            else -> targetUrl
        }
        wv.loadUrl(effectiveUrl)
    }

    private fun isStreamUrl(url: String): Boolean {
        val lower = url.lowercase()
        return lower.contains("googlevideo.com/videoplayback") ||
                lower.contains("video.twimg.com") ||
                (lower.contains("fbcdn.net") && (lower.contains(".mp4") || lower.contains("bytestart"))) ||
                (lower.contains("cdninstagram.com") && lower.contains(".mp4")) ||
                lower.contains("tiktokcdn.com") ||
                lower.endsWith(".mp4") || lower.endsWith(".m4a") || lower.endsWith(".mp3")
    }

    fun destroy() {
        isCapturing = false
        timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        timeoutRunnable = null
        webView?.apply {
            stopLoading()
            webViewClient = WebViewClient()
            destroy()
        }
        webView = null
    }
}
