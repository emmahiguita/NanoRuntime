package dev.nanoai.mobile.services

import android.content.Context
import android.graphics.Color
import android.text.InputType
import android.view.Gravity
import android.view.inputmethod.EditorInfo
import android.widget.EditText
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.TextView

/**
 * NanoGeminiInputBar — Barra de herramientas, proveedores y campo de entrada estilo Gemini.
 *
 * QUÉ: Proporciona selector de herramientas (Web, Auto, Resumir, Media), selector
 *      de proveedores (ChatGPT, DeepSeek, Gemini, Claude) y caja de texto con botón.
 * CÓMO: Chips táctiles con feedback visual activo, EditText con fondo M3 y botón esmeralda.
 * POR QUÉ: Permite interactuar con la IA y descargar multimedia directamente sobre la app activa.
 * SOLID-S: Única responsabilidad: capturar modo, proveedor y prompt del usuario.
 */
internal class NanoGeminiInputBar(
    context: Context,
    private val onActionTriggered: (tool: String, provider: String, prompt: String) -> Unit,
) : LinearLayout(context) {

    private fun dp(n: Int) = NanoOverlayStyle.dp(context, n)

    private var activeTool = "Web AI"
    private var activeProvider = "ChatGPT"

    private val inputField = EditText(context)
    private val toolChips = mutableListOf<TextView>()
    private val providerChips = mutableListOf<TextView>()

    init {
        orientation = VERTICAL
        setPadding(dp(16), dp(4), dp(16), dp(12))

        // 1. Fila de herramientas: Web AI, Auto, Resumir, Media
        addView(createToolsRow())

        // 2. Fila de proveedores IA
        addView(createProvidersRow())

        // 3. Campo de texto + botón de envío con degradado esmeralda
        addView(createInputBox(), LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(8)
        })
    }

    private fun createToolsRow(): HorizontalScrollView = HorizontalScrollView(context).apply {
        isHorizontalScrollBarEnabled = false
        val row = LinearLayout(context).apply { orientation = HORIZONTAL }
        val tools = listOf("🌐 Web AI" to "Web AI", "⚡ Auto" to "Auto", "📄 Resumir" to "Resumir", "📥 Media" to "Media")

        tools.forEach { (label, key) ->
            val chip = TextView(context).apply {
                text = label; textSize = 11f; setTextColor(NanoOverlayStyle.onSurface)
                setPadding(dp(10), dp(5), dp(10), dp(5))
                background = NanoOverlayStyle.chip(context, active = (key == activeTool))
                isClickable = true
                setOnClickListener { selectTool(key) }
            }
            toolChips.add(chip)
            row.addView(chip, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply {
                rightMargin = dp(6)
            })
        }
        addView(row)
    }

    private fun createProvidersRow(): HorizontalScrollView = HorizontalScrollView(context).apply {
        isHorizontalScrollBarEnabled = false
        val row = LinearLayout(context).apply { orientation = HORIZONTAL }
        val providers = listOf("ChatGPT", "DeepSeek", "Gemini", "Claude")

        providers.forEach { name ->
            val chip = TextView(context).apply {
                text = name; textSize = 11f
                setTextColor(if (name == activeProvider) NanoOverlayStyle.emerald else NanoOverlayStyle.onSurfaceMuted)
                setPadding(dp(8), dp(4), dp(8), dp(4))
                isClickable = true
                setOnClickListener { selectProvider(name) }
            }
            providerChips.add(chip)
            row.addView(chip, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT).apply {
                rightMargin = dp(4)
            })
        }
        addView(row)
    }

    private fun createInputBox(): LinearLayout = LinearLayout(context).apply {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        background = NanoOverlayStyle.inputCard(context)
        setPadding(dp(12), dp(4), dp(6), dp(4))

        inputField.apply {
            hint = "Pregunta a Búho sobre esta pantalla…"
            setHintTextColor(NanoOverlayStyle.onSurfaceMuted)
            setTextColor(NanoOverlayStyle.onSurface)
            textSize = 13f
            background = null
            maxLines = 3
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_SENTENCES
            imeOptions = EditorInfo.IME_ACTION_SEND
            setOnEditorActionListener { _, actionId, _ ->
                if (actionId == EditorInfo.IME_ACTION_SEND) { submit(); true } else false
            }
        }
        addView(inputField, LayoutParams(0, LayoutParams.WRAP_CONTENT, 1f))

        val sendBtn = TextView(context).apply {
            text = "✦"
            textSize = 16f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            background = NanoOverlayStyle.actionButton(context)
            isClickable = true
            setOnClickListener { submit() }
        }
        addView(sendBtn, LayoutParams(dp(36), dp(36)))
    }

    private fun selectTool(key: String) {
        activeTool = key
        val tools = listOf("Web AI", "Auto", "Resumir", "Media")
        toolChips.forEachIndexed { i, chip ->
            chip.background = NanoOverlayStyle.chip(context, active = (tools.getOrNull(i) == activeTool))
        }
        // Si el usuario toca "Resumir" o "Media", ejecuta inmediatamente la acción contextual
        if (key == "Resumir" || key == "Media") {
            onActionTriggered(activeTool, activeProvider, inputField.text.toString().trim())
        }
    }

    private fun selectProvider(name: String) {
        activeProvider = name
        val providers = listOf("ChatGPT", "DeepSeek", "Gemini", "Claude")
        providerChips.forEachIndexed { i, chip ->
            val isCurrent = providers.getOrNull(i) == activeProvider
            chip.setTextColor(if (isCurrent) NanoOverlayStyle.emerald else NanoOverlayStyle.onSurfaceMuted)
        }
    }

    private fun submit() {
        val query = inputField.text.toString().trim()
        onActionTriggered(activeTool, activeProvider, query)
        inputField.text.clear()
    }
}
