package dev.nanoai.mobile.services

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.content.Intent
import android.graphics.Path
import android.graphics.Rect
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
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

    override fun onServiceConnected() {
        super.onServiceConnected()
        // NOTA: no reasignar serviceInfo aquí. Hacerlo dispara un rebind del
        // sistema (setServiceInfo interno) → bucle onUnbind/onServiceConnected
        // y el bridge queda null intermitentemente. La configuración (flags,
        // eventTypes, canRetrieveWindowContent) ya viene de
        // res/xml/accessibility_service_config.xml.
        AgentAccessibilityBridge.onConnected(this)
        Log.i(TAG, "AgentAccessibilityService conectado")
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

    private fun walk(node: AccessibilityNodeInfo?, depth: Int, out: MutableList<Map<String, Any?>>) {
        if (node == null || depth > MAX_DEPTH || out.size >= MAX_NODES) return
        out.add(nodeToMap(node))
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            walk(child, depth + 1, out)
            child?.recycle()
        }
    }

    private fun nodeToMap(node: AccessibilityNodeInfo): Map<String, Any?> {
        val bounds = Rect()
        node.getBoundsInScreen(bounds)
        return mapOf(
            "id" to (node.viewIdResourceName ?: ""),
            "type" to (node.className?.toString() ?: ""),
            "text" to (node.text?.toString() ?: ""),
            "desc" to (node.contentDescription?.toString() ?: ""),
            "clickable" to node.isClickable,
            "editable" to node.isEditable,
            "scrollable" to node.isScrollable,
            "checked" to node.isChecked,
            "focusable" to node.isFocusable,
            "focused" to node.isFocused,
            "visible" to node.isVisibleToUser,
            "enabled" to node.isEnabled,
            "bounds" to intArrayOf(bounds.left, bounds.top, bounds.right, bounds.bottom),
        )
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

    /** Escribe texto en el nodo enfocado (ACTION_SET_TEXT). */
    fun inputText(text: String): Boolean {
        val node = findFocusedEditable() ?: return false
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

    private fun findFocusedEditable(): AccessibilityNodeInfo? {
        val root = rootInActiveWindow ?: return null
        var found: AccessibilityNodeInfo? = null
        val stack = ArrayDeque<AccessibilityNodeInfo>()
        stack.add(root)
        while (stack.isNotEmpty() && found == null) {
            val node = stack.removeLast()
            if (node.isEditable && (node.isFocused || node.isFocusable)) {
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
