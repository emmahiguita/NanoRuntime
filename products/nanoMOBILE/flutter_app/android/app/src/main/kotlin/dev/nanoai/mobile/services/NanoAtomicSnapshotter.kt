package dev.nanoai.mobile.services

import android.content.Context
import android.graphics.Bitmap
import android.os.Build
import android.os.SystemClock
import android.view.Surface
import android.view.WindowManager
import java.io.ByteArrayOutputStream
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference
import java.util.concurrent.Executors
import kotlin.math.abs

/**
 * Captura una observacion coherente del dispositivo sin bloquear el main
 * thread. La solicitud de screenshot se inicia primero y, mientras Android la
 * resuelve, se congela el arbol de accesibilidad. El resultado se publica solo
 * cuando ambas mitades han terminado.
 * Motor on-device de captura atómica de jerarquía y visual de Nano.
 * Devuelve el PNG como ByteArray por MethodChannel con sincronización
 * temporal estricta y sin abrir ningún puerto local inseguro.
 */
object NanoAtomicSnapshotter {
    const val PROTOCOL_VERSION = 1
    private const val ERROR_PNG_ENCODING = -2
    private val pngExecutor = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "nano-atomic-png").apply { isDaemon = true }
    }

    fun capture(
        service: AgentAccessibilityService,
        includeScreenshot: Boolean,
        callback: (Map<String, Any?>) -> Unit,
    ) {
        val startedAtEpochMs = System.currentTimeMillis()
        val startedAtNanos = SystemClock.elapsedRealtimeNanos()
        val hierarchyRef = AtomicReference<Map<String, Any?>>(emptyMap())
        val hierarchyCapturedAtNanos = AtomicLong(0L)
        val screenshotRef = AtomicReference<ByteArray?>(null)
        val screenshotCapturedAtNanos = AtomicLong(0L)
        val screenshotErrorCode = AtomicInteger(0)
        val remaining = AtomicInteger(if (includeScreenshot) 2 else 1)
        val delivered = AtomicBoolean(false)

        fun deliverPart() {
            if (remaining.decrementAndGet() != 0 || !delivered.compareAndSet(false, true)) {
                return
            }

            val displayMetrics = service.resources.displayMetrics
            val hierarchy = hierarchyRef.get().toMutableMap()
            val screenshotPng = screenshotRef.get()
            val hierarchyNanos = hierarchyCapturedAtNanos.get()
            val screenshotNanos = screenshotCapturedAtNanos.get()
            val event = AgentAccessibilityBridge.lastEvent
            val activePackage = hierarchy["package"] as? String ?: ""
            val activity = if (event?.packageName == activePackage) event.className else ""

            hierarchy["protocolVersion"] = PROTOCOL_VERSION
            hierarchy["capturedAtEpochMs"] = startedAtEpochMs
            hierarchy["captureStartedAtElapsedNanos"] = startedAtNanos
            hierarchy["hierarchyCapturedAtElapsedNanos"] = hierarchyNanos
            hierarchy["screenshotCapturedAtElapsedNanos"] = screenshotNanos
            hierarchy["synchronizationSkewMs"] = if (screenshotNanos > 0L) {
                abs(screenshotNanos - hierarchyNanos) / 1_000_000.0
            } else {
                null
            }
            hierarchy["width"] = displayMetrics.widthPixels
            hierarchy["height"] = displayMetrics.heightPixels
            hierarchy["rotation"] = displayRotation(service)
            hierarchy["activity"] = activity
            hierarchy["screenshotRequested"] = includeScreenshot
            hierarchy["screenshotIncluded"] = screenshotPng != null
            hierarchy["screenshotErrorCode"] = screenshotErrorCode.get()
            if (screenshotPng != null) hierarchy["screenshotPng"] = screenshotPng
            callback(hierarchy)
        }

        if (includeScreenshot) {
            // Android completa esta rama en el executor del service. Iniciar la
            // captura antes del dump reduce el desfase frente a UIs animadas.
            service.takeScreenshotDetailed { bitmap, errorCode ->
                screenshotCapturedAtNanos.set(SystemClock.elapsedRealtimeNanos())
                screenshotErrorCode.set(errorCode)
                if (bitmap == null) {
                    deliverPart()
                    return@takeScreenshotDetailed
                }
                // PNG puede costar decenas de ms en 1080p. Nunca se comprime
                // en el main thread del AccessibilityService.
                pngExecutor.execute {
                    try {
                        screenshotRef.set(bitmap.toPngBytes())
                    } catch (_: Throwable) {
                        screenshotErrorCode.set(ERROR_PNG_ENCODING)
                    } finally {
                        bitmap.recycle()
                        deliverPart()
                    }
                }
            }
        }

        hierarchyRef.set(service.dumpSnapshot())
        hierarchyCapturedAtNanos.set(SystemClock.elapsedRealtimeNanos())
        deliverPart()
    }

    private fun Bitmap.toPngBytes(): ByteArray {
        val output = ByteArrayOutputStream()
        compress(Bitmap.CompressFormat.PNG, 100, output)
        return output.toByteArray()
    }

    @Suppress("DEPRECATION")
    private fun displayRotation(service: AgentAccessibilityService): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            service.display?.rotation ?: Surface.ROTATION_0
        } else {
            val manager = service.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
            manager?.defaultDisplay?.rotation ?: Surface.ROTATION_0
        }
}
