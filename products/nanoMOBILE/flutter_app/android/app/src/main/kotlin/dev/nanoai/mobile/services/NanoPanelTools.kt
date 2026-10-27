package dev.nanoai.mobile.services

import android.content.Context
import android.graphics.Rect
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.*

/** Presentación de las rutas existentes; Resumir es la clave histórica Android
 * de lectura, no una promesa de resumen mediante IA o comprensión visual. */
internal data class NanoPanelTool(val key: String, val label: String, val description: String)
internal object NanoPanelTools {
    val all = listOf(
        NanoPanelTool("Chat", "Conversar", "Consulta al asistente con el modelo o la conexión disponible."),
        NanoPanelTool("Resumir", "Leer pantalla", "Lee texto accesible de la app activa. No analiza imágenes."),
        NanoPanelTool("Auto", "Controlar apps", "Indica una acción concreta para el motor de automatización."),
        NanoPanelTool("WhatsApp", "WhatsApp", "Busca un contacto, abre un chat o indica qué enviar."),
        NanoPanelTool("Media", "Descargar enlace", "Pega un enlace para buscar archivos descargables."),
    )
    fun find(key: String) = all.firstOrNull { it.key == key } ?: all.first()
}

/** Menú anclado del overlay. Posee una sola ventana y la cierra al desmontar;
 * seleccionar únicamente devuelve una clave al editor que ya existe. */
internal class NanoPanelToolPicker(
    private val context: Context,
    private val selected: () -> String,
    private val choose: (String) -> Unit,
    private val options: List<NanoPanelTool> = NanoPanelTools.all,
) {
    private var popup: PopupWindow? = null
    private fun dp(n: Int) = NanoOverlayStyle.dp(context, n)

    fun dismiss() { popup?.dismiss(); popup = null }

    /** Mide la lista y el espacio seguro antes de preferir el lado superior. */
    fun show(anchor: View) {
        if (popup?.isShowing == true || !anchor.isAttachedToWindow) return
        val frame = Rect().also(anchor::getWindowVisibleDisplayFrame)
        val width = minOf(dp(280), (frame.width() - dp(16)).coerceAtLeast(dp(48)))
        val list = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(8), dp(8), dp(8), dp(8))
        }
        val scroll = ScrollView(context).apply { addView(list) }
        val window = PopupWindow(scroll, width, ViewGroup.LayoutParams.WRAP_CONTENT, true).apply {
            setBackgroundDrawable(NanoOverlayStyle.glassCard(context, 24))
            isOutsideTouchable = true
            elevation = dp(12).toFloat()
            inputMethodMode = PopupWindow.INPUT_METHOD_NOT_NEEDED
            windowLayoutType = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            animationStyle = if (android.animation.ValueAnimator.areAnimatorsEnabled())
                android.R.style.Animation_Dialog else 0
        }
        popup = window
        for (tool in options) {
            val current = selected() == tool.key
            val row = LinearLayout(context).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                minimumHeight = dp(48)
                setPadding(dp(10), dp(8), dp(10), dp(8))
                background = NanoOverlayStyle.chip(context, current)
                contentDescription = tool.label
                isSelected = current
                isClickable = true
                setOnClickListener { dismiss(); choose(tool.key) }
            }
            val label = NanoOverlayStyle.text(context, tool.label, 14f)
            if (tool.key == "WhatsApp") label.installWhatsAppToolIcon(context, inline = true)
            else {
                val resource = when (tool.key) {
                    "AttachCamera" -> android.R.drawable.ic_menu_camera
                    "AttachPhotos" -> android.R.drawable.ic_menu_gallery
                    "AttachFiles" -> android.R.drawable.ic_menu_agenda
                    else -> null
                }
                val icon = resource?.let { context.getDrawable(it)?.mutate() }
                    ?: NanoPanelIcon(tool.key, NanoOverlayStyle.onSurfaceMuted)
                icon.setTint(NanoOverlayStyle.onSurfaceMuted)
                icon.setBounds(0, 0, dp(22), dp(22))
                label.setCompoundDrawables(icon, null, null, null)
                label.compoundDrawablePadding = dp(10)
            }
            row.addView(label, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            if (current) row.addView(ImageView(context).apply {
                setImageDrawable(NanoPanelIcon("check", NanoOverlayStyle.onSurface))
            }, LinearLayout.LayoutParams(dp(18), dp(18)))
            list.addView(row)
        }
        scroll.measure(View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
            View.MeasureSpec.makeMeasureSpec((frame.height() - dp(16)).coerceAtLeast(0), View.MeasureSpec.AT_MOST))
        val pos = IntArray(2).also(anchor::getLocationOnScreen)
        val above = pos[1] - scroll.measuredHeight - dp(8)
        val below = pos[1] + anchor.height + dp(8)
        val minY = frame.top + dp(8)
        val maxY = (frame.bottom - scroll.measuredHeight - dp(8)).coerceAtLeast(minY)
        val y = (if (above >= minY) above else below).coerceIn(minY, maxY)
        val x = pos[0].coerceIn(frame.left + dp(8),
            (frame.right - width - dp(8)).coerceAtLeast(frame.left + dp(8)))
        window.height = scroll.measuredHeight
        window.showAtLocation(anchor, Gravity.TOP or Gravity.START, x, y)
    }
}
