package dev.nanoai.mobile.services

import android.content.Context
import android.content.res.ColorStateList
import android.text.Editable
import android.text.InputType
import android.text.TextWatcher
import android.view.Gravity
import android.view.View
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.ImageButton
import android.widget.LinearLayout
import android.widget.TextView

/** Editor compacto con dictado Android real. Conserva el borrador y muestra
 * permisos, errores y cancelación sin sustituir el resultado de una consulta. */
internal class NanoPanelVoiceInput(
    context: Context,
    sendButton: TextView,
    onSubmit: () -> Unit,
    private val onChanged: () -> Unit,
    onAttach: (View) -> Unit,
) : LinearLayout(context) {
    val field = EditText(context)
    private val voice = NanoVoiceCapture(context)
    private val microphone = ImageButton(context)
    private val attach = TextView(context)
    private val status = TextView(context)
    var capturing = false
        private set
    private var busy = false

    init {
        orientation = VERTICAL
        val row = LinearLayout(context).apply {
            gravity = Gravity.CENTER_VERTICAL
            background = NanoOverlayStyle.inputCard(context)
            setPadding(dp(4), dp(4), dp(5), dp(4))
        }
        attach.apply {
            text = "+"
            textSize = 24f
            gravity = Gravity.CENTER
            setTextColor(NanoOverlayStyle.onSurface)
            contentDescription = "Adjuntar desde cámara, fotos o archivos"
            isClickable = true
            setOnClickListener { onAttach(this) }
        }
        row.addView(attach, LayoutParams(dp(48), dp(48)))
        microphone.apply {
            background = null
            imageTintList = ColorStateList.valueOf(NanoOverlayStyle.onSurface)
            setPadding(dp(12), dp(12), dp(12), dp(12))
            setOnClickListener { toggleVoice() }
        }
        row.addView(microphone, LayoutParams(dp(48), dp(48)))
        field.apply {
            setHintTextColor(NanoOverlayStyle.onSurfaceMuted)
            setTextColor(NanoOverlayStyle.onSurface)
            textSize = 13.5f
            background = null
            maxLines = 3
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            imeOptions = EditorInfo.IME_ACTION_SEND
            setOnEditorActionListener { _, id, _ ->
                if (id == EditorInfo.IME_ACTION_SEND) { onSubmit(); true } else false
            }
            addTextChangedListener(object : TextWatcher {
                /** No altera el borrador antes de editarlo. */
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                /** Actualiza la acción principal con el texto realmente preparado. */
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) { onChanged() }
                /** No normaliza ni envía texto al finalizar una edición. */
                override fun afterTextChanged(s: Editable?) {}
            })
        }
        row.addView(field, LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))
        row.addView(sendButton, LayoutParams(dp(48), dp(48)))
        addView(row, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
        status.apply {
            textSize = 11f
            setTextColor(NanoOverlayStyle.onSurfaceMuted)
            setPadding(dp(4), dp(6), dp(4), 0)
            accessibilityLiveRegion = ACCESSIBILITY_LIVE_REGION_POLITE
            visibility = GONE
        }
        addView(status)
        updateVoiceState(false)
    }

    /** Conserva métricas del tema sin dimensiones absolutas de pantalla. */
    private fun dp(value: Int) = NanoOverlayStyle.dp(context, value)

    /** Una pulsación inicia dictado; otra cancela sin consumir el borrador. */
    private fun toggleVoice() {
        if (busy) return
        if (capturing) {
            voice.stop()
            showStatus("Dictado cancelado. El borrador se conserva.")
        } else voice.start({ dictated ->
            val draft = field.text.toString()
            field.setText(if (draft.isBlank()) dictated else "$draft $dictated")
            field.setSelection(field.length())
        }, ::showStatus, ::updateVoiceState)
    }

    /** Expone estados reales; el reconocedor no controla la acción de enviar. */
    private fun updateVoiceState(listening: Boolean) {
        capturing = listening
        microphone.setImageResource(if (listening) android.R.drawable.ic_menu_close_clear_cancel
            else android.R.drawable.ic_btn_speak_now)
        microphone.contentDescription = if (listening) "Cancelar dictado" else "Dictar mensaje"
        field.isEnabled = !busy && !listening
        attach.isEnabled = !busy && !listening
        if (isAttachedToWindow) onChanged()
    }

    /** Hace visibles errores y permisos también para lectores de pantalla. */
    private fun showStatus(message: String) {
        status.text = message
        status.visibility = VISIBLE
    }

    /** Una consulta bloquea el editor y cancela cualquier captura concurrente. */
    fun setBusy(value: Boolean) {
        busy = value
        if (value && capturing) {
            voice.stop()
            showStatus("Dictado cancelado.")
        }
        field.isEnabled = !value && !capturing
        microphone.isEnabled = !value
        attach.isEnabled = !value && !capturing
        microphone.alpha = if (value) .45f else 1f
    }

    /** El cierre del panel no deja audio ni callbacks activos. */
    override fun onDetachedFromWindow() {
        if (capturing) showStatus("Dictado cancelado. El borrador se conserva.")
        voice.stop()
        super.onDetachedFromWindow()
    }
}
