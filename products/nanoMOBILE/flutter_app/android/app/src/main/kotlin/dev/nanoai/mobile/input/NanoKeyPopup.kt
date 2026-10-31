package dev.nanoai.mobile.input

import android.content.Context
import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.TextView

/**
 * QUÉ HACE: Despliega una burbuja flotante con caracteres alternativos al mantener pulsada una tecla.
 * POR QUÉ EXISTE: Permite escribir tildes (á, é, í, ó, ú), diéresis (ü) y símbolos sin cambiar de teclado.
 * QUÉ RECIBE: La vista anfitriona de la tecla, las alternativas disponibles y el callback de inserción.
 */
internal object NanoKeyPopup {

    private var activePopup: PopupWindow? = null

    fun dismiss() {
        activePopup?.dismiss()
        activePopup = null
    }

    fun show(
        anchor: View,
        alternatives: List<String>,
        palette: NanoKeyboardTheme.Palette,
        density: Float,
        onSelect: (String) -> Unit,
    ) {
        dismiss()
        if (alternatives.isEmpty()) return

        val context = anchor.context
        val container = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            val pad = (4 * density).toInt()
            setPadding(pad, pad, pad, pad)
            background = NanoKeyboardTheme.keyDrawable(
                bgColor = palette.keySpecialBackground,
                borderColor = palette.keyBorder,
                cornerRadiusDp = 8f,
                density = density,
            )
        }

        val popup = PopupWindow(
            container,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            true,
        ).apply {
            setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            isOutsideTouchable = true
        }
        activePopup = popup

        for (alt in alternatives) {
            val tv = TextView(context).apply {
                text = alt
                textSize = 19f
                setTextColor(palette.textPrimary)
                gravity = Gravity.CENTER
                val size = (38 * density).toInt()
                layoutParams = LinearLayout.LayoutParams(size, size).apply {
                    val m = (2 * density).toInt()
                    setMargins(m, 0, m, 0)
                }
                background = NanoKeyboardTheme.keyStateListDrawable(
                    normalBg = palette.keyBackground,
                    pressedBg = palette.keyPressed,
                    borderColor = palette.keyBorder,
                    cornerRadiusDp = 6f,
                    density = density,
                )
                setOnClickListener {
                    onSelect(alt)
                    popup.dismiss()
                }
            }
            container.addView(tv)
        }

        container.measure(View.MeasureSpec.UNSPECIFIED, View.MeasureSpec.UNSPECIFIED)
        val xOffset = (anchor.width - container.measuredWidth) / 2
        val yOffset = -(anchor.height + container.measuredHeight + (6 * density).toInt())

        try {
            popup.showAsDropDown(anchor, xOffset, yOffset)
        } catch (_: Throwable) {
            // Anchor view ya no visible o ventana destruida
        }
    }
}
