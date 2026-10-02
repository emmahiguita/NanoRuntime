package dev.nanoai.mobile.channels

import android.content.Context
import android.os.Handler
import android.util.Log
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.io.File

// Puente LiteRT real: serializa carga, generación y cierre en IO, nunca en el hilo visual.
class LiteRtChannelHandler(
    context: Context,
    private val ioScope: CoroutineScope,
    private val mainHandler: Handler,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        const val METHOD_CHANNEL_NAME = "com.nanoai/litert"
        const val STREAM_CHANNEL_NAME = "com.nanoai/litert_stream"
    }
    private val owner = LiteRtEngineOwner(context)
    private val generation = LiteRtGeneration(owner)
    private val mutex = Mutex()
    private var sink: EventChannel.EventSink? = null
    @Volatile private var closing = false

    init {
        // El scope ya terminó sus hijos; liberar JNI en IO evita bloquear onDestroy.
        // Este trabajo finito no depende del scope de Activity que ya fue cancelado.
        ioScope.coroutineContext[Job]?.invokeOnCompletion {
            CoroutineScope(Dispatchers.IO).launch { runCatching { owner.close() } }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(mapOf("supported" to true,
                "hasGpuOpenCl" to listOf("/vendor/lib64/libOpenCL.so", "/system/lib64/libOpenCL.so")
                    .any { File(it).exists() }))
            "cancel" -> cancelAsync(call.argument<String>("requestId"), result)
            "getMetrics" -> result.success(generation.metrics)
            "initialize", "release", "generate" -> {
                if (call.method != "generate") {
                    closing = true
                }
                ioScope.launch(Dispatchers.IO) {
                    try {
                        // Cancelar no espera al mutex de generación: debe poder interrumpirla.
                        if (call.method != "generate") runCatching { generation.cancel() }
                        val response = mutex.withLock {
                            when (call.method) {
                                "initialize" -> owner.initialize(
                                    call.argument<String>("modelPath") ?: error("Falta modelPath"),
                                    call.argument<String>("backend") ?: "cpu"
                                ).also { closing = false }
                                "release" -> { owner.close(); closing = false; true }
                                else -> {
                                    check(!closing) { "El motor está cambiando de modelo" }
                                    generation.generate(call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()) {
                                        event -> mainHandler.post { sink?.success(event) }
                                    }
                                }
                            }
                        }
                        mainHandler.post { result.success(response) }
                    } catch (error: Exception) {
                        val id = call.argument<String>("requestId")
                        Log.e("LiteRtChannel", "Fallo " + call.method, error)
                        mainHandler.post {
                            if (id != null) sink?.success(mapOf("requestId" to id,
                                "error" to (error.message ?: "Fallo LiteRT"), "stop" to true))
                            result.error("litert_failed", error.message, null)
                        }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }
    override fun onCancel(arguments: Any?) {
        sink = null
        // Captura el turno al desconectar: una tarea tardía no cancela el siguiente.
        generation.requestId?.let { cancelAsync(it) }
    }

    // cancelProcess es JNI potencialmente bloqueante; solo la respuesta vuelve a UI.
    private fun cancelAsync(id: String?, result: MethodChannel.Result? = null) {
        ioScope.launch(Dispatchers.IO) {
            val cancelled = runCatching { generation.cancel(id) }.getOrDefault(false)
            if (result != null) mainHandler.post { result.success(cancelled) }
        }
    }
}
