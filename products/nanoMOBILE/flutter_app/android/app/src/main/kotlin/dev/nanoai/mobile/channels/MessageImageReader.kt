package dev.nanoai.mobile.channels

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import java.io.File
import java.util.concurrent.TimeUnit

/** QUÉ: OCR y clasificación reales del archivo del mensaje.
 * CÓMO: reduce dimensiones, usa ML Kit y libera lectores y bitmap.
 * POR QUÉ: etiquetas generales no son comprensión completa de una escena.
 */
internal object MessageImageReader {
    fun read(file: File): Map<String, Any> {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.path, bounds)
        require(bounds.outWidth > 0 && bounds.outHeight > 0)
        var sample = 1
        while (maxOf(bounds.outWidth, bounds.outHeight) / sample > 2048) sample *= 2
        val bitmap = BitmapFactory.decodeFile(file.path,
            BitmapFactory.Options().apply { inSampleSize = sample })
            ?: error("Imagen no decodificable")
        try {
            val text = ocr(bitmap)
            val labeler = ImageLabeling.getClient(ImageLabelerOptions.DEFAULT_OPTIONS)
            val labels = try {
                Tasks.await(labeler.process(InputImage.fromBitmap(bitmap, 0)), 4, TimeUnit.SECONDS)
                    .filter { it.confidence >= 0.65f }.take(6)
                    .map { mapOf("label" to it.text, "confidence" to it.confidence.toDouble()) }
            } finally { labeler.close() }
            return mapOf("text" to text, "labels" to labels,
                "coverage" to "OCR y etiquetas generales; sin interpretación espacial ni identidad de personas")
        } finally { bitmap.recycle() }
    }

    /** Reutilizado por páginas escaneadas; devuelve solo texto observado. */
    fun ocr(bitmap: Bitmap): String {
        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        return try {
            Tasks.await(recognizer.process(InputImage.fromBitmap(bitmap, 0)), 4, TimeUnit.SECONDS)
                .text.take(6000)
        } finally { recognizer.close() }
    }
}
