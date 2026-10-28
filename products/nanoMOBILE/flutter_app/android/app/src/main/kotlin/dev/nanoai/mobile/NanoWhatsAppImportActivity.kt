package dev.nanoai.mobile

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.widget.Toast
import dev.nanoai.mobile.services.NanoFlutterPanelHost
import dev.nanoai.mobile.services.NanoOwlShareInbox
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/** Destino real del compartir oficial. Copia un TXT/ZIP autorizado por content
 * URI, con límite, fuera del hilo UI; no lee datos privados de WhatsApp. */
class NanoWhatsAppImportActivity : Activity() {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        val uri = if (Build.VERSION.SDK_INT >= 33)
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        else @Suppress("DEPRECATION") (intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri)
        if (intent.action != Intent.ACTION_SEND || uri?.scheme != "content") {
            Toast.makeText(this, "Comparte un TXT o ZIP exportado de WhatsApp.", Toast.LENGTH_LONG).show()
            finish()
            return
        }
        worker.execute {
            var copy: File? = null
            try {
                val name = contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME),
                    null, null, null)?.use { if (it.moveToFirst()) it.getString(0) else null }
                    ?: throw IllegalArgumentException("El archivo no tiene nombre.")
                val extension = name.substringAfterLast('.', "").lowercase()
                require(extension in setOf("txt", "zip")) { "Solo TXT o ZIP." }
                val directory = File(filesDir, "owl/inbox").apply { mkdirs() }
                val target = File(directory, "${UUID.randomUUID()}.$extension")
                copy = target
                contentResolver.openInputStream(uri).use { input ->
                    requireNotNull(input)
                    target.outputStream().use { output ->
                        val buffer = ByteArray(8192)
                        var total = 0
                        while (true) {
                            if (Thread.currentThread().isInterrupted) throw InterruptedException()
                            val read = input.read(buffer)
                            if (read < 0) break
                            total += read
                            require(total <= 16 * 1024 * 1024) { "El archivo supera 16 MB." }
                            output.write(buffer, 0, read)
                        }
                    }
                }
                NanoOwlShareInbox.add(this, target, name)
                main.post {
                    if (isFinishing || isDestroyed) return@post
                    if (!NanoFlutterPanelHost.notifyImport()) {
                        packageManager.getLaunchIntentForPackage(packageName)?.apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                            startActivity(this)
                        }
                    }
                    Toast.makeText(this, "Archivo recibido por Nano; se comprobará antes de importarlo.", Toast.LENGTH_LONG).show()
                    finish()
                }
            } catch (error: Exception) {
                copy?.delete()
                main.post {
                    if (!isDestroyed) {
                        Toast.makeText(this, error.message ?: "No se importó el archivo.", Toast.LENGTH_LONG).show()
                        finish()
                    }
                }
            }
        }
    }

    /** Una Activity cerrada no conserva ejecutores ni callbacks de importación. */
    override fun onDestroy() {
        worker.shutdownNow()
        main.removeCallbacksAndMessages(null)
        super.onDestroy()
    }
}
