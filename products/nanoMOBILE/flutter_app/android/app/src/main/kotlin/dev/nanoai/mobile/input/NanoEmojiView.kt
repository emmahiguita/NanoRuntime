package dev.nanoai.mobile.input

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.View
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/**
 * QUÉ HACE: Panel completo de emojis organizado por categorías con retorno inmediato al teclado.
 * POR QUÉ EXISTE: Provee selección de emojis estándar sin romper secuencias Unicode ni bloquear memoria.
 * QUÉ RECIBE: El servicio activo del teclado y el callback para volver al modo letras.
 */
@SuppressLint("ViewConstructor")
internal class NanoEmojiView(
    context: Context,
    private val onEmojiSelected: (String) -> Unit,
    private val onBackToLetters: () -> Unit,
    private val onBackspace: () -> Unit,
) : LinearLayout(context) {

    private var selectedCategoryIndex = 0
    private lateinit var emojiGridContainer: LinearLayout
    private lateinit var categoryBar: LinearLayout

    init {
        orientation = VERTICAL
        val density = context.resources.displayMetrics.density
        val palette = NanoKeyboardTheme.getPalette(context)
        setBackgroundColor(palette.background)

        buildCategoryTabs(density, palette)
        buildEmojiScrollArea(density, palette)
        buildBottomActionBar(density, palette)
        renderEmojis(density)
    }

    private fun buildCategoryTabs(density: Float, palette: NanoKeyboardTheme.Palette) {
        val tabScroll = HorizontalScrollView(context).apply {
            isHorizontalScrollBarEnabled = false
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, (38 * density).toInt())
            setBackgroundColor(palette.toolbarBackground)
        }
        categoryBar = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding((8 * density).toInt(), 0, (8 * density).toInt(), 0)
        }
        tabScroll.addView(categoryBar)
        addView(tabScroll)

        for (i in NanoEmojiData.categories.indices) {
            val cat = NanoEmojiData.categories[i]
            val btn = TextView(context).apply {
                text = "${cat.icon} ${cat.title}"
                textSize = 12f
                setTextColor(if (i == selectedCategoryIndex) palette.keyActionBackground else palette.textSecondary)
                val padH = (10 * density).toInt()
                setPadding(padH, 0, padH, 0)
                gravity = Gravity.CENTER
                setOnClickListener {
                    selectedCategoryIndex = i
                    updateTabs(palette)
                    renderEmojis(density)
                }
            }
            categoryBar.addView(btn)
        }
    }

    private fun updateTabs(palette: NanoKeyboardTheme.Palette) {
        for (i in 0 until categoryBar.childCount) {
            val v = categoryBar.getChildAt(i) as? TextView ?: continue
            v.setTextColor(if (i == selectedCategoryIndex) palette.keyActionBackground else palette.textSecondary)
        }
    }

    private fun buildEmojiScrollArea(density: Float, palette: NanoKeyboardTheme.Palette) {
        val scrollView = ScrollView(context).apply {
            isVerticalScrollBarEnabled = true
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, (185 * density).toInt())
        }
        emojiGridContainer = LinearLayout(context).apply {
            orientation = VERTICAL
            val pad = (6 * density).toInt()
            setPadding(pad, pad, pad, pad)
        }
        scrollView.addView(emojiGridContainer)
        addView(scrollView)
    }

    private fun renderEmojis(density: Float) {
        emojiGridContainer.removeAllViews()
        val emojis = NanoEmojiData.categories[selectedCategoryIndex].emojis
        val columns = 7
        val rows = (emojis.size + columns - 1) / columns

        for (r in 0 until rows) {
            val rowLayout = LinearLayout(context).apply {
                orientation = HORIZONTAL
                gravity = Gravity.CENTER
                layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, (40 * density).toInt())
            }
            for (c in 0 until columns) {
                val idx = r * columns + c
                if (idx < emojis.size) {
                    val emoji = emojis[idx]
                    val btn = TextView(context).apply {
                        text = emoji
                        textSize = 21f
                        gravity = Gravity.CENTER
                        layoutParams = LayoutParams(0, LayoutParams.MATCH_PARENT, 1.0f)
                        setOnClickListener {
                            performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                            onEmojiSelected(emoji)
                        }
                    }
                    rowLayout.addView(btn)
                } else {
                    rowLayout.addView(View(context), LayoutParams(0, LayoutParams.MATCH_PARENT, 1.0f))
                }
            }
            emojiGridContainer.addView(rowLayout)
        }
    }

    private fun buildBottomActionBar(density: Float, palette: NanoKeyboardTheme.Palette) {
        val bar = LinearLayout(context).apply {
            orientation = HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            val padH = (6 * density).toInt()
            val padV = (4 * density).toInt()
            setPadding(padH, padV, padH, padV)
            layoutParams = LayoutParams(LayoutParams.MATCH_PARENT, (44 * density).toInt())
        }

        val abcBtn = TextView(context).apply {
            text = "ABC"
            textSize = 13f
            gravity = Gravity.CENTER
            setTextColor(palette.textPrimary)
            background = NanoKeyboardTheme.keyDrawable(palette.keySpecialBackground, palette.keyBorder, 7f, density)
            layoutParams = LayoutParams((56 * density).toInt(), LayoutParams.MATCH_PARENT).apply {
                rightMargin = (8 * density).toInt()
            }
            setOnClickListener { onBackToLetters() }
        }
        bar.addView(abcBtn)

        val spaceView = View(context).apply {
            layoutParams = LayoutParams(0, LayoutParams.MATCH_PARENT, 1.0f)
        }
        bar.addView(spaceView)

        val backspaceBtn = TextView(context).apply {
            text = "⌫"
            textSize = 17f
            gravity = Gravity.CENTER
            setTextColor(palette.textPrimary)
            background = NanoKeyboardTheme.keyDrawable(palette.keySpecialBackground, palette.keyBorder, 7f, density)
            layoutParams = LayoutParams((56 * density).toInt(), LayoutParams.MATCH_PARENT).apply {
                leftMargin = (8 * density).toInt()
            }
            setOnClickListener {
                performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                onBackspace()
            }
        }
        bar.addView(backspaceBtn)

        addView(bar)
    }
}
