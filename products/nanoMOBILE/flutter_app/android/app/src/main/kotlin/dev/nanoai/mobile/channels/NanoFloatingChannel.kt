package dev.nanoai.mobile.channels

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import dev.nanoai.mobile.services.NanoFloatingService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * NanoFloatingChannel — Canal Flutter↔Kotlin para el overlay flotante.
 *
 * QUÉ: Expone hasPermission, requestPermission, show, hide y takePendingPrompt.
 * CÓMO: MethodChannel 'dev.nanoai/floating'; delega show/hide a NanoFloatingService.
 * POR QUÉ: Separar el canal del servicio sigue SOLID-S; el canal solo enruta,
 *          el servicio solo dibuja. Arranque solo posible desde Activity visible
 *          → sin zombis de overlay iniciados desde background.
 *
 * REGISTRAR en MainActivity.configureFlutterEngine:
 *   NanoFloatingChannel(this, messenger).also { nanoFloatingChannel = it }
 */
class NanoFloatingChannel(private val activity: Activity, messenger: BinaryMessenger) {

    private val channel = MethodChannel(messenger, "dev.nanoai/floating")

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                // Toma el prompt del Extra que NanoFloatingService puso en el Intent.
                "takePendingPrompt" -> {
                    val entry = activity.intent?.getStringExtra("nano.entry.prompt")
                    // Limpiar el extra para no consumirlo dos veces.
                    activity.intent?.removeExtra("nano.entry.prompt")
                    result.success(entry) // null si no hay prompt pendiente.
                }
                // Verifica si SYSTEM_ALERT_WINDOW está concedido.
                "hasPermission" -> result.success(Settings.canDrawOverlays(activity))

                // Abre la pantalla del sistema para otorgar el permiso.
                "requestPermission" -> {
                    val intent = Intent(
                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                        Uri.parse("package:${activity.packageName}")
                    )
                    activity.startActivity(intent)
                    result.success(null)
                }
                // Inicia el servicio de overlay (requiere SYSTEM_ALERT_WINDOW).
                "show" -> {
                    if (!Settings.canDrawOverlays(activity)) {
                        // Flutter recibirá false y mostrará el diálogo de permiso.
                        result.error("permission_required", "Autoriza superposición", null)
                    } else {
                        activity.startService(
                            Intent(activity, NanoFloatingService::class.java)
                        )
                        result.success(true)
                    }
                }
                // Detiene el servicio de overlay.
                "hide" -> {
                    activity.stopService(Intent(activity, NanoFloatingService::class.java))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Llamar en cleanupFlutterEngine para evitar leaks de canal. */
    fun detach() = channel.setMethodCallHandler(null)
}
