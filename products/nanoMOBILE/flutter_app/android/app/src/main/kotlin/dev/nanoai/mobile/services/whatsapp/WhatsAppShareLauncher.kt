package dev.nanoai.mobile.services.whatsapp

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.util.Log
import dev.nanoai.mobile.services.AgentAccessibilityBridge

/** Dueño del lanzamiento de medios. Mantiene el fallback manual existente,
 * pasando las opciones Android por la API correcta, sin repetir autoenvíos. */
internal class WhatsAppShareLauncher(private val context: Context) {
    /** Un cambio de paquete desarma la tarea antes de mostrar el selector. */
    fun launch(intent: Intent, primaryPkg: String, useChooser: Boolean): Boolean {
        fun launchFor(pkg: String, chooser: Boolean = useChooser) {
            val targeted = Intent(intent).setPackage(pkg)
            val actual = if (chooser) Intent.createChooser(targeted, null) else targeted
            val strategy = WindowStrategySelector.resolveBest(context)
            strategy.applyToIntent(actual, context)
            context.startActivity(actual, strategy.launchOptions(context))
        }
        return try {
            launchFor(primaryPkg)
            true
        } catch (_: ActivityNotFoundException) {
            val fallback = if (primaryPkg == "com.whatsapp") "com.whatsapp.w4b" else "com.whatsapp"
            AgentAccessibilityBridge.disarmAutoSend("El paquete objetivo cambió antes de abrir WhatsApp.")
            try {
                launchFor(fallback, chooser = true)
                true
            } catch (error: ActivityNotFoundException) {
                Log.e("nanoagent_share", "No se pudo abrir el selector de WhatsApp", error)
                AgentAccessibilityBridge.disarmAutoSend()
                false
            }
        }
    }
}
