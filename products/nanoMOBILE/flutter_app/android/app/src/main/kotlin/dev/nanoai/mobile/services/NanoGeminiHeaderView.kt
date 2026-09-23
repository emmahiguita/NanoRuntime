package dev.nanoai.mobile.services

import android.content.Context
import android.graphics.Color
import android.view.Gravity
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import dev.nanoai.mobile.R

/**
 * NanoGeminiHeaderView — Cabecera Glass de Búho AI para el overlay flotante nativo.
 *
 * QUÉ: Muestra el avatar de Búho en aro cósmico, los títulos y acciones de ventana.
 * CÓMO: LinearLayout horizontal con ImageView circular, textos tipográficos M3,
 *       botón para expandir a app completa (⇱) y botón para colapsar a burbuja (✕).
 * POR QUÉ: Otorga identidad visual canónica idéntica a Flutter Hub sin salir de la app externa.
 * SOLID-S: Única responsabilidad: renderizar y despachar eventos de la cabecera del panel.
 */
internal class NanoGeminiHeaderView(
    context: Context,
    private val onClose: () -> Unit,
    private val onOpenFullApp: () -> Unit,
) : LinearLayout(context) {

    private fun dp(n: Int) = NanoOverlayStyle.dp(context, n)

    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        setPadding(dp(16), dp(12), dp(16), dp(8))

        // 1. Avatar Búho en aro cósmico
        val owlIcon = ImageView(context).apply {
            setImageResource(R.drawable.nano_owl_idle)
            scaleType = ImageView.ScaleType.CENTER_CROP
        }
        val avatarRing = FrameLayout(context).apply {
            background = NanoOverlayStyle.chip(context, active = true, activeColor = NanoOverlayStyle.cyanGlow)
            setPadding(dp(3), dp(3), dp(3), dp(3))
            addView(owlIcon, FrameLayout.LayoutParams(dp(36), dp(36), Gravity.CENTER))
        }
        addView(avatarRing, LayoutParams(dp(42), dp(42)))

        // 2. Textos: Título principal y subtítulo de capacidades
        val titlesCol = LinearLayout(context).apply {
            orientation = VERTICAL
            setPadding(dp(10), 0, dp(8), 0)

            val title = NanoOverlayStyle.text(context, "Búho AI", sizeSp = 15f, bold = true)
            val subtitle = NanoOverlayStyle.text(
                context, "Web intelligence & Assistant", sizeSp = 11f,
                color = NanoOverlayStyle.onSurfaceMuted
            )
            addView(title)
            addView(subtitle)
        }
        addView(titlesCol, LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))

        // 3. Botón para abrir la app principal en pantalla completa
        val openAppBtn = createIconButton("⇱", "Abrir Nano completo") { onOpenFullApp() }
        addView(openAppBtn, LayoutParams(dp(32), dp(32)).apply { rightMargin = dp(6) })

        // 4. Botón de cierre que colapsa el panel de regreso a la burbuja
        val closeBtn = createIconButton("✕", "Minimizar a burbuja") { onClose() }
        addView(closeBtn, LayoutParams(dp(32), dp(32)))
    }

    private fun createIconButton(label: String, tooltip: String, onClick: () -> Unit): TextView =
        TextView(context).apply {
            text = label
            textSize = 14f
            setTextColor(Color.rgb(200, 215, 235))
            gravity = Gravity.CENTER
            background = NanoOverlayStyle.circleBtn(context)
            contentDescription = tooltip
            isClickable = true
            setOnClickListener { onClick() }
        }
}
