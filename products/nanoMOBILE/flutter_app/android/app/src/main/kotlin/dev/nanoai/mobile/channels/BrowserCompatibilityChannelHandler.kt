package dev.nanoai.mobile.channels

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
    private fun setDesktopIdentity(viewId: String, enabled: Boolean): Boolean {
        if (viewId.isEmpty()) return false
        val manager = webViewPlugin?.inAppWebViewManager ?: return false
        val webView = manager.keepAliveWebViews[viewId]?.webView ?: return false
        val settings = webView.settings
        val supportsMetadata = WebViewFeature.isFeatureSupported(
            WebViewFeature.USER_AGENT_METADATA,
        )
        if (supportsMetadata) {
            val original = originalIdentities.getOrPut(viewId) {
                IdentityState(WebSettingsCompat.getUserAgentMetadata(settings))
            }
            val metadata = if (enabled) desktopMetadata(original.metadata) else original.metadata
            WebSettingsCompat.setUserAgentMetadata(settings, metadata)
        }
        settings.userAgentString = if (enabled) {
            DESKTOP_USER_AGENT
        } else {
            WebSettings.getDefaultUserAgent(webView.context)
        }
        // En WebViews antiguos aún queda operativo el UA clásico; la página no
        // debe quedar en blanco solo porque el motor no publique Client Hints.
        return true
    }

    /** Conserva marcas/versiones reales de Chromium y cambia solo la plataforma. */
    private fun desktopMetadata(original: UserAgentMetadata): UserAgentMetadata =
        UserAgentMetadata.Builder(original)
            .setPlatform("Windows")
            .setPlatformVersion("10.0.0")
            .setArchitecture("x86")
            .setModel("")
            .setMobile(false)
            .setBitness(64)
            .setWow64(false)
            .build()

    /** Desconecta el canal y descarta referencias a WebViews ya cerrados. */
    fun close() {
        channel.setMethodCallHandler(null)
        originalIdentities.clear()
    }

    companion object {
        const val CHANNEL_NAME = "com.nanoai/browser_compatibility"
        private const val DESKTOP_USER_AGENT =
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) " +
                "AppleWebKit/537.36 (KHTML, like Gecko) " +
                "Chrome/130.0.0.0 Safari/537.36"
    }
}
