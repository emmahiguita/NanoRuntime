package dev.nanoai.mobile.services

import android.content.Context
import android.graphics.PixelFormat
import android.os.Build
import android.view.Gravity
import android.view.WindowManager

/** Geometría de las dos ventanas existentes. No posee vistas, animación ni
 * ejecución; preserva los valores aprobados y las opciones públicas de Android. */
internal object NanoOverlayWindowLayout {
    private fun dp(context: Context, value: Int) = NanoOverlayStyle.dp(context, value)

    /** La burbuja no toma foco ni bloquea los controles de WhatsApp. */
    fun bubble(context: Context): WindowManager.LayoutParams {
        var flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
        if (Build.VERSION.SDK_INT >= 31 && NanoOverlayStyle.glassEnabled) {
            flags = flags or WindowManager.LayoutParams.FLAG_BLUR_BEHIND
        }
        return WindowManager.LayoutParams(
            dp(context, 70), dp(context, 70),
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            flags, PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(context, 8)
            y = dp(context, 180)
            if (Build.VERSION.SDK_INT >= 31 && NanoOverlayStyle.glassEnabled) {
                blurBehindRadius = dp(context, 16)
            }
        }
    }

    /** Solo el panel explícitamente abierto toma foco para su propio editor.
     * Se centra en el espacio disponible y permite ajuste al teclado. */
    fun panel(context: Context): WindowManager.LayoutParams {
        var flags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
            WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
        if (Build.VERSION.SDK_INT >= 31 && NanoOverlayStyle.glassEnabled) {
            flags = flags or WindowManager.LayoutParams.FLAG_BLUR_BEHIND
        }
        val width = (context.resources.displayMetrics.widthPixels * .90f).toInt()
            .coerceAtMost(dp(context, 360))
        return WindowManager.LayoutParams(
            width, WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            flags, PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.CENTER
            softInputMode = WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE
            if (Build.VERSION.SDK_INT >= 31 && NanoOverlayStyle.glassEnabled) {
                blurBehindRadius = dp(context, NanoOverlayStyle.glassBlur)
            }
        }
    }
}
