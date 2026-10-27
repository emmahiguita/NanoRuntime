package dev.nanoai.mobile.runtime

import dev.nanoai.mobile.mnn.MnnNative
import io.flutter.plugin.common.MethodCall
import kotlinx.coroutines.sync.withLock
import org.json.JSONObject
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean

/** QUÉ: dueño único del MNN JNI para UI y servicio sin pantalla.
 * CÓMO: leases por consumidor y misma barrera que LiteRT; cancel alcanza requests en cola.
 * POR QUÉ: un cierre de Activity no debe liberar pesos utilizados por otro engine Flutter. */
object MnnRuntimeSupervisor {
    private class Request(val client: Any, val cancelled: AtomicBoolean = AtomicBoolean(false))
    private val clients = ConcurrentHashMap.newKeySet<Any>()
    private val requests = ConcurrentHashMap<String, Request>()
    @Volatile private var loadedPath: String? = null
    @Volatile private var activeId: String? = null
    private var nativeTouched = false
    private var conversationSession: String? = null

    // Un modelo cargado para otro consumidor no demuestra que este conserve su lease.
    fun status(client: Any): Map<String, Any?> = mapOf(
        "loaded" to (loadedPath != null && client in clients), "modelPath" to loadedPath)

    // Admisión síncrona en el canal: cancelar funciona incluso antes del despacho IO.
    fun admit(client: Any, id: String) {
        check(requests.putIfAbsent(id, Request(client)) == null) { "requestId MNN repetido" }
    }

    suspend fun handle(client: Any, call: MethodCall, emit: (String, String) -> Unit): Any {
        return when (call.method) {
            "load" -> {
                val path = File(call.argument<String>("modelPath") ?: error("Falta modelPath")).canonicalPath
                LocalModelGate.cancelForReplacement("mnn", path)
                LocalModelGate.mutex.withLock { loadLocked(client, path) }
            }
            "generate" -> generate(client, call, emit)
            "trimMemory" -> trimMemory()
            else -> release(client)
        }
    }

    // Carga idempotente de un paquete real, sin reemplazar JNI si otro consumidor ya lo cargó.
    private fun loadLocked(client: Any, path: String): Boolean {
        check(File(path, "llm_config.json").isFile || File(path, "config.json").isFile) {
            "Falta la configuración del paquete MNN"
        }
        InferenceThermalGuard.checkAdmission()
        LocalModelGate.claimLocked("mnn", path, ::closeLocked, ::cancelAll)
        if (loadedPath != path) {
            closeLocked()
            try {
                nativeTouched = true
                check(MnnNative.load(path)) { "MNN no pudo cargar el paquete" }
                loadedPath = path
            } catch (error: Throwable) {
                closeLocked()
                LocalModelGate.releaseLocked("mnn")
                throw error
            }
        }
        clients.add(client)
        return true
    }

    private suspend fun generate(client: Any, call: MethodCall, emit: (String, String) -> Unit): Map<String, Any> {
        val id = call.argument<String>("requestId") ?: error("Falta requestId")
        val request = requests[id] ?: error("MNN request no admitido")
        check(request.client === client) { "MNN request de otro consumidor" }
        try {
            return LocalModelGate.mutex.withLock {
                check(!request.cancelled.get()) { "MNN request cancelado antes de iniciar" }
                check(loadedPath != null && client in clients) { "MNN descargado: vuelve a asegurar el motor" }
                activeId = id
                try {
                    MnnNative.prepareGeneration()
                    val session = call.argument<String>("sessionId")?.takeIf { it.isNotBlank() }
                    if (session == null || session != conversationSession) {
                        MnnNative.resetConversation()
                    }
                    conversationSession = session
                    check(!request.cancelled.get()) { "MNN request cancelado" }
                    InferenceThermalGuard.protect({ cancel(id, client) }) {
                        // Mensajes estructurados (system + historial + turno):
                        // el nativo renderiza la plantilla jinja del modelo.
                        val history = StringBuilder()
                        (call.argument<List<*>>("history") ?: emptyList<Any?>())
                            .forEach { row ->
                                val turn = row as? Map<*, *> ?: return@forEach
                                val role = (turn["role"] as? String)?.takeIf {
                                    it == "user" || it == "assistant"
                                } ?: return@forEach
                                history.append(role).append('\u0001')
                                    .append((turn["content"] as? String) ?: "")
                                    .append('\u0002')
                            }
                        val json = JSONObject(MnnNative.generate(
                            call.argument<String>("system") ?: "",
                            history.toString(),
                            call.argument<String>("prompt") ?: error("Falta prompt"),
                            (call.argument<Int>("maxTokens") ?: 256).coerceIn(1, 2048),
                            (call.argument<Double>("temperature") ?: 0.7).coerceIn(0.05, 1.5),
                            (call.argument<Double>("topP") ?: 0.9).coerceIn(0.1, 1.0),
                        ) { token -> if (!request.cancelled.get()) emit(id, token) })
                        check(!request.cancelled.get()) { "MNN generación cancelada" }
                        mapOf("ttft_ms" to json.optLong("ttft_ms"),
                            "cache_reused" to json.optBoolean("cache_reused"),
                            "prefill_tokens" to json.optInt("prefill_tokens"),
                            "decode_tok_s" to json.optDouble("decode_tok_s"),
                            "prefill_ms" to json.optLong("prefill_ms"),
                            "generated_tokens" to json.optInt("generated_tokens"))
                    }
                } finally { activeId = null }
            }
        } finally { requests.remove(id, request) }
    }

    // No toma mutex: la inferencia lo retiene. La señal nativa es atómica, no un cierre inseguro.
    fun cancel(id: String?, client: Any): Boolean {
        var cancelled = false
        for ((key, request) in requests) {
            if (request.client === client && (id == null || id == key)) {
                request.cancelled.set(true)
                if (activeId == key) MnnNative.cancel()
                cancelled = true
            }
        }
        return cancelled
    }

    private fun cancelAll() {
        requests.values.forEach { it.cancelled.set(true) }
        if (activeId != null) MnnNative.cancel()
    }

    /** Libera pesos ociosos bajo presión antes de abrir el transporte externo.
     * Se ejecuta después del borrador completo, nunca entre generación y retry.
     * CPH2557: WhatsApp murió tras RemoteInput con ~500 MiB disponibles y
     * MNN reteniendo ~4.5 GiB PSS. La siguiente inferencia revalida y recarga. */
    private suspend fun trimMemory(): Boolean = LocalModelGate.mutex.withLock {
        if (loadedPath == null || requests.isNotEmpty()) return@withLock false
        val availableKb = runCatching {
            File("/proc/meminfo").useLines { lines ->
                lines.firstOrNull { it.startsWith("MemAvailable:") }
                    ?.substringAfter(':')?.trim()?.substringBefore(' ')?.toLongOrNull()
            }
        }.getOrNull() ?: return@withLock false
        // Reserva 1 GiB para el receptor y sus servicios en este flujo externo.
        if (availableKb >= 1024L * 1024L) return@withLock false
        closeLocked()
        LocalModelGate.releaseLocked("mnn")
        android.util.Log.i("NanoMnnMemory", "idle runtime released before external dispatch; availableKb=$availableKb")
        true
    }

    suspend fun release(client: Any): Boolean {
        cancel(null, client)
        return LocalModelGate.mutex.withLock {
            clients.remove(client)
            for ((id, request) in requests) if (request.client === client) {
                requests.remove(id, request)
            }
            if (clients.isEmpty()) {
                closeLocked()
                LocalModelGate.releaseLocked("mnn")
            }
            true
        }
    }

    // Bajo la barrera común y después del decoder: nunca libera buffers activos.
    private fun closeLocked() {
        // No toca librerías MNN cuando Nano utilizó únicamente LiteRT.
        if (nativeTouched) check(MnnNative.unload()) { "MNN no confirmó la liberación" }
        nativeTouched = false
        conversationSession = null
        loadedPath = null
        clients.clear()
    }
}
