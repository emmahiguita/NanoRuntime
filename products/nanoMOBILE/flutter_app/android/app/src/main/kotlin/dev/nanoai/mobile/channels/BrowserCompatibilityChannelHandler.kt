package dev.nanoai.mobile.channels

import android.util.Log
import android.webkit.WebSettings
import androidx.webkit.UserAgentMetadata
import androidx.webkit.WebSettingsCompat
import androidx.webkit.WebViewFeature
import com.pichillilorenzo.flutter_inappwebview_android.InAppWebViewFlutterPlugin
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Completa capacidades Android que flutter_inappwebview no publica en Dart.
 *
 * Mantiene juntos el User-Agent clásico y User-Agent Client Hints para que un
 * sitio no reciba identidades contradictorias. También delega el permiso WebRTC
 * al coordinador runtime; nunca concede nada por sí mismo.
 */
internal class BrowserCompatibilityChannelHandler(
    flutterEngine: FlutterEngine,
    private val requestWebMedia: (Boolean, Boolean, MethodChannel.Result) -> Unit,
) : MethodChannel.MethodCallHandler {
    private data class IdentityState(val metadata: UserAgentMetadata)

    private val channel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        CHANNEL_NAME,
    )
    private val webViewPlugin = flutterEngine.plugins
        .get(InAppWebViewFlutterPlugin::class.java) as? InAppWebViewFlutterPlugin
    private val originalIdentities = mutableMapOf<String, IdentityState>()

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setDesktopIdentity" -> result.success(
                setDesktopIdentity(
                    viewId = call.argument<String>("viewId").orEmpty(),
                    enabled = call.argument<Boolean>("enabled") == true,
                    forceMobileLayout = call.argument<Boolean>("forceMobileLayout") == true,
                ),
            )
            "requestMediaPermissions" -> requestWebMedia(
                call.argument<Boolean>("camera") == true,
                call.argument<Boolean>("microphone") == true,
                result,
            )
            else -> result.notImplemented()
        }
    }

    /** Restaura identidad móvil al abandonar el perfil desktop de la pestaña. */
    private fun setDesktopIdentity(
        viewId: String,
        enabled: Boolean,
        forceMobileLayout: Boolean,
    ): Boolean {
        val manager = webViewPlugin?.inAppWebViewManager ?: return false
        // El viewId de la pestaña ES la keepAliveId (FlutterWebViewFactory lo
        // garantiza). Si la vista solicitada no existe, no se toca ninguna otra
        // ventana: una identidad desktop filtrada a pestañas ajenas deja UAs
        // contradictorios en sesiones activas.
        val targets = if (viewId.isNotEmpty()) {
            val target = manager.keepAliveWebViews[viewId]?.webView
                ?: return false
            listOf(viewId to target)
        } else {
            manager.keepAliveWebViews.mapNotNull { (k, v) -> v?.webView?.let { k to it } }
        }
        if (targets.isEmpty()) return false
        val supportsMetadata = WebViewFeature.isFeatureSupported(
            WebViewFeature.USER_AGENT_METADATA,
        )
        for ((key, webView) in targets) {
            val settings = webView.settings
            if (supportsMetadata) {
                val original = originalIdentities.getOrPut(key) {
                    IdentityState(WebSettingsCompat.getUserAgentMetadata(settings))
                }
                val metadata = when {
                    enabled -> desktopMetadata(original.metadata)
                    forceMobileLayout -> mobileChromeMetadata(original.metadata)
                    else -> original.metadata
                }
                WebSettingsCompat.setUserAgentMetadata(settings, metadata)
            }
            val defaultUserAgent = WebSettings.getDefaultUserAgent(webView.context)
            val appliedUserAgent = when {
                enabled -> desktopUserAgent(defaultUserAgent)
                forceMobileLayout -> mobileChromeUserAgent(defaultUserAgent)
                else -> defaultUserAgent
            }
            settings.userAgentString = appliedUserAgent
            // Evidencia operativa sin datos privados: permite verificar en logcat
            // que UA clásico y Client Hints comparten la misma versión Chromium.
            Log.d(
                TAG,
                "setDesktopIdentity viewId=$viewId enabled=$enabled " +
                    "forceMobileLayout=$forceMobileLayout ua=$appliedUserAgent",
            )
            settings.useWideViewPort = true
            settings.loadWithOverviewMode = !forceMobileLayout
            settings.textZoom = 100
        }
        return true
    }

    /** Conserva versiones reales de Chromium y presenta marca Google Chrome Desktop. */
    private fun desktopMetadata(original: UserAgentMetadata): UserAgentMetadata {
        val desktopBrands = original.brandVersionList.map { brand ->
            if (brand.brand.contains("WebView", ignoreCase = true)) {
                UserAgentMetadata.BrandVersion.Builder(brand)
                    .setBrand("Google Chrome")
                    .build()
            } else {
                brand
            }
        }
        return UserAgentMetadata.Builder(original)
            .setBrandVersionList(desktopBrands)
            .setPlatform("Windows")
            .setPlatformVersion("10.0.0")
            .setArchitecture("x86")
            .setModel("")
            .setMobile(false)
            .setBitness(64)
            .setWow64(false)
            .build()
    }

    /**
     * Presenta TikTok como Chrome Android real conservando versiones y modelo
     * del WebView instalado. Solo reemplaza la marca WebView que dispara el
     * layout desktop reducido en algunos frontends adaptativos.
     */
    private fun mobileChromeMetadata(original: UserAgentMetadata): UserAgentMetadata {
        val mobileBrands = original.brandVersionList.map { brand ->
            if (brand.brand.contains("WebView", ignoreCase = true)) {
                UserAgentMetadata.BrandVersion.Builder(brand)
                    .setBrand("Google Chrome")
                    .build()
            } else {
                brand
            }
        }
        return UserAgentMetadata.Builder(original)
            .setBrandVersionList(mobileBrands)
            .setPlatform("Android")
            .setMobile(true)
            .build()
    }

    /**
     * Construye el UA de Chrome Desktop con la MISMA versión real del WebView.
     *
     * Un UA con versión distinta a la de User-Agent Client Hints (que expone las
     * marcas reales del navegador) deja señales contradictorias y algunos sitios
     * lo rechazan; por eso la versión se extrae del UA del sistema.
     */
    private fun desktopUserAgent(defaultUserAgent: String): String =
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
            "AppleWebKit/537.36 (KHTML, like Gecko) " +
            "Chrome/${chromeVersion(defaultUserAgent)} Safari/537.36"

    /** Versión Chromium real del WebView instalado; fallback conservador. */
    private fun chromeVersion(defaultUserAgent: String): String =
        Regex("Chrome/(\\d+(?:\\.\\d+){0,3})")
            .find(defaultUserAgent)
            ?.groupValues
            ?.get(1)
            ?: FALLBACK_CHROME_VERSION

    /** Quita únicamente los marcadores de WebView; conserva Android y Chrome reales. */
    private fun mobileChromeUserAgent(defaultUserAgent: String): String {
        val normalized = defaultUserAgent
            .replace(Regex(";\\s*wv(?=[;)])", RegexOption.IGNORE_CASE), "")
            .replace(Regex("\\s+Version/[0-9.]+", RegexOption.IGNORE_CASE), "")
            .replace(Regex("\\s{2,}"), " ")
            .trim()
        return if (normalized.contains("Mobile Safari/", ignoreCase = true)) {
            normalized
        } else {
            normalized.replace(" Safari/", " Mobile Safari/")
        }
    }

    /** Desconecta el canal y descarta referencias a WebViews ya cerrados. */
    fun close() {
        channel.setMethodCallHandler(null)
        originalIdentities.clear()
    }

    companion object {
        const val CHANNEL_NAME = "com.nanoai/browser_compatibility"

        /** Etiqueta de logcat para verificación física de identidad aplicada. */
        private const val TAG = "NanoBrowserIdentity"

        /** Solo se usa si el UA del sistema no expone la versión (no debería). */
        private const val FALLBACK_CHROME_VERSION = "135.0.0.0"
    }
}
