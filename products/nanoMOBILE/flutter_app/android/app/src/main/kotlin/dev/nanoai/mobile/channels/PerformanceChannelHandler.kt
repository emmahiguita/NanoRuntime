package dev.nanoai.mobile.channels

import android.os.Handler
import android.os.Looper
import dev.nanoai.mobile.performance.NanoPerformanceEngine
import dev.nanoai.mobile.performance.NanoThermalMonitor
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * PerformanceChannelHandler — Puente Flutter para ADPF y Monitoreo Térmico.
 *
 * Responsabilidad Única (SRP):
 * Despachar llamadas de MethodChannel ("com.nanoai/performance") y eventos de
 * EventChannel ("com.nanoai/thermal_events") entre Dart y el subsistema nativo.
 */
class PerformanceChannelHandler(
    private val performanceEngine: NanoPerformanceEngine,
    private val thermalMonitor: NanoThermalMonitor,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        const val CHANNEL_NAME = "com.nanoai/performance"
        const val THERMAL_STREAM_NAME = "com.nanoai/thermal_events"
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    private val thermalListener: (Int) -> Unit = { status ->
        mainHandler.post {
            eventSink?.success(
                mapOf(
                    "status" to status,
                    "name" to thermalMonitor.statusToString(status),
                    "threadScale" to thermalMonitor.getRecommendedThreadScale(status),
                )
            )
        }
    }

    init {
        thermalMonitor.addListener(thermalListener)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setMode" -> {
                val mode = call.argument<String>("mode") ?: NanoPerformanceEngine.MODE_BALANCED
                val ok = performanceEngine.setMode(mode)
                result.success(ok)
            }
            "getMode" -> {
                result.success(performanceEngine.getMode())
            }
            "getThermalStatus" -> {
                val status = thermalMonitor.getCurrentStatus()
                result.success(
                    mapOf(
                        "status" to status,
                        "name" to thermalMonitor.statusToString(status),
                        "threadScale" to thermalMonitor.getRecommendedThreadScale(status),
                    )
                )
            }
            "registerThreads" -> {
                val tidsList = call.argument<List<Int>>("tids") ?: emptyList()
                performanceEngine.registerWorkerThreads(tidsList.toIntArray())
                result.success(true)
            }
            "reportWorkDuration" -> {
                val durationNs = (call.argument<Number>("durationNs"))?.toLong() ?: 0L
                performanceEngine.reportActualWorkDuration(durationNs)
                result.success(true)
            }
            "getCapabilities" -> {
                val status = thermalMonitor.getCurrentStatus()
                result.success(
                    mapOf(
                        "adpfSupported" to performanceEngine.isAdpfSupported,
                        "thermalSupported" to thermalMonitor.isSupported,
                        "currentMode" to performanceEngine.getMode(),
                        "thermalStatus" to status,
                        "thermalStatusName" to thermalMonitor.statusToString(status),
                        "threadScale" to thermalMonitor.getRecommendedThreadScale(status),
                        "cpuCores" to Runtime.getRuntime().availableProcessors(),
                    )
                )
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        // Enviar estado inicial de inmediato
        val current = thermalMonitor.getCurrentStatus()
        events?.success(
            mapOf(
                "status" to current,
                "name" to thermalMonitor.statusToString(current),
                "threadScale" to thermalMonitor.getRecommendedThreadScale(current),
            )
        )
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun close() {
        thermalMonitor.removeListener(thermalListener)
        performanceEngine.close()
        eventSink = null
    }
}
