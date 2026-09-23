package dev.nanoai.mobile.services

import android.animation.ValueAnimator
import android.content.Context
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import kotlin.math.abs

/**
 * NanoBubbleTouchHelper — Manejador táctil magnético y acoplamiento lateral estilo iOS.
 *
 * QUÉ: Proporciona arrastre suave, snap magnético a los bordes y retracción a pestaña lateral.
 * CÓMO: MotionEvent analiza desplazamiento; ValueAnimator anima el snap en 220ms.
 * POR QUÉ: Extrae la lógica de interacción de NanoFloatingService manteniendo archivos < 180 líneas (SOLID-S).
 * ZOMBI: cancel() limpia cualquier ValueAnimator activo al destruir el servicio.
 */
internal class NanoBubbleTouchHelper(
    private val context: Context,
    private val layout: WindowManager.LayoutParams,
    private val onUpdate: () -> Unit,
    private val onClick: () -> Unit,
    private val onDoubleTap: () -> Unit,
) : View.OnTouchListener {

    private fun dp(n: Int) = NanoOverlayStyle.dp(context, n)
    private var snapping: ValueAnimator? = null
    private var sx = 0f; private var sy = 0f; private var px = 0; private var py = 0
    private var moved = false
    private var lastDownTime = 0L

    override fun onTouch(v: View, e: MotionEvent): Boolean {
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                sx = e.rawX; sy = e.rawY; px = layout.x; py = layout.y
                moved = false
                snapping?.cancel()
                val now = System.currentTimeMillis()
                if (now - lastDownTime < 280) { onDoubleTap(); return true }
                lastDownTime = now
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                if (abs(e.rawX - sx) > dp(5) || abs(e.rawY - sy) > dp(5)) moved = true
                if (moved) {
                    val d = context.resources.displayMetrics
                    layout.x = (px + e.rawX - sx).toInt().coerceIn(0, (d.widthPixels - layout.width).coerceAtLeast(0))
                    layout.y = (py + e.rawY - sy).toInt().coerceIn(0, (d.heightPixels - layout.height).coerceAtLeast(0))
                    onUpdate()
                }
                return true
            }
            MotionEvent.ACTION_UP -> {
                if (!moved) onClick() else snapToEdge()
                return true
            }
        }
        return false
    }

    private fun snapToEdge() {
        val d = context.resources.displayMetrics
        val limit = (d.widthPixels - layout.width).coerceAtLeast(0)
        val goal = if (layout.x < limit / 2) dp(6) else (limit - dp(6)).coerceAtLeast(0)
        snapping = ValueAnimator.ofInt(layout.x, goal).apply {
            duration = 220
            addUpdateListener {
                layout.x = (it.animatedValue as Int).coerceIn(0, limit)
                onUpdate()
            }
            start()
        }
    }

    fun cancel() {
        snapping?.cancel()
        snapping = null
    }
}
