package dev.nanoai.mobile.services

import android.app.DownloadManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import java.io.File

/**
 * NanoMediaDownloader — Descarga real de archivos con DownloadManager del sistema.
 *
 * QUÉ: Detecta el tipo de archivo por extensión y lo descarga en Downloads/Nano/.
 *      Notifica a la galería del sistema vía MediaScannerConnection.
 * CÓMO: DownloadManager.Request con notificación nativa del progreso/completado.
 *       BroadcastReceiver desregistrado en detach() — sin leaks.
 * POR QUÉ: DownloadManager es la API oficial de Android para descargas en background;
 *          gestiona reintentos, WiFi y notificaciones sin threads propios.
 * SOLID-S: Solo descarga — NanoFloatingService decide qué y cuándo descargar.
 */
internal class NanoMediaDownloader(private val ctx: Context) {

    private val dm = ctx.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
    private val pendingIds = mutableMapOf<Long, (Boolean, String?) -> Unit>()

    /** Receptor de completado del sistema — limpiado en detach(). */
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(ctx: Context, intent: Intent) {
            val id = intent.getLongExtra(DownloadManager.EXTRA_DOWNLOAD_ID, -1L)
            val cb = pendingIds.remove(id) ?: return
            val uri = dm.getUriForDownloadedFile(id)
            if (uri != null) {
                // Indexar en galería para que aparezca en Fotos/Videos
                MediaScannerConnection.scanFile(ctx, arrayOf(uri.path), null, null)
                cb(true, uri.path)
            } else {
                cb(false, null)
            }
        }
    }

    init {
        // Registrar BroadcastReceiver compatible con API 26+
        val filter = IntentFilter(DownloadManager.ACTION_DOWNLOAD_COMPLETE)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ctx.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            ctx.registerReceiver(receiver, filter)
        }
    }

    /**
     * Inicia la descarga de [url].
     * @param url URL del archivo a descargar (http/https).
     * @param onDone Callback (ok, path?) en el main thread al completar.
     */
    fun download(url: String, onDone: (Boolean, String?) -> Unit) {
        if (!isValidUrl(url)) { onDone(false, null); return }

        val fileName = fileNameFrom(url)
        val dest = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS),
            "Nano/$fileName"
        )
        dest.parentFile?.mkdirs()

        val req = DownloadManager.Request(Uri.parse(url)).apply {
            setTitle(fileName)
            setDescription("Descargando con Nano…")
            setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            setDestinationUri(Uri.fromFile(dest))
            setAllowedOverMetered(true)
            setAllowedOverRoaming(false)
            addRequestHeader("User-Agent", "Mozilla/5.0 (Android)")
        }

        val id = dm.enqueue(req)
        pendingIds[id] = onDone
    }

    /** Cancela todas las descargas pendientes y desregistra el receptor. */
    fun detach() {
        pendingIds.keys.forEach { dm.remove(it) }
        pendingIds.clear()
        try { ctx.unregisterReceiver(receiver) } catch (_: IllegalArgumentException) {}
    }

    private fun isValidUrl(url: String): Boolean =
        url.startsWith("http://") || url.startsWith("https://")

    /** Extrae el nombre del archivo de la URL; fallback a timestamp + extensión. */
    private fun fileNameFrom(url: String): String {
        val name = url.substringAfterLast("/").substringBefore("?").take(60)
        return if (name.contains(".")) name else "nano_${System.currentTimeMillis()}.mp4"
    }

    companion object {
        /** Detecta si la URL apunta a un archivo multimedia descargable. */
        fun isMediaUrl(url: String): Boolean {
            val lower = url.lowercase()
            return lower.contains(Regex("\\.(mp4|webm|m4v|mov|mp3|m4a|aac|jpg|jpeg|png|gif|webp)(\\?|$)"))
        }

        /** Tipo de medio para mostrar en la UI. */
        fun mediaType(url: String) = when {
            url.lowercase().contains(Regex("\\.(mp4|webm|m4v|mov)")) -> "Video"
            url.lowercase().contains(Regex("\\.(mp3|m4a|aac)")) -> "Audio"
            url.lowercase().contains(Regex("\\.(jpg|jpeg|png|gif|webp)")) -> "Imagen"
            else -> "Archivo"
        }
    }
}
