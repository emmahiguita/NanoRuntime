package dev.nanoai.mobile.services

import android.graphics.*
import android.graphics.drawable.Drawable

/** Lente circular del búho sobre otras apps. Refleja los tokens de Nano sin
 * otro motor Flutter, captura de pantalla ni reloj de animación adicional. */
internal class NanoOwlGlassDrawable : Drawable() {
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val lens = RectF()
    private var fill: Shader? = null
    private var rim: Shader? = null
    private var glint: Shader? = null
    private var radius = 0f

    /** Recalcula los gradientes únicamente cuando cambia el tamaño. El búho
     * conserva sus sprites y su respiración independientes dentro de la lente. */
    override fun onBoundsChange(bounds: Rect) {
        val inset = bounds.width() * .035f
        lens.set(bounds.left + inset, bounds.top + inset,
            bounds.right - inset, bounds.bottom - inset)
        radius = minOf(lens.width(), lens.height()) / 2f
        if (radius <= 0f) return
        val base = NanoOverlayStyle.bgGlass
        val alpha = if (NanoOverlayStyle.glassEnabled)
            (NanoOverlayStyle.glassAlpha * 0.70f).toInt().coerceIn(35, 180) else 255
        val tint = Color.argb(alpha, Color.red(base), Color.green(base), Color.blue(base))
        fill = RadialGradient(lens.centerX(), lens.centerY(), radius,
            intArrayOf(tint, tint, Color.argb(if (alpha == 255) 255 else (alpha * 0.85f).toInt(),
                Color.red(base), Color.green(base), Color.blue(base))),
            floatArrayOf(0f, .68f, 1f), Shader.TileMode.CLAMP)
        rim = LinearGradient(lens.left, lens.top, lens.right, lens.bottom,
            intArrayOf(Color.argb(235, 255, 255, 255),
                NanoOverlayStyle.borderGlass, Color.argb(170, 210, 232, 242)),
            floatArrayOf(0f, .52f, 1f), Shader.TileMode.CLAMP)
        glint = RadialGradient(lens.centerX() - radius * .28f,
            lens.centerY() - radius * .62f, radius * .76f,
            Color.argb(155, 255, 255, 255), Color.TRANSPARENT, Shader.TileMode.CLAMP)
    }

    /** Pinta cristal y borde; no difumina el personaje ni redecodifica imágenes. */
    override fun draw(canvas: Canvas) {
        if (radius <= 0f) return
        paint.style = Paint.Style.FILL
        paint.shader = fill
        canvas.drawCircle(lens.centerX(), lens.centerY(), radius, paint)
        paint.shader = glint
        canvas.drawCircle(lens.centerX(), lens.centerY(), radius, paint)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = (radius * .035f).coerceAtLeast(1f)
        paint.shader = rim
        canvas.drawCircle(lens.centerX(), lens.centerY(), radius, paint)
        paint.shader = null
    }

    /** Permite la atenuación del framework sin cambiar preferencias globales. */
    override fun setAlpha(alpha: Int) { paint.alpha = alpha; invalidateSelf() }
    override fun setColorFilter(filter: ColorFilter?) { paint.colorFilter = filter; invalidateSelf() }
    @Deprecated("Drawable translucent")
    override fun getOpacity(): Int = PixelFormat.TRANSLUCENT
}
