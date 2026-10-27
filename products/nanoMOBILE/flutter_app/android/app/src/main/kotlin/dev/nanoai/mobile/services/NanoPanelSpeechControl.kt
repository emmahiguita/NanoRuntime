package dev.nanoai.mobile.services

import android.content.Context
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView

/** Lectura opcional del resultado mediante el puente de Nano, sin otro motor.
 * Posee solo las lecturas iniciadas aquí y cancela una vez al abandonar el panel. */
internal class NanoPanelSpeechControl(
    context: Context,
    private val onAction: (String, String, String) -> Unit,
) : LinearLayout(context) {
    private val button = TextView(context)
    private val status = TextView(context)
    private var content = ""
    private var ownsSpeech = false

    init {
        orientation = VERTICAL
        setPadding(dp(16), 0, dp(16), dp(4))
        visibility = GONE
        button.apply {
            textSize = 12f
            gravity = Gravity.CENTER
            minHeight = dp(48)
            setPadding(dp(8), dp(6), dp(8), dp(6))
            setTextColor(NanoOverlayStyle.onSurface)
            background = NanoOverlayStyle.inputCard(context)
            isClickable = true
            setOnClickListener { toggle() }
        }
        addView(button, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
        status.apply {
            textSize = 11f
            setTextColor(NanoOverlayStyle.onSurfaceMuted)
            setPadding(dp(4), dp(6), dp(4), 0)
            accessibilityLiveRegion = ACCESSIBILITY_LIVE_REGION_POLITE
            visibility = GONE
        }
        addView(status)
        updateLabel()
    }

    /** Reutiliza la densidad del panel y conserva el objetivo táctil de 48 dp. */
    private fun dp(value: Int) = NanoOverlayStyle.dp(context, value)

    /** Prepara el texto visible; recibir una respuesta nunca inicia voz. */
    fun prepare(text: String) {
        stop()
        content = text
        status.visibility = GONE
        visibility = if (text.isBlank()) GONE else VISIBLE
    }

    /** Oculta la lectura al comenzar otra consulta y libera la anterior. */
    fun clear() {
        stop()
        content = ""
        visibility = GONE
    }

    /** Solo una pulsación pide leer; la aceptación no certifica su finalización. */
    private fun toggle() {
        if (ownsSpeech) {
            stop()
        } else if (content.isNotBlank()) {
            ownsSpeech = true
            status.visibility = GONE
            updateLabel()
            onAction("Speak", "nano", content)
        }
    }

    /** Limpia propiedad antes de pedir detener para evitar reenvíos al desmontar. */
    fun stop() {
        if (!ownsSpeech) return
        ownsSpeech = false
        updateLabel()
        onAction("StopSpeech", "nano", "")
    }

    /** Un fallo de voz se muestra aparte y conserva el resultado original. */
    fun showFailure(message: String) {
        ownsSpeech = false
        updateLabel()
        status.text = message
        status.visibility = VISIBLE
    }

    /** Mantiene detener disponible porque el puente no publica fin de audio. */
    private fun updateLabel() {
        button.text = if (ownsSpeech) "Detener lectura" else "Leer respuesta"
        button.contentDescription = button.text
    }

    /** Cancelar o cerrar el panel no deja una lectura iniciada por él. */
    override fun onDetachedFromWindow() {
        stop()
        super.onDetachedFromWindow()
    }
}
