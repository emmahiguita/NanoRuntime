package dev.nanoai.mobile.edge

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.util.TypedValue
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView

/**
 * EDGE-01 — Contenido resuelto que el overlay dibuja. Llega de Dart ya
 * fusionado (EDGE-02/EDGE-03): esta clase Kotlin no deriva nada, solo
 * transporta datos.
 */
data class NanoEdgeContent(
    val title: String,
    val body: String,
)

/**
 * EDGE-01 — Vista programática del búho: bubble colapsado + panel de texto.
 *
 * Sin inflate XML y sin Flutter: una vista nativa mínima que el servicio de
 * accesibilidad puede añadir como TYPE_ACCESSIBILITY_OVERLAY. No tiene ni
 * una sola referencia al árbol de accesibilidad ni a gestos de dispatch.
 */
class NanoOverlayView(
    context: Context,
    private val onTap: (Mode) -> Unit,
    private val onDismiss: () -> Unit,
) : LinearLayout(context) {

    enum class Mode { BUBBLE, PANEL }

    var mode: Mode = Mode.BUBBLE
        private set

    private val bubble: TextView
    private val panel: LinearLayout
    private val panelTitle: TextView
    private val panelBody: TextView

    init {
        orientation = VERTICAL
        gravity = Gravity.END

        bubble = TextView(context).apply {
            text = "🦉" // 🦉 búho
            textSize = 22f
            gravity = Gravity.CENTER
            setPadding(dp(10), dp(8), dp(10), dp(8))
            background = pill(Color.parseColor("#CC0B1E3A"), Color.parseColor("#4D0B1E3A"))
            setOnClickListener { onTap(mode) }
        }

        panel = LinearLayout(context).apply {
            orientation = VERTICAL
            setPadding(dp(14), dp(10), dp(14), dp(12))
            background = pill(Color.parseColor("#F20B1E3A"), Color.parseColor("#660B1E3A"))
            // El panel colapsa al tocar fuera solo vía su propia X: no hay
            // listener global que intercepte la app subyacente.
            visibility = GONE
        }
        panelTitle = TextView(context).apply {
            setTextColor(Color.WHITE)
            textSize = 15f
            setTypeface(typeface, android.graphics.Typeface.BOLD)
            maxLines = 1
        }
        panelBody = TextView(context).apply {
            setTextColor(Color.parseColor("#E6FFFFFF"))
            textSize = 13f
            maxLines = 3
            setLineSpacing(0f, 1.15f)
        }
        val dismiss = TextView(context).apply {
            text = "✕"
            setTextColor(Color.parseColor("#B3FFFFFF"))
            textSize = 16f
            gravity = Gravity.END
            setPadding(dp(4), 0, dp(2), 0)
            setOnClickListener { onDismiss() }
        }

        panel.addView(panelTitle)
        panel.addView(dismiss)
        panel.addView(panelBody)

        addView(bubble)
        addView(panel)
        setMode(Mode.BUBBLE)
    }

    fun setContent(content: NanoEdgeContent) {
        panelTitle.text = content.title
        panelBody.text = content.body
    }

    fun setMode(newMode: Mode) {
        mode = newMode
        bubble.visibility = if (newMode == Mode.BUBBLE) VISIBLE else GONE
        panel.visibility = if (newMode == Mode.PANEL) VISIBLE else GONE
    }

    private fun pill(fill: Int, stroke: Int) = GradientDrawable().apply {
        cornerRadius = dp(18).toFloat()
        setColor(fill)
        setStroke(dp(1), stroke)
    }

    private fun dp(value: Int): Int = TypedValue.applyDimension(
        TypedValue.COMPLEX_UNIT_DIP,
        value.toFloat(),
        resources.displayMetrics,
    ).toInt()
}
