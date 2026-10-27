package dev.nanoai.mobile.services

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.drawable.BitmapDrawable
import android.widget.TextView

/** Reutiliza el icono Nano ya empaquetado. El muestreo evita decodificar un
 * lienzo de 1024 px para un selector pequeño. No abre WhatsApp al seleccionarlo. */
internal fun TextView.installWhatsAppToolIcon(context: Context, inline: Boolean = false) {
    if (!inline) text = ""
    contentDescription = "Activar herramienta WhatsApp"
    try {
        val options = BitmapFactory.Options().apply { inSampleSize = 16 }
        val bitmap = context.assets.open(
            "flutter_assets/assets/automation/whatsapp_personal_icon.png"
        ).use { BitmapFactory.decodeStream(it, null, options) }
        val drawable = BitmapDrawable(resources, bitmap).apply {
            val side = NanoOverlayStyle.dp(context, 24)
            setBounds(0, 0, side, side)
        }
        if (inline) {
            setCompoundDrawables(drawable, null, null, null)
            compoundDrawablePadding = NanoOverlayStyle.dp(context, 10)
        } else setCompoundDrawables(null, drawable, null, null)
    } catch (_: Exception) {
        // Ausencia real del asset: mantener un selector accesible y utilizable.
        text = "WA"
    }
}
