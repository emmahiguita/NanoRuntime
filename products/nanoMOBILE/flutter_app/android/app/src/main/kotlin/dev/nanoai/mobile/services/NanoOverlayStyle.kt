package dev.nanoai.mobile.services

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.view.Gravity
import android.widget.TextView

/**
 * NanoOverlayStyle — Tokens de diseño Material Expressive 3 Glass para el overlay nativo.
 *
 * QUÉ: Paleta de colores idéntica a Búho AI Hub con degradados esmeralda y aro cyan.
 * CÓMO: object Kotlin singleton; dp() convierte dp→px en tiempo de ejecución.
 * POR QUÉ: Permite que el overlay nativo sobre otras apps sea visualmente idéntico (SOLID).
 */
internal object NanoOverlayStyle {
    val bgGlass         = Color.argb(240, 9, 13, 22)     // #F0090D16 — fondo Glass profundo
    val bgInput         = Color.argb(220, 20, 28, 44)    // #DC141C2C — campo de entrada
    val borderGlass     = Color.argb(60, 255, 255, 255)  // borde translúcido
    val onSurface       = Color.rgb(240, 245, 255)       // texto blanco principal
    val onSurfaceMuted  = Color.argb(160, 200, 215, 235) // texto secundario / hint
    val emerald         = Color.rgb(16, 185, 129)        // #10B981 — verde esmeralda
    val cyanGlow        = Color.rgb(56, 189, 248)        // #38BDF8 — aro orbital
    val amber           = Color.rgb(245, 158, 11)        // #F59E0B — automatización

    fun dp(ctx: Context, n: Int): Int =
        (ctx.resources.displayMetrics.density * n + 0.5f).toInt()

    /** Tarjeta Glass con esquinas de 28dp y borde translúcido. */
    fun glassCard(ctx: Context, radiusDp: Int = 28): GradientDrawable =
        GradientDrawable().apply {
            setColor(bgGlass)
            cornerRadius = dp(ctx, radiusDp).toFloat()
            setStroke(dp(ctx, 1), borderGlass)
        }

    /** Campo de entrada redondeado con borde sutil. */
    fun inputCard(ctx: Context): GradientDrawable =
        GradientDrawable().apply {
            setColor(bgInput)
            cornerRadius = dp(ctx, 16).toFloat()
            setStroke(dp(ctx, 1), Color.argb(40, 255, 255, 255))
        }

    /** Chip de herramienta con color activo o fondo oscuro. */
    fun chip(ctx: Context, active: Boolean, activeColor: Int = emerald): GradientDrawable =
        GradientDrawable().apply {
            setColor(if (active) Color.argb(55, Color.red(activeColor), Color.green(activeColor), Color.blue(activeColor)) else Color.argb(25, 255, 255, 255))
            cornerRadius = dp(ctx, 12).toFloat()
            setStroke(dp(ctx, if (active) 1 else 1), if (active) activeColor else Color.argb(30, 255, 255, 255))
        }

    /** Botón principal con degradado esmeralda idéntico a Flutter. */
    fun actionButton(ctx: Context): GradientDrawable =
        GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT,
            intArrayOf(Color.rgb(5, 150, 105), emerald, Color.rgb(52, 211, 153))).apply {
            cornerRadius = dp(ctx, 16).toFloat()
        }

    /** Botón circular de cierre o mic. */
    fun circleBtn(ctx: Context): GradientDrawable =
        GradientDrawable().apply {
            setColor(Color.argb(35, 255, 255, 255))
            shape = GradientDrawable.OVAL
        }

    fun ripple(ctx: Context, bg: GradientDrawable): RippleDrawable =
        RippleDrawable(android.content.res.ColorStateList.valueOf(Color.argb(70, 16, 185, 129)), bg, null)

    fun text(ctx: Context, text: String, sizeSp: Float = 13f,
             color: Int = onSurface, bold: Boolean = false): TextView =
        TextView(ctx).apply {
            this.text = text; textSize = sizeSp; setTextColor(color)
            gravity = Gravity.CENTER_VERTICAL
            typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
        }
}
