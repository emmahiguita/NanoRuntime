package dev.nanoai.mobile.channels

import android.os.SystemClock
import android.util.Log
import com.google.ai.edge.litertlm.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.collect

/**
 * Ejecutor de turnos conversacionales sobre LiteRT-LM con preservación real de KV-cache.
 *
 * - **QUÉ HACE:** Mantiene viva la sesión nativa `Conversation` en GPU entre turnos
 *   consecutivos del mismo chat para responder en ~1 segundo sin reprocesar el historial.
 * - **CÓMO FUNCIONA:** Extrae el mensaje limpio del usuario (`canonicalUserContent`,
 *   quitando el bloque efímero `<CONTEXTO DEL TURNO>`) y la respuesta principal del
 *   asistente (`canonicalAssistantContent`) para que `expectedHistory` coincida con
 *   el historial persistido en SQLite (`canReuseHistory`).
 * - **POR QUÉ:** Si se comparara el prompt crudo con `<CONTEXTO DEL TURNO>` contra el
 *   historial de SQLite, nunca coincidirían y se reconstruiría toda la sesión en cada turno.
 */
@OptIn(ExperimentalApi::class)
class LiteRtGeneration(private val owner: LiteRtEngineOwner) {
    internal data class Turn(val role: String, val content: String)

    companion object {
        private const val DISPATCHED_PREFIX = "[Mensaje despachado por Nano; entrega no verificada]\n"
        private const val CURRENT_MSG_INLINE = "Mensaje actual: "
        private const val CURRENT_MSG_BLOCK = "\nMensaje actual:\n"
        private val CONTEXT_BLOCK_REGEX =
            Regex("""^<CONTEXTO DEL TURNO[^>]*>[\s\S]*?</CONTEXTO DEL TURNO>\s*""")
        private val QUALITY_NOTE_REGEX =
            Regex("""\s*<NOTA_CALIDAD>[\s\S]*?</NOTA_CALIDAD>\s*$""")

        /** Extrae únicamente el mensaje real del usuario sin envoltorios del turno. */
        internal fun canonicalUserContent(raw: String): String {
            val withoutNote = raw.replace(QUALITY_NOTE_REGEX, "").replace(CONTEXT_BLOCK_REGEX, "").trim()
            val blockIdx = withoutNote.lastIndexOf(CURRENT_MSG_BLOCK)
            if (blockIdx >= 0) {
                return withoutNote.substring(blockIdx + CURRENT_MSG_BLOCK.length).trim()
            }
            if (withoutNote.startsWith(CURRENT_MSG_INLINE)) {
                return withoutNote.removePrefix(CURRENT_MSG_INLINE).trim()
            }
            val inlineIdx = withoutNote.lastIndexOf("\n$CURRENT_MSG_INLINE")
            if (inlineIdx >= 0) {
                return withoutNote.substring(inlineIdx + 1 + CURRENT_MSG_INLINE.length).trim()
            }
            return withoutNote
        }

        /** Normaliza la respuesta del asistente tomando la opción principal antes de `||`. */
        internal fun canonicalAssistantContent(raw: String): String =
            raw.removePrefix(DISPATCHED_PREFIX).substringBefore("||").trim()

        internal fun canonicalTurn(turn: Turn): Turn =
            if (turn.role == "user") Turn("user", canonicalUserContent(turn.content))
            else Turn("assistant", canonicalAssistantContent(turn.content))

        /**
         * Comprueba si el historial en GPU coincide con el historial válido de SQLite.
         */
        internal fun canReuseHistory(
            expected: List<Turn>,
            incoming: List<Turn>,
            forceReset: Boolean = false,
        ): Boolean {
            if (forceReset) return false
            val normExpected = expected.map(::canonicalTurn)
            val normIncoming = incoming.map(::canonicalTurn)
            if (normExpected == normIncoming) return true
            return normIncoming.isNotEmpty() &&
                normExpected.size > normIncoming.size &&
                normExpected.takeLast(normIncoming.size) == normIncoming
        }
    }

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

    /** Ejecuta la generación en streaming reutilizando el KV-cache cuando es válido. */
    suspend fun generate(
        args: Map<*, *>,
        emit: (Map<String, Any?>) -> Unit,
        onStarted: () -> Unit = {},
    ): Map<String, Any?> {
        val engine = checkNotNull(owner.engine) { "LiteRT no está inicializado" }
        val id = args["requestId"] as? String ?: error("Falta requestId")
        val prompt = (args["prompt"] as? String)?.takeIf { it.isNotBlank() } ?: error("Falta prompt")
        val incomingHistory = parseHistory(args["history"])
        val system = (args["context"] as? String)?.takeIf { it.isNotBlank() }
        val temperature = ((args["temperature"] as? Number)?.toDouble() ?: 0.3).coerceAtLeast(0.0)
        val topP = ((args["topP"] as? Number)?.toDouble() ?: 0.95).coerceIn(0.0, 1.0)
        val maxTokens = ((args["maxTokens"] as? Number)?.toInt() ?: 512).coerceIn(1, 4096)
        val forceReset = args["resetSession"] as? Boolean ?: false
        val budget = LiteRtContextBudget.fit(
            owner.modelPath, system, prompt, incomingHistory.map { it.role to it.content }, maxTokens,
        )
        val history = budget.history.map { Turn(it.first, it.second) }
        val key = (args["sessionId"] as? String)?.takeIf { it.isNotBlank() }
            ?.let { "$it|$temperature|$topP|$maxTokens" }
        val (current, reused) = obtainConversation(
            engine, key, history, system, temperature, topP, maxTokens, forceReset,
        )
        synchronized(lifecycleLock) {
            active = current
            activeCancelled = false
            requestId = id
        }
        val started = SystemClock.elapsedRealtime()
        var firstTokenMs: Long? = null
        val text = StringBuilder()
        var completed = false
        try {
            onStarted()
            check(!activeCancelled) { "LiteRT cancelado antes del prefill" }
            coroutineScope {
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
            check(!activeCancelled && text.isNotBlank()) { "LiteRT sin salida válida" }
            val benchmark = runCatching { current.getBenchmarkInfo() }.getOrNull()
            metrics = mapOf(
                "ttftMs" to firstTokenMs,
                "tokensPerSec" to benchmark?.lastDecodeTokensPerSecond,
                "totalTokens" to benchmark?.lastDecodeTokenCount,
                "durationMs" to (SystemClock.elapsedRealtime() - started),
                "activeBackend" to owner.backend,
                "conversationReused" to reused,
                "sessionRebuilt" to !reused,
                "kvTokensAfter" to runCatching { current.getTokenCount() }.getOrNull(),
            ) + budget.metrics
            synchronized(lifecycleLock) {
                if (!activeCancelled && conversation === current && key != null) {
                    expectedHistory = history.map(::canonicalTurn) +
                        Turn("user", canonicalUserContent(prompt)) +
                        Turn("assistant", canonicalAssistantContent(text.toString()))
                    completed = true
                    active = null
                    requestId = null
                }
            }
            Log.i("LiteRtChannel", "completed id=$id reused=$reused durationMs=${metrics["durationMs"]}")
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

    private fun obtainConversation(
        engine: Engine, key: String?, history: List<Turn>, system: String?,
        temperature: Double, topP: Double, maxTokens: Int, forceReset: Boolean,
    ): Pair<Conversation, Boolean> = synchronized(lifecycleLock) {
        val existing = conversation
        if (key != null && existing != null && conversationKey == key &&
            conversationSystem == system && canReuseHistory(expectedHistory, history, forceReset)
        ) {
            return@synchronized existing to true
        }
        closeConversationLocked()
        val cleanHistory = history.map(::canonicalTurn)
        val topK = if (owner.modelPath?.contains("qwen", ignoreCase = true) == true) 40 else 64
        val created = engine.createConversation(ConversationConfig(
            systemInstruction = system?.let { Contents.of(it) },
            initialMessages = cleanHistory.map {
                if (it.role == "user") Message.user(it.content) else Message.model(it.content)
            },
            samplerConfig = SamplerConfig(topK, topP, temperature),
            automaticToolCalling = false,
            maxOutputToken = maxTokens,
            thinkingConfig = ThinkingConfig(enableThinking = false),
        ))
        conversation = created
        conversationKey = key
        conversationSystem = system
        expectedHistory = cleanHistory
        created to false
    }

    private fun parseHistory(raw: Any?): List<Turn> = (raw as? List<*>)?.mapNotNull { value ->
        val row = value as? Map<*, *> ?: return@mapNotNull null
        val content = row["content"] as? String ?: return@mapNotNull null
        when (val role = row["role"]) {
            "user", "assistant", "model" -> Turn(if (role == "user") "user" else "assistant", content)
            else -> null
        }
    } ?: emptyList()

    fun cancel(id: String? = null): Boolean = synchronized(lifecycleLock) {
        if (id != null && id != requestId) return false
        val current = active ?: return false
        activeCancelled = true
        current.cancelProcess()
        true
    }

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
