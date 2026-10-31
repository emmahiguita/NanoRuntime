package dev.nanoai.mobile.input

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Typeface
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.MotionEvent
import android.view.View
import android.widget.TextView

/**
 * QUÉ HACE: Fábrica de vistas para teclas físicas de Nano Keyboard.
 * POR QUÉ EXISTE: Desacopla la creación visual, soporte de tildes (long-press) y estados táctiles.
 * QUÉ DEVUELVE: Instancia de [TextView] configurada para máxima responsividad en 0ms.
 */
internal object NanoKeyFactory {

    private val longPressHandler = Handler(Looper.getMainLooper())

    @SuppressLint("ClickableViewAccessibility")
    fun createKey(
        context: Context,
        model: KeyModel,
        palette: NanoKeyboardTheme.Palette,
        density: Float,
        actionLabel: String,
        onKeyPress: (KeyModel) -> Unit,
        onAltSelected: (String) -> Unit,
        onBackspaceTouch: (View, MotionEvent) -> Boolean,
    ): TextView {
        val btn = TextView(context).apply {
            gravity = Gravity.CENTER
            typeface = Typeface.create("sans-serif", Typeface.NORMAL)
            textSize = when (model.type) {
                KeyType.CHARACTER -> if (model.primaryText.length > 1) 13f else 19f
                KeyType.SPACE -> 12f
                KeyType.ENTER -> 13.5f
                KeyType.EMOJI -> 16f
                else -> 13.5f
            }
            isClickable = false
            isFocusable = false
        }

        applyKeyVisuals(btn, model, palette, density, actionLabel)
        setupTouchListener(btn, model, palette, density, onKeyPress, onAltSelected, onBackspaceTouch)
        return btn
    }

    private fun applyKeyVisuals(
        btn: TextView,
        model: KeyModel,
        palette: NanoKeyboardTheme.Palette,
        density: Float,
        actionLabel: String,
    ) {
        btn.text = if (model.type == KeyType.ENTER) actionLabel else model.primaryText

        val isAction = model.type == KeyType.ENTER
        val normalBg = when {
            isAction -> palette.keyActionBackground
            model.isSpecial || model.type == KeyType.SHIFT -> palette.keySpecialBackground
            else -> palette.keyBackground
        }
        val pressedBg = when {
            isAction -> palette.keySpecialBackground
            else -> palette.keyPressed
        }
        val textColor = when {
            isAction -> palette.textAction
            else -> palette.textPrimary
        }
        btn.setTextColor(textColor)
        btn.background = NanoKeyboardTheme.keyStateListDrawable(
            normalBg = normalBg,
            pressedBg = pressedBg,
            borderColor = palette.keyBorder,
            cornerRadiusDp = 7.5f,
            density = density,
        )
    }

    @SuppressLint("ClickableViewAccessibility")
    private fun setupTouchListener(
        btn: View,
        model: KeyModel,
        palette: NanoKeyboardTheme.Palette,
        density: Float,
        onKeyPress: (KeyModel) -> Unit,
        onAltSelected: (String) -> Unit,
        onBackspaceTouch: (View, MotionEvent) -> Boolean,
    ) {
        if (model.type == KeyType.BACKSPACE) {
            btn.setOnTouchListener { v, event -> onBackspaceTouch(v, event) }
            return
        }

        var longPressed = false
        val longPressRunnable = Runnable {
            if (model.alternatives.isNotEmpty()) {
                longPressed = true
                btn.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                NanoKeyPopup.show(btn, model.alternatives, palette, density) { selected ->
                    onAltSelected(selected)
                }
            }
        }

        btn.setOnTouchListener { v, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    v.isPressed = true
                    longPressed = false
                    if (model.alternatives.isNotEmpty()) {
                        longPressHandler.postDelayed(longPressRunnable, 350)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    v.isPressed = false
                    longPressHandler.removeCallbacks(longPressRunnable)
                    if (!longPressed) {
                        v.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                        onKeyPress(model)
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    v.isPressed = false
                    longPressHandler.removeCallbacks(longPressRunnable)
                    true
                }
                else -> false
            }
        }
    }
}
