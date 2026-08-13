package dev.nanoai.mobile.channels

import android.os.Handler
import android.os.Looper
import dev.nanoai.mobile.services.AgentAccessibilityBridge
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Handler del canal `com.nanoai/agent`: agente de UI sobre AccessibilityService.
 *
 * Contrato de métodos (v1):
 * - `getStatus`                 → {connected, root}
 * - `dumpScreen`                → List<Map> — árbol a11y de la ventana activa
 * - `findText {query, maxResults}` → List<Map>
 * - `tapOnText {text}`          → bool
 * - `tapAt {x, y}`              → bool
 * - `longPressAt {x, y, durationMs}` → bool
 * - `swipe {x1,y1,x2,y2,durationMs}` → bool
 * - `inputText {text}`          → bool
 * - `globalAction {action}`     → bool (back|home|recents|notifications|quick_settings)
 * - `launchPackage {packageName}` → bool
 *
 * El AccessibilityNodeInfo está ligado al hilo del service (main). Todas las
 * llamadas se despachan ahí con post + latch; timeout de seguridad 5s.
 */
class AgentChannelHandler : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.nanoai/agent"

        /** Capacidades que declara el agente en el handshake de runtime. */
        val CAPABILITIES = listOf(
            "agent",        // agente de UI instalado (service declarado)
            "dump-screen",  // dumpScreen / findText
            "gestures",     // tapAt / longPressAt / swipe
            "text-input",   // inputText
            "global",       // globalAction back/home/recents
            "launch",       // launchPackage
        )

        /** Reintentos al esperar el rebind del AccessibilityService. */
        private const val REBIND_RETRIES = 4
        private const val REBIND_RETRY_DELAY_MS = 250L
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> {
                val service = AgentAccessibilityBridge.service
                if (service == null) {
                    result.success(mapOf("connected" to false, "root" to ""))
                } else {
                    postToService(service, result) { it.status() }
                }
            }

            "dumpScreen" -> postToService(AgentAccessibilityBridge.service, result) { it.dumpScreen() }

            "findText" -> {
                val query = call.argument<String>("query")
                if (query.isNullOrBlank()) {
                    result.error("BAD_ARG", "query requerido", null)
                    return
                }
                val maxResults = (call.argument<Number>("maxResults")?.toInt()) ?: 10
                postToService(AgentAccessibilityBridge.service, result) {
                    it.findText(query, maxResults)
                }
            }

            "tapOnText" -> {
                val text = call.argument<String>("text")
                if (text.isNullOrBlank()) {
                    result.error("BAD_ARG", "text requerido", null)
                    return
                }
                postToService(AgentAccessibilityBridge.service, result) { it.tapOnText(text) }
            }

            "tapAt" -> {
                val x = call.argument<Number>("x")?.toInt()
                val y = call.argument<Number>("y")?.toInt()
                if (x == null || y == null) {
                    result.error("BAD_ARG", "x e y requeridos", null)
                    return
                }
                postToService(AgentAccessibilityBridge.service, result) { it.tapAt(x, y) }
            }

            "longPressAt" -> {
                val x = call.argument<Number>("x")?.toInt()
                val y = call.argument<Number>("y")?.toInt()
                val durationMs = (call.argument<Number>("durationMs")?.toInt()) ?: 600
                if (x == null || y == null) {
                    result.error("BAD_ARG", "x e y requeridos", null)
                    return
                }
                postToService(AgentAccessibilityBridge.service, result) {
                    it.longPressAt(x, y, durationMs)
                }
            }

            "swipe" -> {
                val x1 = call.argument<Number>("x1")?.toInt()
                val y1 = call.argument<Number>("y1")?.toInt()
                val x2 = call.argument<Number>("x2")?.toInt()
                val y2 = call.argument<Number>("y2")?.toInt()
                val durationMs = (call.argument<Number>("durationMs")?.toInt()) ?: 300
                if (x1 == null || y1 == null || x2 == null || y2 == null) {
                    result.error("BAD_ARG", "x1,y1,x2,y2 requeridos", null)
                    return
                }
                postToService(AgentAccessibilityBridge.service, result) {
                    it.swipe(x1, y1, x2, y2, durationMs)
                }
            }

            "inputText" -> {
                val text = call.argument<String>("text")
                if (text == null) {
                    result.error("BAD_ARG", "text requerido", null)
                    return
                }
                postToService(AgentAccessibilityBridge.service, result) { it.inputText(text) }
            }

            "globalAction" -> {
                val action = call.argument<String>("action")
                if (action.isNullOrBlank()) {
                    result.error("BAD_ARG", "action requerido", null)
                    return
                }
                postToService(AgentAccessibilityBridge.service, result) { it.globalAction(action) }
            }

            "launchPackage" -> {
                val pkg = call.argument<String>("packageName")
                if (pkg.isNullOrBlank()) {
                    result.error("BAD_ARG", "packageName requerido", null)
                    return
                }
                postToService(AgentAccessibilityBridge.service, result) { it.launchPackage(pkg) }
            }

            else -> result.notImplemented()
        }
    }

    /**
     * Ejecuta [block] en el hilo del service y devuelve el resultado por
     * [result]. Si el service no está conectado → error SERVICE_OFF.
     *
     * NUNCA bloquea el main thread: Flutter entrega los MethodChannel en el
     * main de Android (mismo hilo que el AccessibilityService), y un sleep o
     * latch ahí es un ANR → el sistema congela los input events y deja
     * pointer fantasma. El retry de rebind usa postDelayed, que vuelve al
     * looper sin bloquear nada.
     */
    private fun <T> postToService(
        service: dev.nanoai.mobile.services.AgentAccessibilityService?,
        result: MethodChannel.Result,
        block: (dev.nanoai.mobile.services.AgentAccessibilityService) -> T,
    ) {
        // El sistema desvincula y re-vincula el AccessibilityService al
        // recrear MainActivity (onUnbind → onServiceConnected). El bridge
        // queda null durante esa ventana (~100-500ms). Reintentamos un par de
        // veces antes de declarar SERVICE_OFF, para no fallar el gesto del
        // usuario justo tras navegar.
        val isMainThread = Looper.myLooper() == Looper.getMainLooper()
        if (isMainThread) {
            retryOnMain(result, 0, block)
            return
        }
        // Fallback defensivo (canal invocado desde hilo no-main): reintento
        // con sleeps cortos aquí es seguro (no bloquea el main), y ejecuta con
        // post + latch solo como última red.
        var current = service
        var attempt = 0
        while (current == null && attempt < REBIND_RETRIES) {
            Thread.sleep(REBIND_RETRY_DELAY_MS)
            current = AgentAccessibilityBridge.service
            attempt++
        }
        if (current == null) {
            result.error("SERVICE_OFF", "AgentAccessibilityService no conectado — activarlo en Ajustes → Accesibilidad", null)
            return
        }
        val latch = CountDownLatch(1)
        var value: Any? = null
        var failure: Exception? = null
        mainHandler.post {
            try {
                value = block(current)
            } catch (e: Exception) {
                failure = e
            } finally {
                latch.countDown()
            }
        }
        val done = try {
            latch.await(10, TimeUnit.SECONDS)
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
            false
        }
        when {
            !done -> result.error("TIMEOUT", "agente no respondió en 10s", null)
            failure != null -> result.error("AGENT_ERR", failure!!.message ?: "error", null)
            else -> result.success(value)
        }
    }

    /**
     * Intenta ejecutar [block] en el main thread, reintentando con
     * [mainHandler].postDelayed si el service aún está en rebind. No bloquea:
     * cada intento vuelve al looper, así el main sigue procesando input.
     */
    private fun <T> retryOnMain(
        result: MethodChannel.Result,
        attempt: Int,
        block: (dev.nanoai.mobile.services.AgentAccessibilityService) -> T,
    ) {
        val current = AgentAccessibilityBridge.service
        if (current == null) {
            if (attempt < REBIND_RETRIES) {
                mainHandler.postDelayed(
                    { retryOnMain(result, attempt + 1, block) },
                    REBIND_RETRY_DELAY_MS,
                )
            } else {
                result.error("SERVICE_OFF", "AgentAccessibilityService no conectado — activarlo en Ajustes → Accesibilidad", null)
            }
            return
        }
        try {
            result.success(block(current))
        } catch (e: Exception) {
            result.error("AGENT_ERR", e.message ?: "error", null)
        }
    }
}