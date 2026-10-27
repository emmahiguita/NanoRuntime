package dev.nanoai.mobile.services

import android.content.Context
import android.graphics.Color
import android.view.Gravity
import android.widget.*

/** Un selector, una explicación y un editor. El menú prepara el contexto;
 * únicamente la acción principal llama al callback del servicio existente. */
internal class NanoGeminiInputBar(
    context: Context,
    private val onActionTriggered: (String, String, String) -> Unit,
    initialTool: String = "Chat",
    initialDraft: String = "",
    private val onDraftChanged: (String) -> Unit = {},
    private val onToolSelected: (String) -> Unit = {},
) : LinearLayout(context) {
    /** Comparte las métricas del panel con el editor de dictado. */
    private fun dp(n: Int) = NanoOverlayStyle.dp(context, n)
    private var activeTool = NanoPanelTools.find(initialTool).key
    private var busy = false
    private var canStop = false
    private val sendButton = TextView(context)
    private val editor: NanoPanelVoiceInput = NanoPanelVoiceInput(context, sendButton, { submit() },
        { updateEnabled(); onDraftChanged(inputField.text.toString()) }, { showAttachments(it) })
    private val inputField: EditText get() = editor.field
    private val selector = TextView(context)
    private val description = TextView(context)
    private val picker = NanoPanelToolPicker(context, { activeTool }, { selectTool(it) })
    private val attachmentPicker = NanoPanelToolPicker(context, { "" },
        { onActionTriggered(it, "nano", "") }, NanoPanelAttachments.options)

    init {
        orientation = VERTICAL
        setPadding(dp(16), dp(2), dp(16), dp(12))
        selector.apply {
            textSize = 14f
            gravity = Gravity.CENTER_VERTICAL
            setTextColor(NanoOverlayStyle.onSurface)
            setPadding(dp(14), dp(12), dp(14), dp(12))
            minHeight = dp(48)
            background = NanoOverlayStyle.inputCard(context)
            isClickable = true
            setOnClickListener { if (!busy) picker.show(this) }
        }
        addView(selector, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
        description.apply {
            textSize = 11.5f
            setTextColor(NanoOverlayStyle.onSurfaceMuted)
            setPadding(dp(4), dp(8), dp(4), dp(12))
        }
        addView(description)
        configureSendButton()
        addView(editor, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
        addView(NanoOverlayStyle.text(context,
            "Seleccionar prepara. Ejecutar inicia la acción.", 10.5f,
            color = NanoOverlayStyle.onSurfaceMuted).apply {
            gravity = Gravity.CENTER
            setPadding(0, dp(8), 0, 0)
        })
        inputField.setText(initialDraft)
        selectTool(activeTool, notify = false)
    }

    /** Cambia la presentación y conserva el borrador al seleccionar otro modo. */
    private fun selectTool(key: String, notify: Boolean = true) {
        activeTool = key
        val tool = NanoPanelTools.find(key)
        selector.text = tool.label
        selector.setCompoundDrawables(null, null, null, null)
        if (key == "WhatsApp") selector.installWhatsAppToolIcon(context, inline = true)
        else {
            val icon = NanoPanelIcon(key, NanoOverlayStyle.onSurfaceMuted)
            icon.setBounds(0, 0, dp(22), dp(22))
            selector.setCompoundDrawables(icon, null, null, null)
            selector.compoundDrawablePadding = dp(10)
        }
        val chevron = NanoPanelIcon("chevron", NanoOverlayStyle.onSurfaceMuted)
        chevron.setBounds(0, 0, dp(20), dp(20))
        selector.setCompoundDrawables(selector.compoundDrawables[0], null, chevron, null)
        selector.contentDescription = "Funciones de Búho AI: ${tool.label}"
        description.text = tool.description
        inputField.hint = when (key) {
            "WhatsApp" -> "Abre el chat de Emm…"
            "Resumir" -> "Pulsa leer para obtener texto accesible"
            "Media" -> "Pega un enlace…"
            else -> "Escribe una instrucción…"
        }
        sendButton.contentDescription = when (key) {
            "Chat" -> "Consultar"
            "Resumir" -> "Leer pantalla"
            "Media" -> "Buscar archivos"
            else -> "Ejecutar"
        }
        updateEnabled()
        if (notify) onToolSelected(key)
    }

    /** Solo la acción explícita envía el borrador del editor, incluido el dictado. */
    private fun configureSendButton() {
        sendButton.apply {
            text = "↑"
            textSize = 20f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            background = NanoOverlayStyle.actionButton(context)
            isClickable = true
            setOnClickListener { submit() }
        }
    }

    /** El mismo botón solicita detener el turno propio; no promete revertir
     * una acción externa. No añade un segundo control de envío. */
    fun setBusy(value: Boolean, allowStop: Boolean = false) {
        busy = value
        canStop = value && allowStop
        selector.isEnabled = !value
        editor.setBusy(value)
        sendButton.text = if (canStop) "■" else if (value) "…" else "↑"
        if (canStop) sendButton.contentDescription = "Solicitar detener tarea"
        else sendButton.contentDescription = "Ejecutar instrucción"
        updateEnabled()
    }

    /** Durante consulta solo permite solicitar detener si el dueño lo admite;
     * dictar o seleccionar un archivo nunca habilita un segundo envío. */
    private fun updateEnabled() {
        selector.isEnabled = !busy && !editor.capturing
        sendButton.isEnabled = canStop || (!busy && !editor.capturing &&
            (inputField.text.isNotBlank() || activeTool in listOf("Resumir", "Media")))
        sendButton.alpha = if (sendButton.isEnabled) 1f else .45f
    }

    /** El + prepara un adjunto sin cambiar herramienta ni ejecutar el borrador. */
    private fun showAttachments(anchor: android.view.View) {
        if (busy || editor.capturing) return
        picker.dismiss()
        attachmentPicker.show(anchor)
    }

    /** Entrega una copia sin borrar: ocupado, error o resultado incierto deben
     * conservar la instrucción y su destinatario para revisión del usuario. */
    private fun submit() {
        if (!sendButton.isEnabled) return
        if (busy) { onActionTriggered("Cancel", "nano", ""); return }
        val query = inputField.text.toString().trim()
        onActionTriggered(activeTool, "nano", query)
    }

    /** El editor hijo libera voz; el propietario del menú cierra su ventana. */
    override fun onDetachedFromWindow() {
        picker.dismiss()
        attachmentPicker.dismiss()
        super.onDetachedFromWindow()
    }
}
