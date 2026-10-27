package dev.nanoai.mobile.media

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Size
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit
import java.util.concurrent.RejectedExecutionException

/** Reutiliza el canal del almacén: trabajo acotado, sin servicio residente ni permisos nuevos. */
internal class WhatsAppMediaCatalogHandler(context: Context) {
    private val app = context.applicationContext
    private val db = WhatsAppMediaCatalogDb(app)
    private val source = WhatsAppMediaCatalogSource(app, db)
    private val main = Handler(Looper.getMainLooper())

    fun handle(call: MethodCall, result: MethodChannel.Result): Boolean {
        if (call.method !in METHODS) return false
        try {
            io.execute {
                try {
                    val value: Any? = when (call.method) {
                        "whatsappMediaScan" -> source.scan()
                        "whatsappMediaPage" -> db.page(source.allowedKinds(), call.argument<Number>("beforeMs")?.toLong(), call.argument("beforeUri"))
                        else -> {
                            val raw = call.argument<String>("uri").orEmpty()
                            val row = db.find(raw) ?: error("Unknown indexed URI")
                            require(row["kind"] in source.allowedKinds()) { "Permission revoked" }
                            val uri = Uri.parse(raw)
                            require(uri.scheme == "content" && uri.authority == "media")
                            // Verifica acceso actual incluso si el original se borró o cambió permisos.
                            app.contentResolver.openFileDescriptor(uri, "r")?.use { } ?: error("File unavailable")
                            if (call.method == "whatsappMediaThumbnail") thumbnail(uri) else {
                                val intent = Intent(Intent.ACTION_VIEW).setDataAndType(uri, row["mime"])
                                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                main.post {
                                    try { app.startActivity(intent); result.success(true) }
                                    catch (_: Exception) { result.error("MEDIA_OPEN_FAILED", "No se pudo abrir el archivo", null) }
                                }
                                return@execute
                            }
                        }
                    }
                    main.post { result.success(value) }
                } catch (error: Exception) {
                    main.post { result.error("MEDIA_CATALOG_FAILED", error.javaClass.simpleName, null) }
                }
            }
        } catch (_: RejectedExecutionException) {
            result.error("MEDIA_CATALOG_BUSY", "Biblioteca ocupada; reintenta", null)
        }
        return true
    }

    /** Solo miniatura de 320 px. El original se abre mediante acción explícita del usuario. */
    private fun thumbnail(uri: Uri): ByteArray? {
        if (Build.VERSION.SDK_INT < 29) return null
        val bitmap = app.contentResolver.loadThumbnail(uri, Size(320, 320), null)
        return try {
            ByteArrayOutputStream().use { out -> bitmap.compress(Bitmap.CompressFormat.JPEG, 75, out); out.toByteArray() }
        } finally { bitmap.recycle() }
    }

    companion object {
        private val METHODS = setOf("whatsappMediaScan", "whatsappMediaPage", "whatsappMediaThumbnail", "whatsappMediaOpen")
        // Un único trabajador compartido entre motores; su hilo termina tras inactividad.
        private val io = ThreadPoolExecutor(0, 1, 15, TimeUnit.SECONDS, ArrayBlockingQueue(24),
            { task -> Thread(task, "nano-media-catalog").apply { isDaemon = true } })
    }
}
