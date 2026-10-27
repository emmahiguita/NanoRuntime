package dev.nanoai.mobile.channels

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ArrayBlockingQueue
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ThreadPoolExecutor
import java.util.concurrent.TimeUnit

/** Copia archivos reales fuera del hilo UI. Un trabajador y dos esperas máximas
 * limitan disco y memoria; el hilo termina tras 15 s sin trabajo. No retiene Activity. */
internal object CatalogCopyJob {
    private val main = Handler(Looper.getMainLooper())
    private val worker = ThreadPoolExecutor(0, 1, 15, TimeUnit.SECONDS,
        ArrayBlockingQueue<Runnable>(2), { task -> Thread(task, "nano-catalog-copy") })
    private val categories = setOf("productos_servicios", "informes", "fotos", "videos", "documentos")

    fun submit(context: Context, source: String, category: String?, result: MethodChannel.Result) {
        val root = context.filesDir
        val staging = context.cacheDir
        try {
            worker.execute {
                var partial: File? = null
                try {
                    val src = File(source)
                    require(src.isFile) { "El archivo de origen no existe" }
                    val folder = category?.takeIf { it in categories } ?: "documentos"
                    val dir = File(root, "nano/catalog/$folder")
                    check(dir.isDirectory || dir.mkdirs()) { "No se pudo abrir el catálogo" }
                    val extension = src.extension.takeIf { it.isNotBlank() }?.let { ".$it" }.orEmpty()
                    val stem = src.nameWithoutExtension.ifBlank { "archivo" }
                    var dest = File(dir, src.name)
                    var suffix = 2
                    while (dest.exists() && suffix <= 1000) {
                        dest = File(dir, "$stem ($suffix)$extension")
                        suffix++
                    }
                    check(!dest.exists()) { "Hay demasiados archivos con el mismo nombre" }
                    // Una copia interrumpida no debe aparecer como documento listo.
                    partial = File.createTempFile("nano-import-", ".part", staging)
                    src.copyTo(partial, overwrite = true)
                    check(partial.renameTo(dest)) { "No se pudo finalizar el archivo" }
                    partial = null
                    main.post { result.success(dest.absolutePath) }
                } catch (error: Exception) {
                    partial?.delete()
                    main.post { result.error("copy_failed", "No se pudo copiar al catálogo: ${error.message}", null) }
                }
            }
        } catch (_: RejectedExecutionException) {
            result.error("catalog_busy", "Espera a que termine la importación en curso", null)
        }
    }
}
