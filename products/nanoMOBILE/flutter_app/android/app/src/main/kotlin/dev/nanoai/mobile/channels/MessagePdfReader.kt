package dev.nanoai.mobile.channels

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import java.io.File

/** QUÉ: texto por página y OCR para PDF escaneado.
 * CÓMO: secuencial, con plazo y cobertura parcial explícitos.
 * POR QUÉ: procesar algunas páginas no significa haber leído todo.
 */
internal object MessagePdfReader {
    fun read(file: File, maxPages: Int, withOcr: Boolean): Map<String, Any> {
        val deadline = System.nanoTime() + 15_000_000_000L
        PDDocument.load(file).use { document ->
            val total = document.numberOfPages
            val pages = ArrayList<Map<String, Any>>()
            val stripper = PDFTextStripper()
            var chars = 0
            for (page in 1..minOf(total, maxPages)) {
                if (Thread.currentThread().isInterrupted) throw InterruptedException()
                if (System.nanoTime() >= deadline || chars >= 100_000) break
                stripper.startPage = page; stripper.endPage = page
                var text = stripper.getText(document).trim().take(if (withOcr) 6000 else 40_000)
                val scanned = text.isEmpty() && withOcr
                if (scanned) text = scanPage(file, page - 1)
                chars += text.length
                pages.add(mapOf("page" to page, "text" to text, "ocr" to scanned))
            }
            return mapOf("pages" to pages, "totalPages" to total,
                "partial" to (pages.size < total))
        }
    }

    /** Cierra cada página, descriptor y bitmap incluso en cancelación/error. */
    private fun scanPage(file: File, index: Int): String =
        ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { descriptor ->
            PdfRenderer(descriptor).use { renderer ->
                renderer.openPage(index).use { page ->
                    val scale = minOf(2.0, 1800.0 / maxOf(page.width, page.height))
                    val bitmap = Bitmap.createBitmap(maxOf(1, (page.width * scale).toInt()),
                        maxOf(1, (page.height * scale).toInt()), Bitmap.Config.ARGB_8888)
                    try {
                        bitmap.eraseColor(Color.WHITE)
                        page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                        MessageImageReader.ocr(bitmap)
                    } finally { bitmap.recycle() }
                }
            }
        }
}
