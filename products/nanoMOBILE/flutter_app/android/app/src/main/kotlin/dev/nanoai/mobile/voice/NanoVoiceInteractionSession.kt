package dev.nanoai.mobile.voice

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.service.voice.VoiceInteractionSession
import android.view.Gravity
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView

/**
 * A16 — sesión activa de asistente. Recibe la activación del usuario (hotword o
 * botón) y, en la fundación, solo confirma el inicio de la sesión. El STT real
 * lo dispara la app (canal `com.nanoai/speech`), no este servicio ligero.
 *
 * ROLE-01 fix: la sesión SIEMPRE puede cerrarse. ColorOS no garantiza que el
 * botón atrás termine una VoiceInteractionSession, así que la UI mínima lleva
 * un botón explícito que llama a [finish]. Sin esto la sesión queda pegada en
 * pantalla sin forma de salir.
 */
class NanoVoiceInteractionSession(context: Context) : VoiceInteractionSession(context) {

    private val appContext = context

    override fun onCreate() {
        super.onCreate()
        activeSessions++
    }

    override fun onDestroy() {
        super.onDestroy()
        if (activeSessions > 0) activeSessions--
    }

    override fun onShow(args: Bundle?, showFlags: Int) {
        super.onShow(args, showFlags)
        // Hotword detectado → sesión activa + UI mínima con cierre explícito.
        setContentView(buildView())
    }

    override fun onHide() {
        super.onHide()
    }

    /** UI mínima de la sesión: título, estado honesto y cierre explícito. */
    private fun buildView(): View {
        return LinearLayout(appContext).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#E60B0F1A"))
            setPadding(dp(28), dp(28), dp(28), dp(28))
            addView(TextView(appContext).apply {
                text = "🦉 Nano asistente"
                textSize = 22f
                setTextColor(Color.WHITE)
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, dp(12))
            })
            addView(TextView(appContext).apply {
                text = "Sesión de voz activa.\nEl micrófono lo gestiona la app Nano."
                textSize = 14f
                setTextColor(Color.parseColor("#B3FFFFFF"))
                gravity = Gravity.CENTER
                setPadding(0, 0, 0, dp(24))
            })
            addView(TextView(appContext).apply {
                text = "Cerrar asistencia"
                textSize = 16f
                setTextColor(Color.parseColor("#0B1E3A"))
                gravity = Gravity.CENTER
                setPadding(dp(20), dp(12), dp(20), dp(12))
                background = GradientDrawable().apply {
                    cornerRadius = dp(24).toFloat()
                    setColor(Color.WHITE)
                }
                setOnClickListener { finish() }
            })
        }
    }

    private fun dp(value: Int): Int =
        (value * appContext.resources.displayMetrics.density).toInt()

    companion object {
        /** Sesiones vivas (creadas y no destruidas). Contador defensivo:
         *  el sistema puede solaparlas (re-show). */
        @Volatile
        private var activeSessions = 0

        /** Factual: ¿hay una sesión de asistente activa AHORA? (ROLE-01 lo
         *  expone para llenar el AssistContext del SystemContextProvider). */
        val isSessionActive: Boolean get() = activeSessions > 0
    }
}
