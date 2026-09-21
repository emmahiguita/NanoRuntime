package dev.nanoai.mobile.services

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.view.animation.LinearInterpolator
import android.widget.LinearLayout

/**
 * NanoGlassCapsule — Contenedor con estética Dark Liquid Glass y aura viva.
 *
 * QUÉ HACE: Renderiza la cápsula de vidrio oscuro con reflejos especulares,
 *           borde de neón cian/índigo y un aura cósmica pulsante tipo Gemini.
 * CÓMO FUNCIONA: Dibuja en onDraw capas de gradiente, destellos de luz curva
 *                y una onda de brillo continuo cuando la IA está pensando.
 * POR QUÉ: Otorga sensación física de material vivo y reactivo a toques,
 *          sin depender de recursos pesados ni bitmaps estáticos.
 * CONTROL ZOMBI: El ValueAnimator del aura se cancela en stopAnimations().
 */
class NanoGlassCapsule(context: Context) : LinearLayout(context) {

    private val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val auraPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val specPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE }
    private val rect = RectF()

    private var auraPhase = 0f
    private var isThinking = false
    private var auraAnimator: ValueAnimator? = null

    init {
        setWillNotDraw(false)
        startAura()
    }

    /** Inicia la oscilación continua de luz cósmica para dar sensación de vida */
    private fun startAura() {
        auraAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
            duration = 2600
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.REVERSE
            interpolator = LinearInterpolator()
            addUpdateListener {
                auraPhase = it.animatedValue as Float
                invalidate()
            }
            start()
        }
    }

    /** Activa o desactiva la onda energética de pensamiento de la IA */
    fun setThinking(thinking: Boolean) {
        isThinking = thinking
        invalidate()
    }

    override fun onDraw(canvas: Canvas) {
        val w = width.toFloat()
        val h = height.toFloat()
        val radius = h / 2f
        rect.set(6f, 6f, w - 6f, h - 6f)

        // 1. Aura cósmica exterior pulsante (efecto presencia viva)
        val auraAlpha = if (isThinking) 190 else (50 + (auraPhase * 60)).toInt()
        auraPaint.strokeWidth = 7f
        auraPaint.color = if (isThinking) Color.argb(auraAlpha, 56, 189, 248)
                          else Color.argb(auraAlpha, 14, 165, 233)
        canvas.drawRoundRect(rect, radius, radius, auraPaint)

        // 2. Fondo Dark Liquid Glass (obsidiana con tinte azul profundo)
        bgPaint.shader = LinearGradient(
            0f, 0f, w, h,
            intArrayOf(Color.argb(238, 11, 15, 25), Color.argb(246, 22, 31, 48)),
            null, Shader.TileMode.CLAMP
        )
        canvas.drawRoundRect(rect, radius, radius, bgPaint)

        // 3. Borde de vidrio con degradado cian e iluminación especular
        val strokeColorStart = if (isThinking) Color.rgb(56, 189, 248) else Color.argb(170, 56, 189, 248)
        val strokeColorEnd = Color.argb(110, 129, 140, 248)
        strokePaint.strokeWidth = 2.5f
        strokePaint.shader = LinearGradient(0f, 0f, w, 0f, strokeColorStart, strokeColorEnd, Shader.TileMode.CLAMP)
        canvas.drawRoundRect(rect, radius, radius, strokePaint)

        // 4. Reflejo especular blanco en el arco superior (efecto cristal 3D curvado)
        specPaint.color = Color.argb(55, 255, 255, 255)
        specPaint.strokeWidth = 1.8f
        val specRect = RectF(rect.left + 8f, rect.top + 1.5f, rect.right - 8f, rect.top + radius)
        canvas.drawArc(specRect, 200f, 140f, false, specPaint)

        super.onDraw(canvas)
    }

    /** Limpia animadores para evitar memory leaks o procesos zombi */
    fun stopAnimations() {
        auraAnimator?.cancel()
        auraAnimator = null
    }
}
