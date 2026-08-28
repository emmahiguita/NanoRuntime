package dev.nanoai.mobile.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.Display
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import dev.nanoai.mobile.MainActivity
import dev.nanoai.mobile.RuntimeHeartbeat
import java.io.File
import java.util.concurrent.Executors

/**
 * Agente de UI para NanoAI Local — AccessibilityService.
 *
 * Expone al agente LLM (y a Dart) control del UI del dispositivo: leer el árbol
 * de accesibilidad de la ventana activa como JSON, buscar texto, y ejecutar
 * acciones (tap, long-press, swipe, input, back/home/recents, launch).
 *
 * Diseño:
 * - Corre en el proceso de la app (no remoto). [AgentAccessibilityBridge] guarda
 *   la instancia activa; el canal `com.nanoai/agent` (MainActivity) delega aquí.
 * - Todas las acciones van por [performAction] con validación estricta de
 *   argumentos — nunca se confía en el LLM para coordenadas sin verificar
 *   contra el árbol (bounds reales del nodo).
 * - dispatchGesture solo se usa con API 24+ (minSdk 26): OK.
 *
 * Seguridad: el servicio NO expone paths de archivos ni shell. Solo interacción
 * de UI. El control de qué se permite (find/tap/input) lo define el agente
 * aguas arriba, este servicio es el brazo de ejecución mínimo.
 */
class AgentAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "nanoagent"
        private const val MAX_DEPTH = 10
        private const val MAX_NODES = 800
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val mainThreadHandler = android.os.Handler(android.os.Looper.getMainLooper())

    private data class TraversalState(
        var nodeLimitReached: Boolean = false,
        var depthLimitReached: Boolean = false,
    )

    override fun onServiceConnected() {
        super.onServiceConnected()
        // NOTA: no reasignar serviceInfo aquí. Hacerlo dispara un rebind del
        // sistema (setServiceInfo interno) → bucle onUnbind/onServiceConnected
        // y el bridge queda null intermitentemente. La configuración (flags,
        // eventTypes, canRetrieveWindowContent) ya viene de
        // res/xml/accessibility_service_config.xml.
        AgentAccessibilityBridge.onConnected(this)
        Log.i(TAG, "AgentAccessibilityService conectado")
        // U-10: vector resurrección — tras un cached-kill de ColorOS el
        // sistema re-vincula este service él mismo (los accessibility
        // services habilitados se reinician sin acción del usuario). Si el
        // runtime desktop quedó vivo sin apagado limpio, re-lanzamos
        // MainActivity: los accessibility services están exentos de las
        // restricciones de background activity launch (BAL). beginResurrect
        // aplica ventana anti-loop — si ColorOS mata en bucle el proceso
        // recién revivido, no relanzamos en cada rebind.
        val nanoDir = File(filesDir, "nano")
        if (RuntimeHeartbeat.wasKilledByOs(nanoDir) && RuntimeHeartbeat.beginResurrect(nanoDir)) {
            Log.i(TAG, "U-10: kill del OS detectado — relanzando MainActivity")
            startActivity(
                Intent(this, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Sin lógica reactiva en v1: el agente consulta dumpScreen() on demand.
        // El evento solo mantiene el service vivo y despierta el árbol.
    }

    override fun onInterrupt() = Unit

    override fun onUnbind(intent: Intent?): Boolean {
        Log.i(TAG, "onUnbind — service se desvincula, bridge null temporal")
        AgentAccessibilityBridge.onDisconnected()
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        AgentAccessibilityBridge.onDisconnected()
        executor.shutdownNow()
        super.onDestroy()
    }

    // ── Lectura del árbol ────────────────────────────────────────────────────

    /** Dump de la ventana activa a lista de maps (JSON-friendly). */
    fun dumpScreen(): List<Map<String, Any?>> {
        val root = rootInActiveWindow ?: return emptyList()
        val result = mutableListOf<Map<String, Any?>>()
        walk(root, 0, result)
        root.recycle()
        return result
    }

    /**
     * Snapshot enriquecido de la ventana activa: package del root + nodos con
     * depth. Lo consume el Selector Engine en Dart: el package permite
     * verificar expectedPackage y el depth alimenta el rol/posición.
     *
     * Asunción: [AccessibilityNodeInfo.getPackageName] existe desde API 14
     * (minSdk 26 OK). En ventanas OEM (overlays, launchers) puede ser null →
     * "" (nunca excepción).
     */
    fun dumpSnapshot(): Map<String, Any?> {
        val root = rootInActiveWindow
            ?: return mapOf(
                "package" to "",
                "nodes" to emptyList<Map<String, Any?>>(),
                "truncated" to false,
                "nodeLimitReached" to false,
                "depthLimitReached" to false,
            )
        val result = mutableListOf<Map<String, Any?>>()
        val traversal = TraversalState()
        walk(root, 0, result, withDepth = true, traversal = traversal)
        val pkg = root.packageName?.toString() ?: ""
        root.recycle()
        return mapOf(
            "package" to pkg,
            "nodes" to result,
            "truncated" to (traversal.nodeLimitReached || traversal.depthLimitReached),
            "nodeLimitReached" to traversal.nodeLimitReached,
            "depthLimitReached" to traversal.depthLimitReached,
        )
    }

    private fun walk(
        node: AccessibilityNodeInfo?,
        depth: Int,
        out: MutableList<Map<String, Any?>>,
        withDepth: Boolean = false,
        traversal: TraversalState? = null,
    ) {
        if (node == null) return
        if (depth > MAX_DEPTH) {
            traversal?.depthLimitReached = true
            return
        }
        if (out.size >= MAX_NODES) {
            traversal?.nodeLimitReached = true
            return
        }
        out.add(if (withDepth) nodeToMap(node, depth) else nodeToMap(node))
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            walk(child, depth + 1, out, withDepth, traversal)
            child?.recycle()
        }
    }

    private fun nodeToMap(node: AccessibilityNodeInfo, depth: Int? = null): Map<String, Any?> {
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        return buildMap {
            put("id", node.viewIdResourceName ?: "")
            put("type", node.className?.toString() ?: "")
            put("text", node.text?.toString() ?: "")
            put("desc", node.contentDescription?.toString() ?: "")
            put("clickable", node.isClickable)
            put("editable", node.isEditable)
            put("scrollable", node.isScrollable)
            put("checked", node.isChecked)
            put("focusable", node.isFocusable)
            put("focused", node.isFocused)
            put("visible", node.isVisibleToUser)
            put("enabled", node.isEnabled)
            put("bounds", intArrayOf(bounds.left, bounds.top, bounds.right, bounds.bottom))
            // Solo dumpSnapshot incluye depth; dumpScreen conserva su contrato.
            if (depth != null) put("depth", depth)
        }
    }

    // ── Búsqueda ─────────────────────────────────────────────────────────────

    /** Encuentra nodos cuyo texto/desc contenga [query] (case-insensitive). */
    fun findText(query: String, maxResults: Int = 10): List<Map<String, Any?>> {
        val root = rootInActiveWindow ?: return emptyList()
        val q = query.lowercase()
        val hits = mutableListOf<Map<String, Any?>>()
        val stack = ArrayDeque<AccessibilityNodeInfo>()
        stack.add(root)
        while (stack.isNotEmpty() && hits.size < maxResults) {
            val node = stack.removeLast()
            val text = node.text?.toString()?.lowercase() ?: ""
            val desc = node.contentDescription?.toString()?.lowercase() ?: ""
            if (text.contains(q) || desc.contains(q)) {
                hits.add(nodeToMap(node))
            }
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { stack.add(it) }
            }
        }
        root.recycle()
        return hits
    }

    // ── Acciones ─────────────────────────────────────────────────────────────

    /**
     * Tap sobre un nodo cuyo texto/desc contiene [text]. Devuelve true si se
     * encontró y ejecutó. Usa el centro real del bounds del nodo.
     */
    fun tapOnText(text: String): Boolean {
        val node = findFirstClickableByText(text) ?: return false
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        val cx = bounds.centerX()
        val cy = bounds.centerY()
        node.recycle()
        return gestureTap(cx, cy)
    }

    /** Tap en coordenadas absolutas de pantalla. */
    fun tapAt(x: Int, y: Int): Boolean = gestureTap(x, y)

    fun longPressAt(x: Int, y: Int, durationMs: Int = 600): Boolean =
        gestureTap(x, y, durationMs.coerceAtLeast(400))

    fun swipe(x1: Int, y1: Int, x2: Int, y2: Int, durationMs: Int = 300): Boolean {
        if (x1 < 0 || y1 < 0 || x2 < 0 || y2 < 0) return false
        val path = Path().apply {
            moveTo(x1.toFloat(), y1.toFloat())
            lineTo(x2.toFloat(), y2.toFloat())
        }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, durationMs.toLong()))
            .build()
        return dispatchGesture(gesture, null, null)
    }

    /**
     * Escribe texto únicamente en el nodo resuelto por Dart. El foco, id y
     * bounds deben seguir coincidiendo en el instante de ACTION_SET_TEXT;
     * cualquier cambio de pantalla/foco aborta en vez de escribir en otro campo.
     */
    fun inputText(text: String, targetResourceId: String, targetBounds: IntArray): Boolean {
        val node = findFocusedEditable(targetResourceId, targetBounds) ?: return false
        val args = Bundle().apply {
            putCharSequence(
                AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE,
                text,
            )
        }
        val ok = node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        node.recycle()
        return ok
    }

    /** Global actions: back / home / recents. */
    fun globalAction(action: String): Boolean {
        val mapped = when (action.lowercase()) {
            "back" -> GLOBAL_ACTION_BACK
            "home" -> GLOBAL_ACTION_HOME
            "recents" -> GLOBAL_ACTION_RECENTS
            "notifications" -> GLOBAL_ACTION_NOTIFICATIONS
            "quick_settings" -> GLOBAL_ACTION_QUICK_SETTINGS
            else -> return false
        }
        return performGlobalAction(mapped)
    }

    /** Lanza una app por package name. */
    fun launchPackage(packageName: String): Boolean {
        if (!packageName.matches(Regex("[a-zA-Z0-9._]+"))) {
            Log.w(TAG, "launchPackage($packageName): nombre inválido")
            return false
        }
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        if (intent == null) {
            Log.w(TAG, "launchPackage($packageName): sin launch intent")
            return false
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            startActivity(intent)
            Log.i(TAG, "launchPackage($packageName): lanzado")
            true
        } catch (e: Exception) {
            Log.w(TAG, "launchPackage($packageName) falló: $e")
            false
        }
    }

    /**
     * Captura pantalla (A9, OCR dirigido). API 30+ (AccessibilityService
     * takeScreenshot). callback(null) si no soportado o falla.
     */
    fun takeScreenshot(callback: (Bitmap?) -> Unit) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            Log.w(TAG, "takeScreenshot: requiere API 30+")
            callback(null)
            return
        }
        takeScreenshot(
            Display.DEFAULT_DISPLAY,
            mainExecutor,
            object : TakeScreenshotCallback {
                override fun onSuccess(screenshot: ScreenshotResult) {
                    val bitmap = try {
                        Bitmap.wrapHardwareBuffer(
                            screenshot.hardwareBuffer,
                            screenshot.colorSpace,
                        )
                    } catch (e: Exception) {
                        null
                    } finally {
                        screenshot.hardwareBuffer.close()
                    }
                    callback(bitmap)
                }

                override fun onFailure(errorCode: Int) {
                    Log.w(TAG, "takeScreenshot onFailure: $errorCode")
                    callback(null)
                }
            },
        )
    }

    /** estado del servicio para el handshake. NO toca el árbol (el binder
     *  rootInActiveWindow puede colgar si el sistema está reconfigurando). */
    fun status(): Map<String, Any> = mapOf(
        "connected" to true,
        "canRetrieveWindowContent" to true,
    )    // ── Internos ─────────────────────────────────────────────────────────────

    private fun findFirstClickableByText(text: String): AccessibilityNodeInfo? {
        val root = rootInActiveWindow ?: return null
        val q = text.lowercase()
        var found: AccessibilityNodeInfo? = null
        val stack = ArrayDeque<AccessibilityNodeInfo>()
        stack.add(root)
        while (stack.isNotEmpty() && found == null) {
            val node = stack.removeLast()
            val t = node.text?.toString()?.lowercase() ?: ""
            val d = node.contentDescription?.toString()?.lowercase() ?: ""
            if ((t.contains(q) || d.contains(q)) && node.isClickable) {
                found = node
                break
            }
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { stack.add(it) }
            }
        }
        root.recycle()
        return found
    }

    private fun findFocusedEditable(
        targetResourceId: String,
        targetBounds: IntArray,
    ): AccessibilityNodeInfo? {
        val root = rootInActiveWindow ?: return null
        var found: AccessibilityNodeInfo? = null
        val stack = ArrayDeque<AccessibilityNodeInfo>()
        stack.add(root)
        while (stack.isNotEmpty() && found == null) {
            val node = stack.removeLast()
            val bounds = Rect()
            node.getBoundsInScreen(bounds)
            val idMatches = targetResourceId.isBlank() ||
                node.viewIdResourceName == targetResourceId
            val boundsMatch = targetBounds.size == 4 &&
                bounds.left == targetBounds[0] &&
                bounds.top == targetBounds[1] &&
                bounds.right == targetBounds[2] &&
                bounds.bottom == targetBounds[3]
            if (node.isEditable && node.isFocused && idMatches && boundsMatch) {
                found = node
                break
            }
            for (i in 0 until node.childCount) {
                node.getChild(i)?.let { stack.add(it) }
            }
        }
        root.recycle()
        return found
    }

    private fun gestureTap(x: Int, y: Int, durationMs: Int = 60): Boolean {
        if (x < 0 || y < 0) return false
        val path = Path().apply { moveTo(x.toFloat(), y.toFloat()) }
        val gesture = GestureDescription.Builder()
            .addStroke(GestureDescription.StrokeDescription(path, 0, durationMs.toLong()))
            .build()
        return dispatchGesture(gesture, null, null)
    }
}

/**
 * Bridge estático service ↔ canal Flutter.
 *
 * El AccessibilityService corre en el mismo proceso que MainActivity, así que
 * una referencia estática es suficiente y evita IPC. Se limpia en onUnbind/
 * onDestroy para no colgar el GC.
 */
object AgentAccessibilityBridge {
    @Volatile
    var service: AgentAccessibilityService? = null
        private set

    fun onConnected(s: AgentAccessibilityService) {
        service = s
    }

    fun onDisconnected() {
        service = null
    }
}
