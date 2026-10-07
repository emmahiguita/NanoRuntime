package dev.nanoai.mobile.channels

import android.os.SystemClock
import android.util.Log
import com.google.ai.edge.litertlm.*
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.*

// QUÉ HACE: Ejecuta turnos reales y conserva el KV mientras el historial coincide.
// CÓMO FUNCIONA: Reutiliza Conversation; cancelación o divergencia obligan a reconstruirla.
// POR QUÉ: Evita reprocesar todo el chat sin mezclar sesiones ni conservar un KV dudoso.
@OptIn(ExperimentalApi::class)
class LiteRtGeneration(private val owner: LiteRtEngineOwner) {
    private data class Turn(val role: String, val content: String)

    // Protege referencias JNI que cancel() también toca desde otra corrutina.
    private val lifecycleLock = Any()
    private var conversation: Conversation? = null
    private var conversationKey: String? = null
    private var conversationSystem: String? = null
    private var expectedHistory: List<Turn> = emptyList()
    @Volatile private var active: Conversation? = null
    @Volatile private var activeCancelled = false
    @Volatile var requestId: String? = null
        private set
    @Volatile var metrics: Map<String, Any?> = emptyMap()
        private set

    suspend fun generate(args: Map<*, *>, emit: (Map<String, Any?>) -> Unit): Map<String, Any?> {
        val engine = checkNotNull(owner.engine) { "LiteRT no está inicializado" }
        val id = args["requestId"] as? String ?: error("Falta requestId")
        val prompt = args["prompt"] as? String ?: error("Falta prompt")
        require(prompt.isNotBlank()) { "El mensaje está vacío" }
        val history = parseHistory(args["history"])
        val system = (args["context"] as? String)?.takeIf { it.isNotBlank() }
        val temperature = ((args["temperature"] as? Number)?.toDouble() ?: 0.3).coerceAtLeast(0.0)
        val topP = ((args["topP"] as? Number)?.toDouble() ?: 0.95).coerceIn(0.0, 1.0)
        val maxTokens = ((args["maxTokens"] as? Number)?.toInt() ?: 512).coerceIn(1, 4096)
        val session = (args["sessionId"] as? String)?.takeIf { it.isNotBlank() }
        val key = session?.let { "$it|$temperature|$topP|$maxTokens" }
        val (current, reused) = obtainConversation(
            engine, key, history, system, temperature, topP, maxTokens,
        )
        synchronized(lifecycleLock) {
            active = current
            activeCancelled = false
            requestId = id
        }

        val started = SystemClock.elapsedRealtime()
        Log.i("LiteRtChannel", "generate id=$id reused=$reused history=${history.size} promptChars=${prompt.length}")
        var firstTokenMs: Long? = null
        val text = StringBuilder()
        var completed = false
        try {
            coroutineScope {
                // Latido de progreso real durante un prefill largo; no altera el timeout total.
                val heartbeat = launch {
                    while (isActive) {
                        delay(5000)
                        emit(mapOf("requestId" to id, "content" to "", "stop" to false, "phase" to "generating"))
                    }
                }
                try {
                    current.sendMessageAsync(prompt).collect { message ->
                        val chunk = message.toString()
                        if (chunk.isNotEmpty()) {
                            if (firstTokenMs == null) firstTokenMs = SystemClock.elapsedRealtime() - started
                            text.append(chunk)
                            emit(mapOf("requestId" to id, "content" to chunk, "stop" to false))
                        }
                    }
                } finally { heartbeat.cancelAndJoin() }
            }
            check(text.isNotBlank()) { "El modelo terminó sin emitir texto" }
            val benchmark = runCatching { current.getBenchmarkInfo() }.getOrNull()
            metrics = mapOf(
                "ttftMs" to firstTokenMs,
                "tokensPerSec" to benchmark?.lastDecodeTokensPerSecond,
                "totalTokens" to benchmark?.lastDecodeTokenCount,
                "durationMs" to (SystemClock.elapsedRealtime() - started),
                "activeBackend" to owner.backend,
                "conversationReused" to reused,
            )
            synchronized(lifecycleLock) {
                if (!activeCancelled && conversation === current && key != null) {
                    expectedHistory = history + Turn("user", prompt) + Turn("assistant", text.toString())
                    completed = true
                    // El turno ya terminó: onCancel del EventChannel no debe invalidar este KV sano.
                    active = null
                    requestId = null
                }
            }
            Log.i("LiteRtChannel", "completed id=$id metrics=$metrics")
            emit(metrics + mapOf("requestId" to id, "content" to "", "stop" to true))
            return metrics + mapOf("text" to text.toString())
        } finally {
            synchronized(lifecycleLock) {
                if (active === current) active = null
                if (requestId == id) requestId = null
                if (!completed) closeConversationLocked(current)
            }
        }
    }

    // Reusa solo cuando el historial recibido es exactamente el que dejó el turno anterior.
    private fun obtainConversation(
        engine: Engine,
        key: String?,
        history: List<Turn>,
        system: String?,
        temperature: Double,
        topP: Double,
        maxTokens: Int,
    ): Pair<Conversation, Boolean> = synchronized(lifecycleLock) {
        val existing = conversation
        // El contexto forma parte del KV: cambiar instrucciones requiere otra conversación.
        if (key != null && existing != null && conversationKey == key &&
            conversationSystem == system && expectedHistory == history) {
            return@synchronized existing to true
        }
        closeConversationLocked()
        val created = engine.createConversation(ConversationConfig(
            systemInstruction = system?.let { Contents.of(it) },
            initialMessages = history.map {
                if (it.role == "user") Message.user(it.content) else Message.model(it.content)
            },
            samplerConfig = SamplerConfig(recommendedTopK(), topP, temperature),
            automaticToolCalling = false,
            maxOutputToken = maxTokens,
            thinkingConfig = ThinkingConfig(enableThinking = false),
        ))
        conversation = created
        conversationKey = key
        conversationSystem = system
        expectedHistory = history
        created to false
    }

    // Qwen publica topK=40; Gemma conserva 64, validado por su configuración.
    private fun recommendedTopK(): Int =
        if (owner.modelPath?.contains("qwen", ignoreCase = true) == true) 40 else 64

    private fun parseHistory(raw: Any?): List<Turn> = (raw as? List<*>)?.mapNotNull { value ->
        val row = value as? Map<*, *> ?: return@mapNotNull null
        val content = row["content"] as? String ?: return@mapNotNull null
        when (val role = row["role"]) {
            "user", "assistant", "model" ->
                Turn(if (role == "user") "user" else "assistant", content)
            else -> null
        }
    } ?: emptyList()

    // Cancelar invalida el KV; finally lo cierra antes de aceptar otro turno.
    fun cancel(id: String? = null): Boolean = synchronized(lifecycleLock) {
        if (id != null && id != requestId) return false
        val current = active ?: return false
        activeCancelled = true
        current.cancelProcess()
        true
    }

    // Cierra la conversación antes de liberar o reemplazar el Engine propietario.
    fun close() = synchronized(lifecycleLock) {
        active?.let { runCatching { it.cancelProcess() } }
        closeConversationLocked()
        active = null
        requestId = null
    }

    private fun closeConversationLocked(target: Conversation? = conversation) {
        if (target == null) return
        if (conversation === target) {
            conversation = null
            conversationKey = null
            conversationSystem = null
            expectedHistory = emptyList()
        }
        runCatching { target.close() }
    }
}
