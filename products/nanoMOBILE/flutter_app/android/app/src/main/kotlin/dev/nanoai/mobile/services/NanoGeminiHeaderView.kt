package dev.nanoai.mobile.services

import android.content.Context
import android.view.Gravity
import android.widget.ImageView
import android.widget.LinearLayout
import dev.nanoai.mobile.R

/** Cabecera compartida visualmente con Flutter. Reutiliza el avatar existente;
 * el historial y contraer conservan callbacks diferentes y áreas de 48 dp. */
internal class NanoGeminiHeaderView(
    context: Context,
    onClose: () -> Unit,
    onOpenFullApp: () -> Unit,
    onHistory: () -> Unit,
) : LinearLayout(context) {
    private fun dp(n: Int) = NanoOverlayStyle.dp(context, n)

    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        setPadding(dp(14), dp(10), dp(10), dp(10))
        addView(ImageView(context).apply {
            setImageResource(R.drawable.nano_owl_idle)
            scaleType = ImageView.ScaleType.FIT_CENTER
            contentDescription = "Abrir Nano"
            isClickable = true
            setOnClickListener { onOpenFullApp() }
        }, LayoutParams(dp(44), dp(44)))
        addView(LinearLayout(context).apply {
            orientation = VERTICAL
            setPadding(dp(8), 0, dp(4), 0)
            addView(NanoOverlayStyle.text(context, "Búho AI", 15f, bold = true))
            addView(NanoOverlayStyle.text(context, "Asistente de Nano", 11.5f,
                color = NanoOverlayStyle.onSurfaceMuted))
        }, LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
        addView(icon("history", "Historial de acciones", onHistory), LayoutParams(dp(48), dp(48)))
        addView(icon("close", "Contraer panel", onClose), LayoutParams(dp(48), dp(48)))
    }

    /** Símbolo pequeño dentro de un área táctil completa, sin otra placa. */
    private fun icon(kind: String, label: String, action: () -> Unit) = ImageView(context).apply {
        setImageDrawable(NanoPanelIcon(kind, NanoOverlayStyle.onSurfaceMuted))
        setPadding(dp(13), dp(13), dp(13), dp(13))
        contentDescription = label
        isClickable = true
        background = NanoOverlayStyle.ripple(context, NanoOverlayStyle.circleBtn(context))
        setOnClickListener { action() }
    }
}
