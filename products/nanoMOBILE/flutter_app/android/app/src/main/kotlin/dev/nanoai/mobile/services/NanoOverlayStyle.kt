package dev.nanoai.mobile.services

import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.view.Gravity
import android.widget.TextView

/** Tokens del panel Android. Lee la apariencia guardada por Nano al abrir;
 * no cambia preferencias ni mantiene un proceso de sondeo permanente. */
internal object NanoOverlayStyle {
    var bgGlass = Color.argb(230, 18, 18, 18); private set
    var bgInput = Color.argb(42, 255, 255, 255); private set
    var borderGlass = Color.argb(75, 255, 255, 255); private set
    var onSurface = Color.WHITE; private set
    var onSurfaceMuted = Color.rgb(209, 209, 214); private set
    var activeSegment = Color.argb(36, 65, 180, 112); private set
    var accent = Color.rgb(42, 160, 96); private set
    var glassEnabled = true; private set
    var glassBlur = 18; private set
    // La lente usa la misma opacidad resuelta, sin otro ajuste de apariencia.
    val glassAlpha: Int get() = Color.alpha(bgGlass)

    /** Usa las mismas claves persistidas por SettingsRepository de Flutter.
     * Sistema sigue uiMode; Claro y Gris espacial respetan la elección de Nano. */
    fun configure(ctx: Context) {
        val raw = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.nanoai_settings", null)
        val settings = try { org.json.JSONObject(raw ?: "{}") }
            catch (_: org.json.JSONException) { org.json.JSONObject() }
        val systemDark = (ctx.resources.configuration.uiMode and
            android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
            android.content.res.Configuration.UI_MODE_NIGHT_YES
        val mode = settings.optString("themeMode", "Oscuro")
        val spaceGray = mode in setOf("Grisáceo", "Opaco")
        val dark = when (mode) {
            "Claro", "Clásico" -> false
            "Sistema" -> systemDark
            else -> true
        }
        glassEnabled = settings.optBoolean("glassEnabled", true)
        glassBlur = settings.optDouble("glassBlur", 18.0).coerceIn(0.0, 42.0).toInt()
        val density = settings.optDouble("glassOpacity", .70).coerceIn(.05, 1.0)
        // El panel externo no debe aclararse sobre una app blanca. Gris espacial
        // conserva el grafito, mientras Oscuro/Sistema oscuro usan negro neutro.
        val alpha = if (!glassEnabled) 255 else
            if (dark) (214 + density * 30).toInt() else (135 + density * 65).toInt()
        bgGlass = when {
            spaceGray -> Color.argb(alpha, 28, 30, 36)
            dark -> Color.argb(alpha, 18, 18, 18)
            else -> Color.argb(alpha, 246, 249, 247)
        }
        bgInput = if (dark) Color.argb(35, 255, 255, 255) else Color.argb(155, 255, 255, 255)
        borderGlass = if (dark) Color.argb(80, 255, 255, 255) else Color.argb(55, 55, 70, 64)
        onSurface = if (dark) Color.rgb(245, 245, 247) else Color.rgb(25, 30, 28)
        onSurfaceMuted = if (dark) Color.rgb(185, 185, 191) else Color.rgb(85, 96, 90)
        accent = when {
            spaceGray -> Color.rgb(56, 189, 248)
            dark -> Color.rgb(37, 99, 235)
            else -> Color.rgb(24, 125, 74)
        }
        activeSegment = Color.argb(36, Color.red(accent), Color.green(accent), Color.blue(accent))
    }

    fun dp(ctx: Context, n: Int): Int =
        (ctx.resources.displayMetrics.density * n + 0.5f).toInt()

    /** Tarjeta de cristal líquido con esquinas redondeadas y borde cáustico. */
    fun glassCard(ctx: Context, radiusDp: Int = 22): GradientDrawable =
        GradientDrawable().apply {
            setColor(bgGlass)
            cornerRadius = dp(ctx, radiusDp).toFloat()
            setStroke(dp(ctx, 1), borderGlass)
        }

    /** Campo de entrada en cristal líquido. */
    fun inputCard(ctx: Context): GradientDrawable =
        GradientDrawable().apply {
            setColor(bgInput)
            cornerRadius = dp(ctx, 20).toFloat()
            setStroke(dp(ctx, 1), borderGlass)
        }

    /** Segmento de cristal líquido estilo iOS. */
    fun chip(ctx: Context, active: Boolean): GradientDrawable =
        GradientDrawable().apply {
            setColor(if (active) activeSegment else Color.TRANSPARENT)
            cornerRadius = dp(ctx, 8).toFloat()
            if (active) {
                setStroke(dp(ctx, 1), Color.argb(80, 255, 255, 255))
            }
        }

    /** Botón circular de envío Apple blanco puro. */
    fun actionButton(ctx: Context): GradientDrawable =
        GradientDrawable().apply {
            setColor(accent)
            shape = GradientDrawable.OVAL
        }

    /** Botón circular de vidrio suave para acciones de ventana. */
    fun circleBtn(ctx: Context): GradientDrawable =
        GradientDrawable().apply {
            setColor(Color.argb(38, 255, 255, 255))
            shape = GradientDrawable.OVAL
        }

    fun ripple(ctx: Context, bg: GradientDrawable): RippleDrawable =
        RippleDrawable(android.content.res.ColorStateList.valueOf(Color.argb(50, 255, 255, 255)), bg, null)

    fun text(ctx: Context, text: String, sizeSp: Float = 13f,
             color: Int = onSurface, bold: Boolean = false): TextView =
        TextView(ctx).apply {
            this.text = text; textSize = sizeSp; setTextColor(color)
            gravity = Gravity.CENTER_VERTICAL
            typeface = if (bold) Typeface.DEFAULT_BOLD else Typeface.DEFAULT
        }
}
