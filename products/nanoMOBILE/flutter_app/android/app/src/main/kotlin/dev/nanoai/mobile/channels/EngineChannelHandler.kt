package dev.nanoai.mobile.channels

import android.util.Log
import dev.nanoai.mobile.EngineSupervisor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Canal `com.nanoai/engine` — ciclo de vida del motor nanortime.
 *
 * `start` responde `accepted: true` de inmediato (el spawn + health poll
 * corren en hilos IO del supervisor) y los estados reales se entregan por
 * evento `engineState` hacia Dart. `state` devuelve el snapshot actual.
 */
class EngineChannelHandler(
    private val engineSupervisor: EngineSupervisor,
    private val ioScope: CoroutineScope,
    private val mainHandler: android.os.Handler,
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "EngineChannel"
        const val CHANNEL_NAME = "com.nanoai/engine"
        const val EVENT_STATE = "engineState"
        private const val HEALTH_TIMEOUT_MS = 2_000
    }

    /** Canal para empujar estados a Dart — lo fija MainActivity tras crear. */
    @Volatile
    private var channel: MethodChannel? = null

    fun attach(channel: MethodChannel) {
        this.channel = channel
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "start" -> handleStart(call, result)
            "state" -> handleVerifiedState(result)
            "health" -> handleHealth(result)
            "stop" -> handleStop(result)
            "debugKill" -> result.success(engineSupervisor.debugKillEngine())
            "ensureExtracted" -> handleEnsureExtracted(result)
            else -> result.notImplemented()
        }
    }

    private fun handleStart(call: MethodCall, result: MethodChannel.Result) {
        val port = call.argument<Int>("port") ?: EngineSupervisor.ENGINE_PORT_DEFAULT
        val modelPath = call.argument<String?>("modelPath")

        engineSupervisor.start(port, modelPath) { state ->
            mainHandler.post {
                channel?.invokeMethod(EVENT_STATE, stateToMap(state))
            }
        }
        result.success(mapOf("accepted" to true))
    }

    private fun handleHealth(result: MethodChannel.Result) {
        val port = currentPort()
        if (port <= 0) {
            result.error("engine_not_running", "motor no está corriendo", null)
            return
        }
        ioScope.launch {
            val body = engineSupervisor.probeHealth(port, HEALTH_TIMEOUT_MS)
            mainHandler.post {
                if (body != null) {
                    result.success(parseHealth(body))
                } else {
                    result.error("health_failed", "sin respuesta de 127.0.0.1:$port/health", null)
                }
            }
        }
    }

    private fun handleStop(result: MethodChannel.Result) {
        ioScope.launch {
            engineSupervisor.stop { ok ->
                mainHandler.post { result.success(ok) }
            }
        }
    }

    private fun handleEnsureExtracted(result: MethodChannel.Result) {
        engineSupervisor.ensureExtracted { res ->
            mainHandler.post {
                res.fold(
                    onSuccess = { f ->
                        result.success(mapOf("path" to f.absolutePath, "bytes" to f.length()))
                    },
                    onFailure = { e ->
                        Log.w(TAG, "ensureExtracted falló: ${e.message}")
                        result.error("extract_failed", e.message, null)
                    },
                )
            }
        }
    }

    private fun currentPort(): Int {
        val state = engineSupervisor.currentState()
        return when (state) {
            is EngineSupervisor.EngineState.Ready -> state.port
            else -> -1
        }
    }

    /** Parseo tolerante del body /health — org.json es parte de Android. */
    private fun parseHealth(body: String): Map<String, Any?> {
        return try {
            val json = org.json.JSONObject(body)
            mapOf(
                "status" to json.optString("status"),
                "version" to json.optString("version"),
                "uptime_seconds" to json.optLong("uptime_seconds", -1L),
                "active_requests" to json.optInt("active_requests", -1),
            )
        } catch (e: Exception) {
            mapOf("status" to "unparseable", "raw" to body.take(200))
        }
    }

    private fun stateToMap(state: EngineSupervisor.EngineState): Map<String, Any?> {
        return when (state) {
            is EngineSupervisor.EngineState.Idle -> mapOf("state" to "idle")
            is EngineSupervisor.EngineState.Starting -> mapOf("state" to "starting", "port" to state.port)
            is EngineSupervisor.EngineState.Ready ->
                mapOf("state" to "ready", "pid" to state.pid, "port" to state.port)
            is EngineSupervisor.EngineState.Failed -> mapOf("state" to "failed", "reason" to state.reason)
        }
    }

    /**
     * `state` ahora significa "comprueba que el proceso todavía existe" —
     * la verificación real (worker round-trip) corre en IO, no en main thread.
     * `process_alive` es la señal autoritativa de liveness para el watchdog.
     */
    private fun handleVerifiedState(result: MethodChannel.Result) {
        ioScope.launch {
            val state = engineSupervisor.verifiedState()
            mainHandler.post {
                result.success(verifiedStateToMap(state))
            }
        }
    }

    private fun verifiedStateToMap(state: EngineSupervisor.EngineState): Map<String, Any?> {
        return when (state) {
            is EngineSupervisor.EngineState.Idle ->
                mapOf("state" to "idle", "process_alive" to false, "source" to "worker")
            is EngineSupervisor.EngineState.Starting ->
                mapOf("state" to "starting", "port" to state.port, "process_alive" to false, "source" to "worker")
            is EngineSupervisor.EngineState.Ready ->
                mapOf("state" to "ready", "pid" to state.pid, "port" to state.port, "process_alive" to true, "source" to "worker")
            is EngineSupervisor.EngineState.Failed ->
                mapOf("state" to "failed", "reason" to state.reason, "process_alive" to false, "source" to "worker")
        }
    }
}
