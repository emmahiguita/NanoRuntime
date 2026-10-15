package dev.nanoai.mobile.channels

import android.content.Context
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Extrae texto de PDFs privados de Nano sin convertirlo en hechos comerciales. */
class PdfTextExtractionChannelHandler(context: Context) : MethodChannel.MethodCallHandler {
    private val appContext = context.applicationContext

    init {
        PDFBoxResourceLoader.init(appContext)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "extractPages") {
            result.notImplemented()
            return
        }
        try {
            val rawPath = call.argument<String>("path").orEmpty()
            val file = File(rawPath).canonicalFile
            val privateRoot = File(appContext.applicationInfo.dataDir).canonicalFile
            if (!file.isFile || !file.path.startsWith(privateRoot.path + File.separator)) {
                result.error("invalid_pdf", "El PDF no pertenece a la biblioteca privada de Nano.", null)
                return
            }
            if (file.length() > MAX_FILE_BYTES) {
                result.error("pdf_too_large", "El PDF supera el tamaño permitido para analizarlo.", null)
                return
            }
            PDDocument.load(file).use { document ->
                val pageCount = minOf(document.numberOfPages, MAX_PAGES)
                val stripper = PDFTextStripper()
                val pages = ArrayList<Map<String, Any>>(pageCount)
                for (page in 1..pageCount) {
                    stripper.startPage = page
                    stripper.endPage = page
                    val text = stripper.getText(document).trim().take(MAX_CHARS_PER_PAGE)
                    pages.add(mapOf("page" to page, "text" to text))
                }
                result.success(pages)
            }
        } catch (_: Throwable) {
            result.error("pdf_extract_failed", "No se pudo leer el texto de este PDF.", null)
        }
    }

    companion object {
        const val CHANNEL_NAME = "dev.nanoai/pdf_text"
        private const val MAX_FILE_BYTES = 50L * 1024L * 1024L
        private const val MAX_PAGES = 200
        private const val MAX_CHARS_PER_PAGE = 40_000
    }
}
