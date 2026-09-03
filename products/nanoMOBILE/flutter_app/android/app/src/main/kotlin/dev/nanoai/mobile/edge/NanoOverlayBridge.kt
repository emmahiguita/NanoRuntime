package dev.nanoai.mobile.edge

import android.content.Context
import android.util.Log
import dev.nanoai.mobile.services.AgentAccessibilityService
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * EDGE-01 — Bridge estático servicio ↔ overlay ↔ canal Flutter.
 *
 * Mismo patrón que [AgentAccessibilityBridge]: el AccessibilityService corre
 * en el proceso de la app, una referencia estática evita IPC. El controller
 * solo existe mientras el servicio está conectado; al desconectarse se
 * remueve la ventana (cero privilegios fantasma).
 */
object NanoOverlayBridge {

    private const val TAG = "nanoedge"

    /** Archivo de preferencias del búho (vive en el contexto del servicio). */
    private const val PREFS_NAME = "nano_edge"

    /** true = el usuario dejó la burbuja encendida (restaurar al conectar). */
    private const val KEY_BUBBLE_ENABLED = "bubble_enabled"

    /** Canal de comandos Dart → overlay. */
    const val CHANNEL_NAME = "com.nanoai/edge"

    /** Canal de eventos overlay → Dart (bubbleTapped, panelDismissed). */
    const val EVENTS_CHANNEL_NAME = "com.nanoai/edge_events"

    @Volatile
    private var controller: NanoOverlayController? = null

    @Volatile
    var eventsSink: EventChannel.EventSink? = null

    /**
     * Intención persistida del usuario (EDGE-PERSIST). ColorOS mata la app en
     * caché; al re-vincular el servicio de accesibilidad solo, la burbuja debe
     * volver sin intervención si el usuario la dejó encendida. Un solo
     * escritor (este bridge): Dart lee el estado real vía [isShowing].
     */
    @Volatile
    private var prefs: android.content.SharedPreferences? = null

    /** Llamado desde AgentAccessibilityService.onServiceConnected. */
    fun onServiceConnected(service: AgentAccessibilityService) {
        prefs = service.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        controller = NanoOverlayController(service) { event, args ->
            eventsSink?.success(mapOf("event" to event) + args)
        }
        if (prefs?.getBoolean(KEY_BUBBLE_ENABLED, false) == true) {
            controller?.showBubble()
        }
    }

    /** Llamado desde onUnbind/onDestroy: remueve la ventana de inmediato. */
    fun onServiceDisconnected() {
        controller?.detach()
        controller = null
        prefs = null
    }

    /** true si el servicio está conectado (y por tanto el overlay es posible). */
    fun isAvailable(): Boolean = controller != null

    fun showBubble(): Boolean {
        val ok = controller?.showBubble() ?: return false
        prefs?.edit()?.putBoolean(KEY_BUBBLE_ENABLED, true)?.apply()
        return ok
    }

    fun showPanel(title: String, body: String): Boolean =
        controller?.showPanel(NanoEdgeContent(title = title, body = body)) ?: false

    fun hide(): Boolean {
        val ok = controller?.hide() ?: return false
        prefs?.edit()?.putBoolean(KEY_BUBBLE_ENABLED, false)?.apply()
        return ok
    }

    fun isShowing(): Boolean = controller?.isShowing ?: false
}

/**
 * EDGE-01 — Handler del MethodChannel [NanoOverlayBridge.CHANNEL_NAME].
 *
 * Métodos: showBubble, showPanel {title, body}, hide, isShowing, isAvailable.
 * Todos responden honestamente: sin servicio conectado devuelven false, no
 * error (el overlay es una mejora visual, jamás un requisito de ejecución).
 */
class NanoEdgeChannelHandler : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "showBubble" -> result.success(NanoOverlayBridge.showBubble())
            "showPanel" -> {
                val title = call.argument<String>("title") ?: ""
                val body = call.argument<String>("body") ?: ""
                result.success(NanoOverlayBridge.showPanel(title, body))
            }
            "hide" -> result.success(NanoOverlayBridge.hide())
            "isShowing" -> result.success(NanoOverlayBridge.isShowing())
            "isAvailable" -> result.success(NanoOverlayBridge.isAvailable())
            else -> result.notImplemented()
        }
    }
}
