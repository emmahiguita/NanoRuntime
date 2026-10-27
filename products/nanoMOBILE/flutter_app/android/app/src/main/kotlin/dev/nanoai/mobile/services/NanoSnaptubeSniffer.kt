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

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                if (!isCapturing || view == null) return
                // Forzar reproducción silenciosa en el DOM y extraer src/og:video directo si ya existe
                val jsProbe = """
                    (function() {
                        try {
                            var videos = document.querySelectorAll('video');
                            for (var i = 0; i < videos.length; i++) {
                                videos[i].muted = true;
                                var p = videos[i].play();
                                if (p && p.catch) p.catch(function(){});
                                if (videos[i].currentSrc && videos[i].currentSrc.indexOf('http') === 0) return videos[i].currentSrc;
                                if (videos[i].src && videos[i].src.indexOf('http') === 0) return videos[i].src;
                            }
                            var srcEl = document.querySelector('video source[src^="http"]');
                            if (srcEl) return srcEl.src;
                            var og = document.querySelector('meta[property="og:video:secure_url"], meta[property="og:video"]');
                            if (og && og.content && og.content.indexOf('http') === 0) return og.content;
                        } catch (e) {}
                        return '';
                    })();
                """.trimIndent()
                view.evaluateJavascript(jsProbe) { raw ->
                    val cleaned = raw?.trim()?.removeSurrounding("\"")?.replace("\\/", "/").orEmpty()
                    if (isCapturing && cleaned.startsWith("http") && !cleaned.startsWith("blob:")) {
                        isCapturing = false
                        mainHandler.removeCallbacks(timeoutRunnable!!)
                        wv.stopLoading()
                        onFound(SniffedStream(cleaned, audioOnly, if (audioOnly) "audio/mp4" else "video/mp4"), null)
                    }
                }
            }
        }

        // Transformar URLs cortas/escritorio de YouTube y X a versión móvil para carga rápida
        val effectiveUrl = when {
            targetUrl.contains("youtu.be/") -> {
                val id = targetUrl.substringAfter("youtu.be/").substringBefore("?")
                "https://m.youtube.com/watch?v=$id"
            }
            targetUrl.contains("youtube.com/shorts/") -> {
                val id = targetUrl.substringAfter("youtube.com/shorts/").substringBefore("?").substringBefore("/")
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
                (lower.contains("cdninstagram.com") && (lower.contains(".mp4") || lower.contains("bytestart"))) ||
                lower.contains("tiktokcdn.com") ||
                lower.contains("tiktokv.com") ||
                lower.contains("v.redd.it") ||
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
