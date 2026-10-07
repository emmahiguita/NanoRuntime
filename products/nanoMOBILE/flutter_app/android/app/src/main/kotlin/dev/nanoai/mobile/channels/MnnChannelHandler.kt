package dev.nanoai.mobile.channels

import android.os.Handler
import android.os.Looper
import dev.nanoai.mobile.mnn.MnnNative
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONObject
import java.io.File
import java.util.concurrent.atomic.AtomicReference

/** Keeps model memory under one owner and serializes load, generation and unload. */
class MnnChannelHandler(
    private val ioScope: CoroutineScope,
    private val mainHandler: Handler,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    companion object {
        const val METHOD_CHANNEL_NAME = "com.nanoai/mnn"
        const val STREAM_CHANNEL_NAME = "com.nanoai/mnn_events"
    }

    private val owner = MnnEngineOwner()
    private var sink: EventChannel.EventSink? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "load", "generate", "unload" -> ioScope.launch(Dispatchers.IO) {
                runCatching { owner.handle(call) }
                    .onSuccess { value -> mainHandler.post { result.success(value) } }
                    .onFailure { error -> mainHandler.post {
                        result.error("mnn_failed", error.message ?: "Fallo MNN", null)
                    } }
            }
            "cancel" -> result.success(owner.cancel(call.argument<String>("requestId")))
            else -> result.notImplemented()
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) { sink = events }

    override fun onCancel(arguments: Any?) {
        sink = null
        owner.cancel(null)
    }

    /** Unload asynchronously because Activity destruction must not wait on native decode. */
    fun close() {
        sink = null
        // Solicita el fin antes de esperar al mutex que mantiene el decodificador.
        owner.cancel(null)
        val closingScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        closingScope.launch { owner.unload(); closingScope.cancel() }
    }

    private inner class MnnEngineOwner {
        private val gate = Mutex()
        private val activeRequest = AtomicReference<String?>(null)
        private val cancelBeforeNativeStart = java.util.concurrent.atomic.AtomicBoolean(false)
        private var loadedPath: String? = null

        suspend fun handle(call: MethodCall): Any {
            // Unload no debe aguardar hasta que se agoten todos los tokens.
            if (call.method == "unload") cancel(null)
            return gate.withLock {
                when (call.method) {
                    "load" -> load(call.argument<String>("modelPath") ?: error("Falta modelPath"))
                    "generate" -> generate(call)
                    else -> unloadUnlocked()
                }
            }
        }

        private fun load(path: String): Boolean {
            check(File(path, "llm_config.json").isFile || File(path, "config.json").isFile) {
                "Falta la configuración (llm_config.json / config.json) del paquete MNN"
            }
            loadedPath = null
            check(MnnNative.unload()) { "No se pudo liberar el modelo anterior" }
            check(MnnNative.load(path)) { "MNN no pudo cargar Qwen Omni" }
            loadedPath = path
            return true
        }

        private fun generate(call: MethodCall): Map<String, Any> {
            check(loadedPath != null) { "No hay un modelo MNN cargado" }
            val id = call.argument<String>("requestId") ?: error("Falta requestId")
            cancelBeforeNativeStart.set(false)
            check(activeRequest.compareAndSet(null, id)) { "MNN ya está generando" }
            return try {
                val prompt = call.argument<String>("prompt") ?: error("Falta prompt")
                val maxTokens = (call.argument<Int>("maxTokens") ?: 256).coerceIn(1, 2048)
                // Limita los controles al rango aceptado por el muestreador MNN.
                val temperature = (call.argument<Double>("temperature") ?: 0.7).coerceIn(0.05, 1.5)
                val topP = (call.argument<Double>("topP") ?: 0.9).coerceIn(0.1, 1.0)
                MnnNative.prepareGeneration()
                // Atiende cancel si llegó mientras JNI estaba preparando este request.
                if (cancelBeforeNativeStart.get()) return mapOf("generated_tokens" to 0)
                val metrics = MnnNative.generate(prompt, maxTokens, temperature, topP) { token ->
                    mainHandler.post { sink?.success(mapOf("requestId" to id, "token" to token)) }
                }
                JSONObject(metrics).let { json ->
                    mapOf("ttft_ms" to json.optLong("ttft_ms"),
                        "decode_tok_s" to json.optDouble("decode_tok_s"),
                        "generated_tokens" to json.optInt("generated_tokens"))
                }
            } finally {
                activeRequest.compareAndSet(id, null)
            }
        }

        fun cancel(id: String?): Boolean {
            if (id != null && activeRequest.get() != id) return false
            if (activeRequest.get() == null) return false
            cancelBeforeNativeStart.set(true)
            MnnNative.cancel()
            return true
        }

        suspend fun unload(): Boolean = gate.withLock { unloadUnlocked() }

        private fun unloadUnlocked(): Boolean {
            if (activeRequest.get() != null) {
                MnnNative.cancel()
            }
            val unloaded = MnnNative.unload()
            if (unloaded) {
                activeRequest.set(null)
                loadedPath = null
            }
            return unloaded
        }
    }
}
