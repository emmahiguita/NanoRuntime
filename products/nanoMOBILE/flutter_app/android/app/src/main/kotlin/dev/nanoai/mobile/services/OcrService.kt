package dev.nanoai.mobile.services

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * OcrService (A9) — reconocimiento de texto on-device (ML Kit bundled).
 *
 * SRP: solo OCR sobre un Bitmap. No conoce Flutter/MethodChannel (eso es
 * [dev.nanoai.mobile.channels.AgentChannelHandler]) ni captura pantalla. El
 * texto reconocido es OBSERVACIÓN NO CONFIABLE; el llamador decide qué hacer.
 */
class OcrService {

    data class OcrLine(
        val text: String,
        val left: Int,
        val top: Int,
        val right: Int,
        val bottom: Int,
    )

    private val recognizer =
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    /** Reconoce texto en [bitmap]. Bloquea hasta ~10s (llamar en background). */
    fun recognize(bitmap: Bitmap): List<OcrLine> {
        val image = InputImage.fromBitmap(bitmap, 0)
        val latch = CountDownLatch(1)
        val lines = mutableListOf<OcrLine>()
        recognizer.process(image)
            .addOnSuccessListener { result ->
                for (block in result.textBlocks) {
                    for (line in block.lines) {
                        val b = line.boundingBox ?: continue
                        if (line.text.isBlank()) continue
                        lines.add(OcrLine(line.text, b.left, b.top, b.right, b.bottom))
                    }
                }
                latch.countDown()
            }
            .addOnFailureListener { latch.countDown() }
        try {
            latch.await(10, TimeUnit.SECONDS)
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        return lines
    }
}
