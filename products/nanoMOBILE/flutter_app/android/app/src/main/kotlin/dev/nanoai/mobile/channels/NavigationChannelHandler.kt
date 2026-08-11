package dev.nanoai.mobile.channels

import android.content.Intent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Handler dedicado para el canal de navegación.
 * Maneja intents del sistema y navegación interna.
 */
class NavigationChannelHandler(
    private val activity: android.app.Activity,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL_NAME = "com.nanoai/navigation"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "openSettings" -> {
                // Navegación forzada desde Ajustes del sistema
                activity.startActivity(
                    Intent(Intent.ACTION_APPLICATION_PREFERENCES).setClassName(
                        activity,
                        activity.javaClass.name
                    )
                )
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Llamado desde MainActivity.onNewIntent() cuando se recibe ACTION_APPLICATION_PREFERENCES
     */
    fun notifySettingsIntent() {
        // Este handler no tiene referencia directa al channel para notificar,
        // pero MainActivity lo maneja directamente
    }
}
