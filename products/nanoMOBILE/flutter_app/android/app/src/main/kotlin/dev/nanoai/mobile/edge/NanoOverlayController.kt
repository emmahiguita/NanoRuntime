package dev.nanoai.mobile.edge

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.graphics.PixelFormat
import android.util.Log
import android.view.Gravity
import android.view.WindowManager

/**
 * EDGE-01 — Controlador del overlay del búho (Nano system overlay).
 *
 * Reimplementación propia del patrón "edge overlay" (Portal es AGPLv3:
 * inspiración de arquitectura únicamente, cero código copiado). Una ventana
 * `TYPE_ACCESSIBILITY_OVERLAY` solo puede crearla un AccessibilityService,
 * por eso este controlador vive atado a [AgentAccessibilityService]:
 * sin accesibilidad conectada no hay overlay posible (cero privilegios
 * fantasma — regla dura del sprint).
 *
 * Límites (reglas duras):
 * - NUNCA lee el árbol de accesibilidad ni ejecuta gestos. Solo recibe
 *   [NanoEdgeContent] ya resuelto desde Dart y lo dibuja.
 * - El único input que procesa es su PROPIO tap (bubble → colapsar/expandir,
 *   panel → dismiss), reportado como evento a Dart. No hay inyección de
 *   input hacia la app subyacente.
 */
class NanoOverlayController(
    private val service: AccessibilityService,
    private val onEvent: (String, Map<String, Any?>) -> Unit,
) {

    companion object {
        private const val TAG = "nanoedge"

        // El overlay no toma foco de teclado ni es modal: la app subyacente
        // sigue recibiendo su input con normalidad.
        private val OVERLAY_FLAGS = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
    }

    private val windowManager =
        service.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var overlayView: NanoOverlayView? = null

    /** true si la ventana está añadida al WindowManager. */
    val isShowing: Boolean
        get() = overlayView != null

    /** Bubble visible (estado colapsado) sobre la app en foreground. */
    fun showBubble(): Boolean {
        val view = ensureWindow() ?: return false
        view.setMode(NanoOverlayView.Mode.BUBBLE)
        return true
    }

    /** Panel expandido con el contenido resuelto por Dart. */
    fun showPanel(content: NanoEdgeContent): Boolean {
        val view = ensureWindow() ?: return false
        view.setContent(content)
        view.setMode(NanoOverlayView.Mode.PANEL)
        return true
    }

    /** Oculta (remueve) la ventana por completo. Idempotente. */
    fun hide(): Boolean {
        val view = overlayView ?: return false
        try {
            windowManager.removeView(view)
        } catch (e: Exception) {
            Log.w(TAG, "hide: removeView falló: $e")
        }
        overlayView = null
        return true
    }

    /** Suelta el WindowManager (onUnbind/onDestroy del servicio). */
    fun detach() = hide()

    private fun ensureWindow(): NanoOverlayView? {
        overlayView?.let { return it }
        // Los callbacks corren DESPUÉS de la construcción: capturan `this`,
        // no la referencia local (que aún no existe durante el init).
        val view = NanoOverlayView(
            context = service,
            onTap = { mode ->
                when (mode) {
                    NanoOverlayView.Mode.BUBBLE ->
                        onEvent(NanoOverlayEvents.BUBBLE_TAPPED, emptyMap())
                    NanoOverlayView.Mode.PANEL ->
                        overlayView?.setMode(NanoOverlayView.Mode.BUBBLE)
                }
            },
            onDismiss = {
                onEvent(NanoOverlayEvents.PANEL_DISMISSED, emptyMap())
                overlayView?.setMode(NanoOverlayView.Mode.BUBBLE)
            },
        )
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            // Vía documentada para overlays de un AccessibilityService sobre
            // apps ajenas (Android 12+): el servicio es el único que puede
            // añadir este tipo de ventana.
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            OVERLAY_FLAGS,
            PixelFormat.TRANSLUCENT,
        ).apply {
            // Esquina superior derecha, con margen para no chocar con el reloj.
            gravity = Gravity.TOP or Gravity.END
            x = dp(12)
            y = dp(64)
        }
        return try {
            windowManager.addView(view, params)
            overlayView = view
            view
        } catch (e: Exception) {
            // Sin permisos o WindowManager saturado: el overlay simplemente
            // no aparece. Nunca se lanza hacia Dart (fail-closed visual).
            Log.w(TAG, "ensureWindow: addView falló: $e")
            null
        }
    }

    private fun dp(value: Int): Int =
        (value * service.resources.displayMetrics.density).toInt()
}

/** Eventos del overlay hacia Dart (EventChannel edge_events). */
object NanoOverlayEvents {
    const val BUBBLE_TAPPED = "bubbleTapped"
    const val PANEL_DISMISSED = "panelDismissed"
}
