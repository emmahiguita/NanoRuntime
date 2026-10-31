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
 * QUÉ HACE: Barra superior inteligente con Búho Nano, predicciones en tiempo real y herramientas.
 * CÓMO FUNCIONA: Preasigna vistas para sugerencias eliminando removeAllViews() y recreación de vistas en cada tecla.
 * POR QUÉ EXISTE: Permite 120 FPS constantes sin pausas de Garbage Collection durante la escritura rápida (< 180 líneas).
 */
internal class NanoKeyboardToolbar(
    context: Context,
    private val service: NanoInputMethodService,
    private val onSuggestionSelected: (String) -> Unit,
    private val onVoiceRequested: () -> Unit,
    private val onNanoActionRequested: (NanoLocalAssistant.Action) -> Unit,
) : LinearLayout(context) {

    enum class BarMode { SUGGESTIONS, TOOLS, NANO_LOCAL }

    private var currentMode = BarMode.SUGGESTIONS
    private lateinit var centerContainer: LinearLayout
    private lateinit var suggestionsContainer: LinearLayout
    private lateinit var statusView: TextView
    private val suggestionPills = ArrayList<TextView>(3)
    private lateinit var owlFaceView: ImageView

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
            setOnClickListener { toggleNanoLocalMode() }
        }
        addView(owlFaceView)

        // 2. Contenedor central dinámico
        centerContainer = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LayoutParams(0, LayoutParams.MATCH_PARENT, 1.0f)
        }
        addView(centerContainer)

        // Preconstruir contenedor y 3 píldoras fijas de sugerencias para 0ms de asignación
        suggestionsContainer = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.MATCH_PARENT)
        }
        statusView = TextView(context).apply {
            text = "Nano AI"
            textSize = 12f
            setTextColor(palette.textSecondary)
            typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
            gravity = Gravity.CENTER_VERTICAL
        }
        suggestionsContainer.addView(statusView)

        for (i in 0 until 3) {
            val pill = TextView(context).apply {
                textSize = 13.5f
                setTextColor(palette.textPrimary)
                gravity = Gravity.CENTER
                visibility = GONE
                layoutParams = LayoutParams(0, (30 * density).toInt(), 1.0f).apply {
                    val m = (3 * density).toInt()
                    setMargins(m, 0, m, 0)
                }
                background = NanoKeyboardTheme.keyDrawable(palette.keyBackground, palette.keyBorder, 6f, density)
            }
            suggestionPills.add(pill)
            suggestionsContainer.addView(pill)
        }
        centerContainer.addView(suggestionsContainer)

        // 3. Botones rápidos de la derecha: Micrófono y Menú de herramientas
        addView(createQuickIcon("🎤", density, palette) { onVoiceRequested() })
        addView(createQuickIcon("⋮", density, palette) {
            currentMode = if (currentMode == BarMode.TOOLS) BarMode.SUGGESTIONS else BarMode.TOOLS
            renderModeViews(density, palette)
        })
    }

    /**
     * Actualiza sugerencias reutilizando las vistas existentes sin reconstruir el árbol (0ms GC).
     */
    fun updateSuggestions(newSuggestions: List<String>) {
        if (currentMode != BarMode.SUGGESTIONS) return

        if (newSuggestions.isEmpty()) {
            statusView.visibility = VISIBLE
            for (i in 0 until 3) suggestionPills[i].visibility = GONE
        } else {
            statusView.visibility = GONE
            for (i in 0 until 3) {
                if (i < newSuggestions.size) {
                    val word = newSuggestions[i]
                    suggestionPills[i].text = word
                    suggestionPills[i].setOnClickListener { onSuggestionSelected(word) }
                    suggestionPills[i].visibility = VISIBLE
                } else {
                    suggestionPills[i].visibility = GONE
                }
            }
        }
    }

    private fun toggleNanoLocalMode() {
        currentMode = if (currentMode == BarMode.NANO_LOCAL) BarMode.SUGGESTIONS else BarMode.NANO_LOCAL
        val density = context.resources.displayMetrics.density
        val palette = NanoKeyboardTheme.getPalette(context)
        renderModeViews(density, palette)
    }

    private fun renderModeViews(density: Float, palette: NanoKeyboardTheme.Palette) {
        centerContainer.removeAllViews()
        when (currentMode) {
            BarMode.SUGGESTIONS -> {
                centerContainer.addView(suggestionsContainer)
            }
            BarMode.TOOLS -> {
                centerContainer.addView(createPill("📋 Pegar", density, palette) { service.pasteClipboard() })
                centerContainer.addView(createPill("⌨️ Teclados", density, palette) { service.chooseKeyboard() })
                centerContainer.addView(createPill("⚙️ Ajustes", density, palette) { NanoInputStatus.openKeyboardSettings(context) })
            }
            BarMode.NANO_LOCAL -> {
                centerContainer.addView(createPill("✨ Ortografía", density, palette) { onNanoActionRequested(NanoLocalAssistant.Action.CORRECT) })
                centerContainer.addView(createPill("✍️ Mejorar", density, palette) { onNanoActionRequested(NanoLocalAssistant.Action.IMPROVE) })
                centerContainer.addView(createPill("📄 Resumir", density, palette) { onNanoActionRequested(NanoLocalAssistant.Action.SUMMARIZE) })
            }
        }
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
