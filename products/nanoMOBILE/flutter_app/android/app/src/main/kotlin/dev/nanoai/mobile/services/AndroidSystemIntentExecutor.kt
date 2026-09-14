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
            "display_settings" -> Intent(Settings.ACTION_DISPLAY_SETTINGS)
            "sound_settings" -> Intent(Settings.ACTION_SOUND_SETTINGS)
            "battery_saver_settings" -> Intent(Settings.ACTION_BATTERY_SAVER_SETTINGS)
            "application_settings" -> Intent(Settings.ACTION_APPLICATION_SETTINGS)
            "date_settings" -> Intent(Settings.ACTION_DATE_SETTINGS)
            "internal_storage_settings" -> Intent(Settings.ACTION_INTERNAL_STORAGE_SETTINGS)
            "nfc_settings" -> Intent(Settings.ACTION_NFC_SETTINGS)
            "network_operator_settings" -> Intent(Settings.ACTION_NETWORK_OPERATOR_SETTINGS)
            "device_info_settings" -> Intent(Settings.ACTION_DEVICE_INFO_SETTINGS)
            "camera" -> Intent(android.provider.MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA)
            "dial" -> Intent(Intent.ACTION_DIAL)
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
