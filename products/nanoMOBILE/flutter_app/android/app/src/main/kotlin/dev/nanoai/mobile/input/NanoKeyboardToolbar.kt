package dev.nanoai.mobile.input

import android.content.Context
import android.graphics.Typeface
import android.view.Gravity
import android.view.View
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import dev.nanoai.mobile.R

/**
 * QUÉ HACE: Barra superior inteligente con Búho Nano, sugerencias y herramientas compactas.
 * POR QUÉ EXISTE: Descongestiona el teclado, unifica predicciones reales y acceso a Nano Local.
 */
internal class NanoKeyboardToolbar(
    context: Context,
    private val service: NanoInputMethodService,
    private val onSuggestionSelected: (String) -> Unit,
    private val onVoiceRequested: () -> Unit,
    private val onNanoActionRequested: (NanoLocalAssistant.Action) -> Unit,
) : LinearLayout(context) {

    enum class BarMode { SUGGESTIONS, TOOLS, NANO_LOCAL, STATUS }

    private var currentMode = BarMode.SUGGESTIONS
    private lateinit var centerContainer: LinearLayout
    private lateinit var owlFaceView: ImageView
    private var suggestions = listOf<String>()

    init {
        orientation = HORIZONTAL
        gravity = Gravity.CENTER_VERTICAL
        val density = context.resources.displayMetrics.density
        val padH = (8 * density).toInt()
        setPadding(padH, 0, padH, 0)
        applyTheme()
        buildViews(density)
    }

    private fun applyTheme() {
        val palette = NanoKeyboardTheme.getPalette(context)
        setBackgroundColor(palette.toolbarBackground)
    }

    private fun buildViews(density: Float) {
        val palette = NanoKeyboardTheme.getPalette(context)

        // 1. Rostro oficial del Búho Nano
        val owlSize = (28 * density).toInt()
        owlFaceView = ImageView(context).apply {
            setImageResource(R.drawable.nano_owl_idle)
            layoutParams = LayoutParams(owlSize, owlSize).apply { rightMargin = (8 * density).toInt() }
            contentDescription = "Asistente Nano Local"
            setOnClickListener {
                toggleNanoLocalMode()
            }
        }
        addView(owlFaceView)

        // 2. Contenedor central dinámico (Sugerencias / Herramientas / Nano Local)
        centerContainer = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LayoutParams(0, LayoutParams.MATCH_PARENT, 1.0f)
        }
        addView(centerContainer)

        // 3. Botones rápidos de la derecha: Micrófono y Menú de herramientas
        val micBtn = createQuickIcon("🎤", density, palette) { onVoiceRequested() }
        addView(micBtn)

        val toolsToggleBtn = createQuickIcon("⋮", density, palette) {
            currentMode = if (currentMode == BarMode.TOOLS) BarMode.SUGGESTIONS else BarMode.TOOLS
            renderCenter(density, palette)
        }
        addView(toolsToggleBtn)

        renderCenter(density, palette)
    }

    fun updateSuggestions(newSuggestions: List<String>) {
        suggestions = newSuggestions
        if (currentMode != BarMode.TOOLS && currentMode != BarMode.NANO_LOCAL) {
            currentMode = if (newSuggestions.isNotEmpty()) BarMode.SUGGESTIONS else BarMode.STATUS
            val density = context.resources.displayMetrics.density
            val palette = NanoKeyboardTheme.getPalette(context)
            renderCenter(density, palette)
        }
    }

    private fun toggleNanoLocalMode() {
        currentMode = if (currentMode == BarMode.NANO_LOCAL) BarMode.SUGGESTIONS else BarMode.NANO_LOCAL
        val density = context.resources.displayMetrics.density
        val palette = NanoKeyboardTheme.getPalette(context)
        renderCenter(density, palette)
    }

    private fun renderCenter(density: Float, palette: NanoKeyboardTheme.Palette) {
        centerContainer.removeAllViews()
        when (currentMode) {
            BarMode.SUGGESTIONS -> renderSuggestions(density, palette)
            BarMode.TOOLS -> renderTools(density, palette)
            BarMode.NANO_LOCAL -> renderNanoLocalActions(density, palette)
            BarMode.STATUS -> renderStatus(palette)
        }
    }

    private fun renderSuggestions(density: Float, palette: NanoKeyboardTheme.Palette) {
        if (suggestions.isEmpty()) {
            renderStatus(palette)
            return
        }
        for (word in suggestions) {
            val pill = TextView(context).apply {
                text = word
                textSize = 13.5f
                setTextColor(palette.textPrimary)
                gravity = Gravity.CENTER
                layoutParams = LayoutParams(0, (30 * density).toInt(), 1.0f).apply {
                    val m = (3 * density).toInt()
                    setMargins(m, 0, m, 0)
                }
                background = NanoKeyboardTheme.keyDrawable(palette.keyBackground, palette.keyBorder, 6f, density)
                setOnClickListener { onSuggestionSelected(word) }
            }
            centerContainer.addView(pill)
        }
    }

    private fun renderTools(density: Float, palette: NanoKeyboardTheme.Palette) {
        centerContainer.addView(createPill("📋 Pegar", density, palette) { service.pasteClipboard() })
        centerContainer.addView(createPill("⌨️ Teclados", density, palette) { service.chooseKeyboard() })
        centerContainer.addView(createPill("⚙️ Ajustes", density, palette) { NanoInputStatus.openKeyboardSettings(context) })
    }

    private fun renderNanoLocalActions(density: Float, palette: NanoKeyboardTheme.Palette) {
        centerContainer.addView(createPill("✨ Ortografía", density, palette) {
            onNanoActionRequested(NanoLocalAssistant.Action.CORRECT)
        })
        centerContainer.addView(createPill("✍️ Mejorar", density, palette) {
            onNanoActionRequested(NanoLocalAssistant.Action.IMPROVE)
        })
        centerContainer.addView(createPill("📄 Resumir", density, palette) {
            onNanoActionRequested(NanoLocalAssistant.Action.SUMMARIZE)
        })
    }

    private fun renderStatus(palette: NanoKeyboardTheme.Palette) {
        val statusView = TextView(context).apply {
            text = "Nano AI"
            textSize = 12f
            setTextColor(palette.textSecondary)
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            gravity = Gravity.CENTER_VERTICAL
        }
        centerContainer.addView(statusView)
    }

    private fun createPill(label: String, density: Float, palette: NanoKeyboardTheme.Palette, onClick: () -> Unit): View =
        TextView(context).apply {
            text = label
            textSize = 11.5f
            setTextColor(palette.textPrimary)
            gravity = Gravity.CENTER
            val padH = (6 * density).toInt()
            setPadding(padH, 0, padH, 0)
            layoutParams = LayoutParams(LayoutParams.WRAP_CONTENT, (28 * density).toInt()).apply {
                val m = (3 * density).toInt()
                setMargins(m, 0, m, 0)
            }
            background = NanoKeyboardTheme.keyDrawable(palette.keySpecialBackground, palette.keyBorder, 5f, density)
            setOnClickListener { onClick() }
        }

    private fun createQuickIcon(icon: String, density: Float, palette: NanoKeyboardTheme.Palette, onClick: () -> Unit): View =
        TextView(context).apply {
            text = icon
            textSize = 14f
            gravity = Gravity.CENTER
            val size = (30 * density).toInt()
            layoutParams = LayoutParams(size, size).apply { leftMargin = (4 * density).toInt() }
            setTextColor(palette.textPrimary)
            setOnClickListener { onClick() }
        }
}
