package dev.nanoai.mobile.channels

import android.os.Handler
import dev.nanoai.mobile.runtime.MnnRuntimeSupervisor
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

/** QUÉ: traduce canales Flutter a la instancia MNN compartida.
 * CÓMO: cada handler posee un lease; cierre y cancelación afectan solo sus requests.
 * POR QUÉ: reutiliza pesos entre UI/headless sin duplicar la lógica de inferencia. */
class MnnChannelHandler(
    private val ioScope: CoroutineScope,
    private val mainHandler: Handler,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        const val METHOD_CHANNEL_NAME = "com.nanoai/mnn"
        const val STREAM_CHANNEL_NAME = "com.nanoai/mnn_events"
    }
    private val client = Any()
    @Volatile private var sink: EventChannel.EventSink? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "status" -> result.success(MnnRuntimeSupervisor.status(client))
            "cancel" -> result.success(MnnRuntimeSupervisor.cancel(call.argument<String>("requestId"), client))
            "load", "generate", "unload" -> {
            if (call.method == "generate") {
                try { MnnRuntimeSupervisor.admit(client,
                    call.argument<String>("requestId") ?: error("Falta requestId"))
                } catch (error: Exception) {
                    result.error("mnn_failed", error.message, null)
                    return
                }
            }
            ioScope.launch(Dispatchers.IO) {
                runCatching {
                    MnnRuntimeSupervisor.handle(client, call) { id, token ->
                        mainHandler.post { sink?.success(mapOf("requestId" to id, "token" to token)) }
                    }
                }.onSuccess { value -> mainHandler.post { result.success(value) } }
                    .onFailure { error -> mainHandler.post {
                        result.error("mnn_failed", error.message ?: "Fallo MNN", null)
                    } }
            }
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
    override fun onCancel(arguments: Any?) {
        sink = null
        MnnRuntimeSupervisor.cancel(null, client)
    }

    // El cierre tiene un scope propio: el scope de Activity/Service puede estar ya cancelado.
    fun close() {
        sink = null
        MnnRuntimeSupervisor.cancel(null, client)
        val closingScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        closingScope.launch {
            try { MnnRuntimeSupervisor.release(client) } finally { closingScope.cancel() }
        }
    }
}
