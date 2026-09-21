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
            "alarm" -> Intent(android.provider.AlarmClock.ACTION_SHOW_ALARMS)
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

    /**
     * Programa una alarma o despertador en el reloj del sistema (Clean Architecture).
     * Mapea días ISO (1=Lun..7=Dom) a constantes de Calendar de Android.
     */
    fun setAlarm(
        hour: Int,
        minutes: Int,
        message: String = "",
        weekdays: List<Int>? = null,
        skipUi: Boolean = true,
    ): IntentResult {
        val intent = Intent(android.provider.AlarmClock.ACTION_SET_ALARM).apply {
            putExtra(android.provider.AlarmClock.EXTRA_HOUR, hour)
            putExtra(android.provider.AlarmClock.EXTRA_MINUTES, minutes)
            if (message.isNotBlank()) {
                putExtra(android.provider.AlarmClock.EXTRA_MESSAGE, message)
            }
            if (!weekdays.isNullOrEmpty()) {
                val calendarDays = ArrayList<Int>()
                for (w in weekdays) {
                    when (w) {
                        1 -> calendarDays.add(java.util.Calendar.MONDAY)
                        2 -> calendarDays.add(java.util.Calendar.TUESDAY)
                        3 -> calendarDays.add(java.util.Calendar.WEDNESDAY)
                        4 -> calendarDays.add(java.util.Calendar.THURSDAY)
                        5 -> calendarDays.add(java.util.Calendar.FRIDAY)
                        6 -> calendarDays.add(java.util.Calendar.SATURDAY)
                        7 -> calendarDays.add(java.util.Calendar.SUNDAY)
                    }
                }
                putIntegerArrayListExtra(android.provider.AlarmClock.EXTRA_DAYS, calendarDays)
            }
            putExtra(android.provider.AlarmClock.EXTRA_SKIP_UI, skipUi)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            context.startActivity(intent)
            IntentResult(true, null)
        } catch (e: Exception) {
            IntentResult(false, e.message ?: "set_alarm_failed")
        }
    }
}
