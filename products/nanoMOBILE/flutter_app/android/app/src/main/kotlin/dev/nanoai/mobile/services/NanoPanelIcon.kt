package dev.nanoai.mobile.services

import android.graphics.*
import android.graphics.drawable.Drawable

/** Símbolos lineales del panel, independientes del tamaño y sin recursos animados.
 * Los trazos pertenecen al diseño; no ejecutan acciones ni sustituyen al búho. */
internal class NanoPanelIcon(private val kind: String, color: Int) : Drawable() {
    private val pen = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        this.color = color
        style = Paint.Style.STROKE
        strokeWidth = 1.7f
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }

    /** Dibuja en coordenadas de 24 unidades para conservar nitidez al escalar. */
    override fun draw(canvas: Canvas) {
        val save = canvas.save()
        canvas.translate(bounds.left.toFloat(), bounds.top.toFloat())
        canvas.scale(bounds.width() / 24f, bounds.height() / 24f)
        fun line(vararg points: Float) {
            val p = Path().apply {
                moveTo(points[0], points[1])
                for (i in 2 until points.size step 2) lineTo(points[i], points[i + 1])
            }
            canvas.drawPath(p, pen)
        }
        when (kind) {
            "Chat" -> {
                canvas.drawRoundRect(RectF(3f, 3f, 21f, 17f), 4f, 4f, pen)
                line(3f, 14f, 3f, 21f, 8f, 17f)
                line(7f, 9f, 17f, 9f)
            }
            "Resumir" -> {
                canvas.drawRoundRect(RectF(5f, 2f, 19f, 22f), 2f, 2f, pen)
                for (y in listOf(7f, 12f, 17f)) line(9f, y, 15f, y)
            }
            "Auto" -> line(5f, 3f, 19f, 13f, 12f, 14f, 10f, 21f, 5f, 3f)
            "Media" -> {
                line(12f, 3f, 12f, 16f); line(7f, 11f, 12f, 16f, 17f, 11f)
                line(3f, 17f, 3f, 21f, 21f, 21f, 21f, 17f)
            }
            "history" -> {
                canvas.drawArc(RectF(3f, 3f, 21f, 21f), -110f, 295f, false, pen)
                line(3f, 3f, 3f, 9f, 9f, 9f); line(12f, 7f, 12f, 12f, 16f, 14f)
            }
            "close" -> { line(6f, 6f, 18f, 18f); line(18f, 6f, 6f, 18f) }
            "chevron" -> line(6f, 9f, 12f, 15f, 18f, 9f)
            "check" -> line(5f, 12f, 10f, 17f, 20f, 6f)
        }
        canvas.restoreToCount(save)
    }
    override fun setAlpha(alpha: Int) { pen.alpha = alpha; invalidateSelf() }
    override fun setColorFilter(filter: ColorFilter?) { pen.colorFilter = filter; invalidateSelf() }
    @Deprecated("Drawable compatibility")
    override fun getOpacity(): Int = PixelFormat.TRANSLUCENT
}
