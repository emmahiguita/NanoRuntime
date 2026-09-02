package dev.nanoai.mobile.services

import android.graphics.Bitmap
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.label.ImageLabeling
import com.google.mlkit.vision.label.defaults.ImageLabelerOptions
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * VisionService (A16) — etiquetado de imagen on-device (ML Kit bundled).
 *
 * SRP: solo detección de objetos/etiquetas sobre un Bitmap. No conoce Flutter
 * ni captura pantalla. El resultado es OBSERVACIÓN NO CONFIABLE (estructurado:
 * label/confidence/bounds), nunca prosa ejecutable.
 */
class VisionService {

    data class VisionLabel(
        val text: String,
        val confidence: Float,
        val left: Int,
        val top: Int,
        val right: Int,
        val bottom: Int,
    )

    private val labeler = ImageLabeling.getClient(
        ImageLabelerOptions.Builder()
            .setConfidenceThreshold(0.5f)
            .build(),
    )

    /** Etiqueta objetos en [bitmap]. Bloquea hasta ~10s (llamar en background).
     *
     * ML Kit Image Labeling CLASIFICA (qué hay en la imagen), no LOCALIZA
     * (no da boundingBox; eso es Object Detection). El bounds se reporta como
     * la imagen completa — honesto: no se inventa una localización precisa.
     */
    fun label(bitmap: Bitmap): List<VisionLabel> {
        val image = InputImage.fromBitmap(bitmap, 0)
        val latch = CountDownLatch(1)
        val labels = mutableListOf<VisionLabel>()
        labeler.process(image)
            .addOnSuccessListener { result ->
                for (l in result) {
                    labels.add(
                        VisionLabel(l.text, l.confidence, 0, 0, bitmap.width, bitmap.height),
                    )
                }
                latch.countDown()
            }
            .addOnFailureListener { latch.countDown() }
        try {
            latch.await(10, TimeUnit.SECONDS)
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        return labels
    }
}
