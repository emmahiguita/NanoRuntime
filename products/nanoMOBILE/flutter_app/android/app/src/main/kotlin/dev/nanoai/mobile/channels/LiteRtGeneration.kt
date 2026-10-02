package dev.nanoai.mobile.channels

import android.os.SystemClock
import android.util.Log
import com.google.ai.edge.litertlm.*
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.*

// Usa el historial autorizado de Dart por turno: no cruza memoria entre contactos.
// Nano conserva su protocolo y confirmaciones de herramientas; JNI no ejecuta acciones.
@OptIn(ExperimentalApi::class)
internal class LiteRtGeneration(private val owner: LiteRtEngineOwner) {
    // Protege cancelar/cerrar la misma conversación JNI; nunca se toma desde UI.
    private val lifecycleLock = Any()
    @Volatile private var active: Conversation? = null
    @Volatile var requestId: String? = null
        private set
    @Volatile var metrics: Map<String, Any?> = emptyMap()
        private set

    suspend fun generate(args: Map<*, *>, emit: (Map<String, Any?>) -> Unit): Map<String, Any?> {
        val engine = checkNotNull(owner.engine) { "LiteRT no está inicializado" }
        val id = args["requestId"] as? String ?: error("Falta requestId")
        val prompt = args["prompt"] as? String ?: error("Falta prompt")
        require(prompt.isNotBlank()) { "El mensaje está vacío" }
        val history = (args["history"] as? List<*>)?.mapNotNull { value ->
            val row = value as? Map<*, *> ?: return@mapNotNull null
            val content = row["content"] as? String ?: return@mapNotNull null
            when (row["role"]) {
                "user" -> Message.user(content)
                "assistant", "model" -> Message.model(content)
                else -> null
            }
        } ?: emptyList()
        val system = (args["context"] as? String)?.takeIf { it.isNotBlank() }
        val conversation = engine.createConversation(ConversationConfig(
            systemInstruction = system?.let { Contents.of(it) },
            initialMessages = history,
            samplerConfig = SamplerConfig(64,
                ((args["topP"] as? Number)?.toDouble() ?: 0.95).coerceIn(0.0, 1.0),
                ((args["temperature"] as? Number)?.toDouble() ?: 0.3).coerceAtLeast(0.0)),
            automaticToolCalling = false,
            maxOutputToken = ((args["maxTokens"] as? Number)?.toInt() ?: 512).coerceIn(1, 4096),
            thinkingConfig = ThinkingConfig(enableThinking = false),
        ))
        synchronized(lifecycleLock) {
            active = conversation
            requestId = id
        }
        val started = SystemClock.elapsedRealtime()
        // Solo IDs y tamaños: diagnostica contexto/latencia sin copiar conversaciones al log.
        Log.i("LiteRtChannel", "generate id=$id history="+history.size+" promptChars="+prompt.length)
        var firstTokenMs: Long? = null
        val text = StringBuilder()
        try {
            coroutineScope {
              // Progreso de una llamada real: mantiene vivo el stream durante prefill largo.
              val heartbeat = launch {
                while (isActive) {
                  delay(5000)
                  emit(mapOf("requestId" to id, "content" to "", "stop" to false, "phase" to "generating"))
                }
              }
              try { conversation.sendMessageAsync(prompt).collect { message ->
                // Message 0.17.1 expone el contenido textual mediante toString, no text.
                val chunk = message.toString()
                if (chunk.isNotEmpty()) {
                    if (firstTokenMs == null) firstTokenMs = SystemClock.elapsedRealtime() - started
                    text.append(chunk)
                    emit(mapOf("requestId" to id, "content" to chunk, "stop" to false))
                }
              } } finally { heartbeat.cancelAndJoin() }
            }
            check(text.isNotBlank()) { "El modelo terminó sin emitir texto" }
            val benchmark = runCatching { conversation.getBenchmarkInfo() }.getOrNull()
            metrics = mapOf("ttftMs" to firstTokenMs,
                "tokensPerSec" to benchmark?.lastDecodeTokensPerSecond,
                "totalTokens" to benchmark?.lastDecodeTokenCount,
                "durationMs" to (SystemClock.elapsedRealtime() - started),
                "activeBackend" to owner.backend)
            Log.i("LiteRtChannel", "completed id=$id metrics=$metrics")
            emit(metrics + mapOf("requestId" to id, "content" to "", "stop" to true))
            return metrics + mapOf("text" to text.toString())
        } finally {
            // También corta JNI si Android cancela la corrutina al destruir la Activity.
            synchronized(lifecycleLock) {
                runCatching { conversation.cancelProcess() }
                active = null
                requestId = null
                conversation.close()
            }
        }
    }

    // El ID evita que cancelar un turno antiguo interrumpa la siguiente conversación.
    fun cancel(id: String? = null): Boolean = synchronized(lifecycleLock) {
        if (id != null && id != requestId) return false
        val conversation = active ?: return false
        conversation.cancelProcess()
        true
    }
}
