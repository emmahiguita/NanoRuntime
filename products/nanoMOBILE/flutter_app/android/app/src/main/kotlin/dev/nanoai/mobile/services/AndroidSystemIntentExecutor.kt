package dev.nanoai.mobile.services

import android.content.Context
import android.content.Intent
import android.provider.Settings

/**
 * Ejecutor de NAVEGACIÓN de sistema allowlisted (A3).
 *
 * SRP: ejecuta SOLO destinos oficiales allowlisted. NO acepta strings crudos de
 * Intent, component names arbitrarios, URIs arbitrarias ni extras arbitrarios:
 * la entrada es un ID semántico (p. ej. `"bluetooth_settings"`).
 *
 * Los destinos accessibility / notification listener / app details NO se
 * duplican aquí: ya los abre [dev.nanoai.mobile.channels.DevicePermissionsChannelHandler]
 * (boundary de permisos).
 */
class AndroidSystemIntentExecutor(private val context: Context) {

    data class IntentResult(val opened: Boolean, val error: String?)

    fun open(destination: String): IntentResult {
        val intent = when (destination) {
            "settings" -> Intent(Settings.ACTION_SETTINGS)
            "wifi_settings" -> Intent(Settings.ACTION_WIFI_SETTINGS)
            "bluetooth_settings" -> Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
            else -> return IntentResult(false, "unsupported_destination")
        }
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            context.startActivity(intent)
            IntentResult(true, null)
        } catch (e: Exception) {
            IntentResult(false, "launch_failed")
        }
    }
}
