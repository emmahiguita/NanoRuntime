package dev.nanoai.mobile.channels

import android.content.Context
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.FutureTask
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

/** QUÉ: documentos e imágenes de mensajes, fuera de UI.
 * CÓMO: cola acotada compartida y cancelación por requestId.
 * POR QUÉ: evita bloquear Flutter o dejar hilos ilimitados trabajando.
 */
class PdfTextExtractionChannelHandler(context: Context) : MethodChannel.MethodCallHandler {
    private val appContext = context.applicationContext
    private val main = Handler(Looper.getMainLooper())
    private val owned = ConcurrentHashMap.newKeySet<String>()
    @Volatile private var closed = false

    init {
        PDFBoxResourceLoader.init(appContext)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("requestId").orEmpty()
        if (call.method == "cancel") {
            if (owned.remove(id)) jobs.remove(id)?.cancel(true)
            worker.purge()
            result.success(null)
            return
        }
        if (call.method !in setOf("extractPages", "readMessagePdf", "readMessageImage")) {
            result.notImplemented()
            return
        }
        val key = id.ifBlank { "library:${System.nanoTime()}" }
        if (closed) { result.error("closed", "Lector cerrado", null); return }
        val task = FutureTask<Unit> {
          try {
            val rawPath = call.argument<String>("path").orEmpty()
            val file = File(rawPath).canonicalFile
            val privateRoot = File(appContext.applicationInfo.dataDir).canonicalFile
            require(file.isFile && file.path.startsWith(privateRoot.path + File.separator))
            require(file.length() in 1..MAX_FILE_BYTES)
            val output: Any = when (call.method) {
                "readMessageImage" -> MessageImageReader.read(file)
                "readMessagePdf" -> MessagePdfReader.read(file, 8, true)
                else -> MessagePdfReader.read(file, MAX_PAGES, false)["pages"]!!
            }
            if (!Thread.currentThread().isInterrupted) main.post { if (!closed) result.success(output) }
          } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            main.post { if (!closed) result.error("cancelled", "Lectura cancelada", null) }
          } catch (_: Exception) {
            main.post { if (!closed) result.error("pdf_extract_failed", "No se pudo leer este archivo", null) }
          } finally { jobs.remove(key); owned.remove(key) }
        }
        jobs[key] = task
        owned.add(key)
        try { worker.execute(task) } catch (_: java.util.concurrent.RejectedExecutionException) {
            jobs.remove(key)
            owned.remove(key)
            result.error("document_busy", "Hay una lectura en curso", null)
        }
    }

    /** Cancela solo el trabajo de este engine; no detiene el lector de otro. */
    fun close() {
        closed = true
        owned.forEach { jobs.remove(it)?.cancel(true) }
        owned.clear()
        worker.purge()
    }

    companion object {
        const val CHANNEL_NAME = "dev.nanoai/pdf_text"
        private const val MAX_FILE_BYTES = 50L * 1024L * 1024L
        private const val MAX_PAGES = 200
        private val jobs = ConcurrentHashMap<String, FutureTask<Unit>>()
        // Sin hilo permanente cuando no hay trabajo: el worker vence tras 20 s.
        private val worker = ThreadPoolExecutor(0, 1, 20, TimeUnit.SECONDS,
            ArrayBlockingQueue<Runnable>(2), { task ->
                Thread(task, "nano-document-reader").apply { isDaemon = true }
            })
    }
}
