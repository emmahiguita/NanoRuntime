package dev.nanoai.mobile.channels

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import dev.nanoai.mobile.NanoApplication
import dev.nanoai.mobile.automation.AutomationRuntimeService
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * WA-PROD-01 — estado y configuración del runtime en segundo plano
 * (Ajustes → Automatización). Solo se registra en el engine de la UI: lee
 * estados factuales (exención de batería, listener, cola pendiente) y
 * expone la puerta que el NotificationListener consulta antes de persistir.
 */
class AutomationBackgroundChannelHandler(
    private val activity: Activity,
) : MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> {
                val pm = activity.getSystemService(PowerManager::class.java)
                result.success(
                    mapOf(
                        "backgroundEnabled" to isBackgroundEnabled(activity),
                        "listenerGranted" to NotificationManagerCompat
                            .getEnabledListenerPackages(activity)
                            .contains(activity.packageName),
                        "batteryIgnored" to pm.isIgnoringBatteryOptimizations(
                            activity.packageName,
                        ),
                        "runtimeRunning" to AutomationRuntimeService.running,
                        "pendingCount" to NanoApplication.from(activity)
                            .durableInbox.pendingCount(),
                    ),
                )
            }

            "setEnabled" -> {
                val enabled = call.argument<Boolean>("enabled") == true
                activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                    .edit()
                    .putBoolean(KEY_ENABLED, enabled)
                    .apply()
                result.success(true)
            }

            "requestBatteryExemption" -> result.success(requestBatteryExemption())

            else -> result.notImplemented()
        }
    }

    private fun requestBatteryExemption(): Boolean {
        return try {
            val intent = Intent(
                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                Uri.parse("package:${activity.packageName}"),
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            activity.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    companion object {
        const val CHANNEL_NAME = "com.nanoai/automation_background"
        private const val PREFS = "nano_automation"
        private const val KEY_ENABLED = "background_enabled"

        /** Puerta del listener (NLS): procesar en segundo plano exige permiso
         *  explícito; desactivado = comportamiento histórico (solo UI abierta). */
        fun isBackgroundEnabled(context: Context): Boolean =
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getBoolean(KEY_ENABLED, true)
    }
}
