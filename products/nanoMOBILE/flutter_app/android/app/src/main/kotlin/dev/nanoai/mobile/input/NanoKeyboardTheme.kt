package dev.nanoai.mobile.input

import android.content.Context
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.StateListDrawable

/**
 * QUÉ HACE: Tokens de diseño Material 3 Expressive para Nano Keyboard.
 * POR QUÉ EXISTE: Garantiza contraste, bordes limpios (6-9dp) y elimina colores estridentes.
 * QUÉ PROVEE: Paletas claras y oscuras con acento azul Nano (#6087B2 / #8EAED7).
 */
internal object NanoKeyboardTheme {
    data class Palette(
        val background: Int,
        val keyBackground: Int,
        val keySpecialBackground: Int,
        val keyActionBackground: Int,
        val textPrimary: Int,
        val textSecondary: Int,
        val textAction: Int,
        val keyBorder: Int,
        val keyPressed: Int,
        val toolbarBackground: Int,
        val dividerColor: Int,
    )

    private val lightPalette = Palette(
        background = Color.parseColor("#F0F2F5"),
        keyBackground = Color.parseColor("#FFFFFF"),
        keySpecialBackground = Color.parseColor("#DDE2E9"),
        keyActionBackground = Color.parseColor("#6087B2"),
        textPrimary = Color.parseColor("#20242B"),
        textSecondary = Color.parseColor("#646C78"),
        textAction = Color.parseColor("#FFFFFF"),
        keyBorder = Color.parseColor("#D6DAE2"),
        keyPressed = Color.parseColor("#E4E7ED"),
        toolbarBackground = Color.parseColor("#EAECEF"),
        dividerColor = Color.parseColor("#D1D5DB"),
    )

    private val darkPalette = Palette(
        background = Color.parseColor("#1C1F25"),
        keyBackground = Color.parseColor("#343942"),
        keySpecialBackground = Color.parseColor("#454B55"),
        keyActionBackground = Color.parseColor("#8EAED7"),
        textPrimary = Color.parseColor("#F6F7FA"),
        textSecondary = Color.parseColor("#BEC5D0"),
        textAction = Color.parseColor("#1C1F25"),
        keyBorder = Color.parseColor("#3C424E"),
        keyPressed = Color.parseColor("#4C5360"),
        toolbarBackground = Color.parseColor("#15171B"),
        dividerColor = Color.parseColor("#2D3139"),
    )

    fun getPalette(context: Context): Palette {
        val isDark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        return if (isDark) darkPalette else lightPalette
    }

    fun keyDrawable(bgColor: Int, borderColor: Int, cornerRadiusDp: Float, density: Float): GradientDrawable {
        val radiusPx = cornerRadiusDp * density
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(bgColor)
            cornerRadius = radiusPx
            setStroke((0.7f * density).toInt().coerceAtLeast(1), borderColor)
        }
    }

    fun keyStateListDrawable(
        normalBg: Int,
        pressedBg: Int,
        borderColor: Int,
        cornerRadiusDp: Float,
        density: Float,
    ): StateListDrawable {
        val normal = keyDrawable(normalBg, borderColor, cornerRadiusDp, density)
        val pressed = keyDrawable(pressedBg, borderColor, cornerRadiusDp, density)
        return StateListDrawable().apply {
            addState(intArrayOf(android.R.attr.state_pressed), pressed)
            addState(intArrayOf(), normal)
        }
    }
}
