package dev.nanoai.mobile.edge

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

    /** Canal de comandos Dart → overlay. */
    const val CHANNEL_NAME = "com.nanoai/edge"

    /** Canal de eventos overlay → Dart (bubbleTapped, panelDismissed). */
    const val EVENTS_CHANNEL_NAME = "com.nanoai/edge_events"

    @Volatile
    private var controller: NanoOverlayController? = null

    @Volatile
    var eventsSink: EventChannel.EventSink? = null

    /** Llamado desde AgentAccessibilityService.onServiceConnected. */
    fun onServiceConnected(service: AgentAccessibilityService) {
        controller = NanoOverlayController(service) { event, args ->
            eventsSink?.success(mapOf("event" to event) + args)
        }
    }

    /** Llamado desde onUnbind/onDestroy: remueve la ventana de inmediato. */
    fun onServiceDisconnected() {
        controller?.detach()
        controller = null
    }

    /** true si el servicio está conectado (y por tanto el overlay es posible). */
    fun isAvailable(): Boolean = controller != null

    fun showBubble(): Boolean = controller?.showBubble() ?: false

    fun showPanel(title: String, body: String): Boolean =
        controller?.showPanel(NanoEdgeContent(title = title, body = body)) ?: false

    fun hide(): Boolean = controller?.hide() ?: false

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
