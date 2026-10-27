package dev.nanoai.mobile.services

import android.os.Handler
import android.os.Looper
import android.widget.ImageView
import dev.nanoai.mobile.R
import kotlin.random.Random
import kotlin.math.sin
import android.os.SystemClock

/**
 * NanoOwlAnimator — Animación del búho nativo en el overlay del sistema.
 *
 * QUÉ: Intercambio de frames (poses) + movimiento de respiración continuo.
 * CÓMO: Respiración a 15 Hz y parpadeos; se detiene con la pantalla o panel oculto.
 *       Handler en main looper ejecuta la secuencia de parpadeo aleatorio.
 * POR QUÉ: La articulación 3D real (plumas, ojos independientes) requiere rig Rive.
 *          Esta implementación usa sprites PNG — es honesta y funcional.
 * ZOMBI: running=false en stop() previene callbacks huérfanos del Handler.
 */
internal class NanoOwlAnimator(private val owl: ImageView) {
    private val handler = Handler(Looper.getMainLooper())
    private var running = false
    private var pose = R.drawable.nano_owl_idle

    // Secuencia de parpadeo: medio → cerrado → medio (frames 85ms c/u)
    private val blinkFrames = intArrayOf(
        R.drawable.nano_owl_blink_half,
        R.drawable.nano_owl_sleep,
        R.drawable.nano_owl_blink_half,
    )
    private var blinkStep = 0

    private val blink = object : Runnable {
        override fun run() {
            if (!running) return
            if (blinkStep < blinkFrames.size) {
                owl.setImageResource(blinkFrames[blinkStep++])
                handler.postDelayed(this, 85)
            } else {
                // Fin del parpadeo — restaurar pose y programar el siguiente.
                blinkStep = 0
                owl.setImageResource(pose)
                handler.postDelayed(this, (2800 + Random.nextInt(2400)).toLong())
            }
        }
    }

    private var startedAt = 0L
    // Solo transforma el ImageView: no recarga PNG ni recompone el panel.
    private val breathe = object : Runnable {
        override fun run() {
            if (!running) return
            val phase = (SystemClock.uptimeMillis() - startedAt) / 3200.0 * Math.PI * 2
            val wave = sin(phase).toFloat()
            owl.translationY = wave * owl.resources.displayMetrics.density * 1.8f
            owl.scaleX = 1f + wave * .012f
            owl.scaleY = 1f + wave * .012f
            handler.postDelayed(this, 66)
        }
    }

    fun start() {
        if (running) return
        running = true
        startedAt = SystemClock.uptimeMillis()
        handler.post(breathe)
        handler.postDelayed(blink, 2800)
    }

    /** Cambia la pose según el estado del asistente (no interrumpe el parpadeo). */
    fun mood(state: String) {
        pose = when (state) {
            "welcome", "greeting"                -> R.drawable.nano_owl_welcome
            "thinking", "comparing", "debating" -> R.drawable.nano_owl_think
            "listening"                          -> R.drawable.nano_owl_listening
            "success"                            -> R.drawable.nano_owl_happy
            "drowsy"                             -> R.drawable.nano_owl_drowsy
            "sleep"                              -> R.drawable.nano_owl_sleep
            "error"                              -> R.drawable.nano_owl_surprised
            else                                 -> R.drawable.nano_owl_idle
        }
        if (blinkStep == 0) owl.setImageResource(pose)
    }

    /** Detener todas las animaciones y limpiar callbacks — sin zombis. */
    fun stop() {
        running = false
        handler.removeCallbacks(blink)
        handler.removeCallbacks(breathe)
        blinkStep = 0
        owl.setImageResource(pose)
        owl.scaleX = 1f; owl.scaleY = 1f; owl.translationY = 0f
    }
}
