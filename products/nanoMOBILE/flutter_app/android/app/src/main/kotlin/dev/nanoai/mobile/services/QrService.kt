package dev.nanoai.mobile.services

import android.graphics.Bitmap
import com.google.mlkit.vision.barcode.BarcodeScanner
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * QrService — Escaneo de código QR y códigos de barra on-device con ML Kit.
 *
 * **QUÉ HACE:**
 * Procesa un Bitmap en memoria para detectar y decodificar códigos QR 100% offline.
 *
 * **CÓMO FUNCIONA:**
 * Pasa el Bitmap a `InputImage.fromBitmap` e invoca `BarcodeScanning.getClient`.
 *
 * **POR QUÉ:**
 * Permite decodificar QR directamente de capturas de pantalla o WebView sin necesidad de usar la cámara.
 */
class QrService {

    data class QrResult(
        val rawValue: String,
        val format: Int,
        val valueType: Int,
        val bounds: List<Int>?,
    )

    private val options = BarcodeScannerOptions.Builder()
        .setBarcodeFormats(Barcode.FORMAT_QR_CODE, Barcode.FORMAT_ALL_FORMATS)
        .build()

    private val scanner: BarcodeScanner = BarcodeScanning.getClient(options)

    /** Decodifica códigos QR en [bitmap]. Bloquea hasta 5s (llamar en background thread). */
    fun scan(bitmap: Bitmap): List<QrResult> {
        val image = InputImage.fromBitmap(bitmap, 0)
        val latch = CountDownLatch(1)
        val results = mutableListOf<QrResult>()

        scanner.process(image)
            .addOnSuccessListener { barcodes ->
                for (barcode in barcodes) {
                    val raw = barcode.rawValue ?: continue
                    val box = barcode.boundingBox
                    val boundsList = box?.let { listOf(it.left, it.top, it.right, it.bottom) }
                    results.add(
                        QrResult(
                            rawValue = raw,
                            format = barcode.format,
                            valueType = barcode.valueType,
                            bounds = boundsList,
                        )
                    )
                }
                latch.countDown()
            }
            .addOnFailureListener {
                latch.countDown()
            }

        try {
            latch.await(5, TimeUnit.SECONDS)
        } catch (e: InterruptedException) {
            Thread.currentThread().interrupt()
        }
        return results
    }
}
