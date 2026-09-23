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
 * QUÉ: Expone hasPermission, requestPermission, show, hide,
 *      takePendingPrompt y takePendingEntry (prompt + mode).
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

                // Kit v2: devuelve {prompt, mode} como mapa; null si no hay prompt.
                "takePendingEntry" -> {
                    val original = activity.intent
                    val prompt = original?.getStringExtra("nano.entry.prompt")
                    val mode   = original?.getStringExtra("nano.entry.mode") ?: "quick"
                    // Limpiar los extras para no consumirlos dos veces.
                    original?.removeExtra("nano.entry.prompt")
                    original?.removeExtra("nano.entry.mode")
                    result.success(
                        if (prompt == null) null
                        else mapOf("prompt" to prompt, "mode" to mode)
                    )
                }

                // Compat v1: devuelve solo el String del prompt.
                "takePendingPrompt" -> {
                    val prompt = activity.intent?.getStringExtra("nano.entry.prompt")
                    activity.intent?.removeExtra("nano.entry.prompt")
                    result.success(prompt)
                }

                // Verifica si SYSTEM_ALERT_WINDOW está concedido.
                "hasPermission" -> result.success(Settings.canDrawOverlays(activity))

                // Abre la pantalla del sistema para otorgar el permiso.
                "requestPermission" -> {
                    activity.startActivity(
                        Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:${activity.packageName}")
                        )
                    )
                    result.success(null)
                }

                // Inicia el servicio de overlay (requiere SYSTEM_ALERT_WINDOW).
                "show" -> {
                    if (!Settings.canDrawOverlays(activity)) {
                        result.error("permission_required", "Autoriza superposición", null)
                    } else {
                        activity.startService(Intent(activity, NanoFloatingService::class.java))
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
