package dev.nanoai.mobile.input

import android.content.Context
import android.content.res.Configuration
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView

/**
 * QUÉ HACE: Construye los renglones de teclas y administra las referencias a vistas especiales.
 * POR QUÉ EXISTE: Cumple la regla de responsabilidad única y límite estricto < 200 líneas.
 */
internal object NanoKeyboardRowsBuilder {

    data class BuildResult(
        val container: LinearLayout,
        val letterKeys: List<Pair<TextView, KeyModel>>,
        val enterKeys: List<TextView>,
        val shiftKey: TextView?,
    )

    fun buildModeContainer(
        context: Context,
        mode: KeyboardMode,
        density: Float,
        palette: NanoKeyboardTheme.Palette,
        actionLabel: String,
        onKeyPress: (KeyModel) -> Unit,
        onAltSelected: (String) -> Unit,
        onBackspaceTouch: (View, MotionEvent) -> Boolean,
    ): BuildResult {
        val isLandscape = context.resources.configuration.orientation == Configuration.ORIENTATION_LANDSCAPE
        val keyHeight = ((if (isLandscape) 34f else 46f) * density).toInt()
        val rowMargin = (3.5f * density).toInt()
        val keyMargin = (2.2f * density).toInt()
        val rows = NanoKeyboardLayouts.getRows(mode)

        val letterKeys = ArrayList<Pair<TextView, KeyModel>>()
        val enterKeys = ArrayList<TextView>()
        var shiftKey: TextView? = null

        val container = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )

            for (rowModels in rows) {
                val rowLayout = LinearLayout(context).apply {
                    orientation = LinearLayout.HORIZONTAL
                    gravity = Gravity.CENTER
                    layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, keyHeight).apply {
                        bottomMargin = rowMargin
                    }
                }
                for (model in rowModels) {
                    val keyView = NanoKeyFactory.createKey(
                        context = context,
                        model = model,
                        palette = palette,
                        density = density,
                        actionLabel = actionLabel,
                        onKeyPress = onKeyPress,
                        onAltSelected = onAltSelected,
                        onBackspaceTouch = onBackspaceTouch,
                    )
                    if (mode == KeyboardMode.LETTERS && model.type == KeyType.CHARACTER) {
                        letterKeys.add(Pair(keyView, model))
                    } else if (model.type == KeyType.SHIFT) {
                        shiftKey = keyView
                    } else if (model.type == KeyType.ENTER) {
                        enterKeys.add(keyView)
                    }
                    rowLayout.addView(keyView, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.MATCH_PARENT, model.weight).apply {
                        leftMargin = keyMargin
                        rightMargin = keyMargin
                    })
                }
                addView(rowLayout)
            }
        }

        return BuildResult(container, letterKeys, enterKeys, shiftKey)
    }
}
