package dev.nanoai.mobile.services

import android.content.Context
import android.graphics.Bitmap
import android.os.Build
import android.os.SystemClock
import android.view.Surface
import android.view.WindowManager
import java.io.ByteArrayOutputStream
import java.util.concurrent.Callable
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import java.util.concurrent.ExecutorService
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicLong
import java.util.concurrent.atomic.AtomicReference
import java.util.concurrent.Executors
import kotlin.math.abs

/**
 * NanoAtomicSnapshotter — Captura atómica de jerarquía UI + screenshot.
 *
 * QUÉ: Produce un snapshot coherente del dispositivo sin bloquear el main thread.
 *      Screenshot se inicia primero; árbol de a11y se congela mientras Android lo resuelve.
 * CÓMO: AtomicInteger(remaining) como barrera de dos fases. PNG en executor daemon con
 *       timeout de 100ms para evitar bloquear el binder thread en pantallas 1080p.
 * POR QUÉ: PNG sin timeout puede costar 80-150ms en pantallas densas → bloqueo del
 *          AccessibilityService binder thread → ANR del sistema.
 * FIX BUG-02: pngExecutor tiene shutdown() explícito; PNG usa Future.get(timeout).
 */
object NanoAtomicSnapshotter {
    const val PROTOCOL_VERSION = 1

    // Código de error cuando la compresión PNG supera el timeout de 100ms.
    // Se reporta igual que un fallo de encoding para que el caller decida reintentar.
    private const val ERROR_PNG_ENCODING = -2
    private const val ERROR_PNG_TIMEOUT  = -3

    // Executor daemon: el thread no impide que la JVM muera, pero necesita
    // shutdown() explícito para liberar recursos al destruirse el servicio.
    private val executorLock = Any()
    private val workerCounter = AtomicInteger(0)
    @Volatile private var acceptingCaptures = false
    @Volatile private var pngExecutor: ExecutorService? = null

    private fun newExecutor(): ExecutorService =
        Executors.newFixedThreadPool(2) { runnable ->
            Thread(
                runnable,
                "nano-atomic-png-${workerCounter.incrementAndGet()}",
            ).apply { isDaemon = true }
        }

    // El AccessibilityService es el dueño del executor. Un rebind puede crear
    // una nueva instancia después de shutdown, por eso el recurso es reiniciable.
    fun start() {
        synchronized(executorLock) {
            acceptingCaptures = true
            if (pngExecutor == null || pngExecutor?.isShutdown == true) {
                pngExecutor = newExecutor()
            }
        }
    }

    // Llamado desde AgentAccessibilityService.onDestroy() para evitar thread huérfano.
    fun shutdown() {
        val executor = synchronized(executorLock) {
            acceptingCaptures = false
            val current = pngExecutor
            pngExecutor = null
            current
        }
        executor?.shutdownNow()
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
                // PNG puede costar 80-150ms en 1080p. Se comprime en el executor
                // con timeout de 100ms. Si excede, reporta ERROR_PNG_TIMEOUT y entrega
                // el snapshot sin imagen — el caller puede reintentar sin bloquear.
                val executor = synchronized(executorLock) {
                    if (!acceptingCaptures) null
                    else pngExecutor ?: newExecutor().also { pngExecutor = it }
                }
                if (executor == null) {
                    bitmap.recycle()
                    screenshotErrorCode.set(ERROR_PNG_ENCODING)
                    deliverPart()
                    return@takeScreenshotDetailed
                }
                val compressionStarted = AtomicBoolean(false)
                val bitmapRecycled = AtomicBoolean(false)
                fun recycleBitmapOnce() {
                    if (bitmapRecycled.compareAndSet(false, true)) bitmap.recycle()
                }
                var compressionFuture: java.util.concurrent.Future<ByteArray>? = null
                try {
                    val future = executor.submit(Callable {
                        compressionStarted.set(true)
                        try {
                            bitmap.toPngBytes()
                        } finally {
                            recycleBitmapOnce()
                        }
                    })
                    compressionFuture = future
                    executor.execute {
                        try {
                            screenshotRef.set(future.get(100, TimeUnit.MILLISECONDS))
                        } catch (_: TimeoutException) {
                            if (future.cancel(true) && !compressionStarted.get()) {
                                recycleBitmapOnce()
                            }
                            screenshotErrorCode.set(ERROR_PNG_TIMEOUT)
                        } catch (_: Throwable) {
                            screenshotErrorCode.set(ERROR_PNG_ENCODING)
                        } finally {
                            deliverPart()
                        }
                    }
                } catch (_: RejectedExecutionException) {
                    val future = compressionFuture
                    if (future == null ||
                        (future.cancel(true) && !compressionStarted.get())
                    ) {
                        recycleBitmapOnce()
                    }
                    screenshotErrorCode.set(ERROR_PNG_ENCODING)
                    deliverPart()
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
