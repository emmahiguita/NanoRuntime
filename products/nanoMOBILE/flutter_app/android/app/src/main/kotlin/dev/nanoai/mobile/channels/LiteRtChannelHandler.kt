package dev.nanoai.mobile.channels

import android.content.Context
import android.os.Handler
import android.util.Log
import dev.nanoai.mobile.runtime.NanoModelRuntimeSupervisor
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.File

/**
 * LiteRtChannelHandler — Puente MethodChannel y EventChannel entre Dart y LiteRT.
 *
 * QUÉ: Recibe peticiones de Flutter ("initialize", "generate", "release", "cancel", "getMetrics").
 * CÓMO: Delega al supervisor singleton [runtimeSupervisor], sin crear motores JNI duplicados.
 * POR QUÉ: Evita OOM por modelos duplicados (UI vs Headless vs Búho Flotante).
 * SOLID: SRP (traducción de canal Flutter a llamadas del supervisor) + DIP (depende de supervisor inyectado).
 */
class LiteRtChannelHandler(
    context: Context,
    private val ioScope: CoroutineScope,
    private val mainHandler: Handler,
    private val supervisor: NanoModelRuntimeSupervisor,
    private val performanceEngine: dev.nanoai.mobile.performance.NanoPerformanceEngine? = null,
    private val thermalMonitor: dev.nanoai.mobile.performance.NanoThermalMonitor? = null,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val METHOD_CHANNEL_NAME = "com.nanoai/litert"
        const val STREAM_CHANNEL_NAME = "com.nanoai/litert_stream"
    }

    private var sink: EventChannel.EventSink? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(
                mapOf(
                    "supported" to true,
                    "hasGpuOpenCl" to listOf("/vendor/lib64/libOpenCL.so", "/system/lib64/libOpenCL.so")
                        .any { File(it).exists() }
                )
            )
            "cancel" -> cancelAsync(call.argument<String>("requestId"), result)
            "getMetrics" -> result.success(supervisor.getMetrics())
            "initialize", "release", "generate" -> {
                ioScope.launch(Dispatchers.IO) {
                    try {
                        val response = when (call.method) {
                            "initialize" -> {
                                val userThreads = call.argument<Int>("threads")
                                val effectiveThreads = userThreads ?: thermalMonitor?.let {
                                    (4 * it.getRecommendedThreadScale(it.getCurrentStatus())).toInt().coerceIn(1, 4)
                                } ?: 4
                                val modelPath = call.argument<String>("modelPath") ?: error("Falta modelPath")
                                val backend = call.argument<String>("backend") ?: "cpu"
                                
                                supervisor.ensureReady(modelPath, backend, effectiveThreads)
                                mapOf("success" to true, "backend" to backend, "modelPath" to modelPath)
                            }
                            "release" -> {
                                supervisor.unload()
                                true
                            }
                            else -> {
                                val startNs = System.nanoTime()
                                performanceEngine?.registerWorkerThreads(intArrayOf(android.os.Process.myTid()))
                                performanceEngine?.setMode(dev.nanoai.mobile.performance.NanoPerformanceEngine.MODE_TURBO)
                                try {
                                    supervisor.generate(call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()) { event ->
                                        mainHandler.post { sink?.success(event) }
                                    }
                                } finally {
                                    val durationNs = System.nanoTime() - startNs
                                    performanceEngine?.reportActualWorkDuration(durationNs)
                                    performanceEngine?.setMode(dev.nanoai.mobile.performance.NanoPerformanceEngine.MODE_BALANCED)
                                }
                            }
                        }
                        mainHandler.post { result.success(response) }
                    } catch (error: Exception) {
                        val id = call.argument<String>("requestId")
                        Log.e("LiteRtChannel", "Fallo en ${call.method}", error)
                        mainHandler.post {
                            if (id != null) {
                                sink?.success(mapOf("requestId" to id, "error" to (error.message ?: "Fallo LiteRT"), "stop" to true))
                            }
                            result.error("litert_failed", error.message, null)
                        }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        sink = events
    }

    override fun onCancel(arguments: Any?) {
        sink = null
        cancelAsync(null)
    }

    private fun cancelAsync(id: String?, result: MethodChannel.Result? = null) {
        ioScope.launch(Dispatchers.IO) {
            val cancelled = supervisor.cancelInference(id)
            if (result != null) mainHandler.post { result.success(cancelled) }
        }
    }
}
