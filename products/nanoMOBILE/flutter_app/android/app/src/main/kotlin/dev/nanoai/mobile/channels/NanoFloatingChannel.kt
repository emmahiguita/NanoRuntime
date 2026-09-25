package dev.nanoai.mobile.channels

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import dev.nanoai.mobile.services.NanoFloatingService
import dev.nanoai.mobile.services.NanoMediaDownloader
import dev.nanoai.mobile.services.NanoMediaResolver
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * NanoFloatingChannel — Canal Flutter↔Kotlin para el overlay flotante y descargas multimedia.
 *
 * QUÉ: Expone hasPermission, requestPermission, show, hide,
 *      takePendingPrompt, takePendingEntry, resolveMedia y downloadMedia.
 * CÓMO: MethodChannel 'dev.nanoai/floating'; delega show/hide a NanoFloatingService
 *       y resolveMedia/downloadMedia a NanoMediaResolver y NanoMediaDownloader.
 * POR QUÉ: Conecta tanto el panel Flutter como la burbuja nativa al mismo motor Snaptube.
 */
class NanoFloatingChannel(private val activity: Activity, messenger: BinaryMessenger) {

    private val channel = MethodChannel(messenger, "dev.nanoai/floating")
    private val mediaResolver by lazy { NanoMediaResolver(activity) }
    private val mediaDownloader by lazy { NanoMediaDownloader(activity) }

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

                // Resuelve enlaces de YouTube, Facebook, X, Instagram, TikTok a stream MP4/MP3 directo.
                "resolveMedia" -> {
                    val url = call.argument<String>("url")?.trim().orEmpty()
                    val audioOnly = call.argument<Boolean>("audioOnly") ?: false
                    if (url.isEmpty()) {
                        result.success(mapOf("ok" to false, "error" to "URL vacía"))
                        return@setMethodCallHandler
                    }
                    mediaResolver.resolveMedia(url, audioOnly) { media, err ->
                        if (media != null) {
                            result.success(
                                mapOf(
                                    "ok" to true,
                                    "downloadUrl" to media.downloadUrl,
                                    "filename" to media.filename,
                                    "isAudioOnly" to media.isAudioOnly,
                                    "sourceService" to media.sourceService,
                                )
                            )
                        } else {
                            result.success(mapOf("ok" to false, "error" to (err ?: "No se pudo resolver el enlace")))
                        }
                    }
                }

                // Descarga mediante DownloadManager nativo de Android e indexa en Galería.
                "downloadMedia" -> {
                    val url = call.argument<String>("url")?.trim().orEmpty()
                    val audioOnly = call.argument<Boolean>("audioOnly") ?: false
                    if (url.isEmpty()) {
                        result.success(mapOf("ok" to false, "error" to "URL vacía"))
                        return@setMethodCallHandler
                    }
                    if (NanoMediaResolver.isSupportedSocialUrl(url) && !NanoMediaDownloader.isMediaUrl(url)) {
                        mediaResolver.resolveMedia(url, audioOnly) { media, err ->
                            if (media != null) {
                                mediaDownloader.download(media.downloadUrl) { ok, path ->
                                    result.success(mapOf("ok" to ok, "path" to path, "filename" to media.filename))
                                }
                            } else {
                                result.success(mapOf("ok" to false, "error" to (err ?: "Error al extraer stream")))
                            }
                        }
                    } else {
                        mediaDownloader.download(url) { ok, path ->
                            result.success(mapOf("ok" to ok, "path" to path))
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    /** Llamar en cleanupFlutterEngine para evitar leaks de canal. */
    fun detach() {
        channel.setMethodCallHandler(null)
        mediaResolver.destroy()
        mediaDownloader.detach()
    }
}
