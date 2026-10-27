package dev.nanoai.mobile.channels

import java.io.File

/** QUÉ: reserva salida antes de admitir historial en paquetes conocidos.
 * CÓMO: cota conservadora UTF-8 para el tokenizer byte-BPE de este Qwen3.
 * POR QUÉ: caracteres no son tokens. No declara esta cota como medición real
 * ni impone el límite de Qwen a Gemma, MNN o archivos desconocidos. */
internal object LiteRtContextBudget {
    private const val QWEN3 = "qwen3_0.6b_nothink_q4_block32_ekv1280.litertlm"
    // Fuente: litert-community/Qwen3-0.6B-int4, artefacto del catálogo con SHA.
    private const val KV_TOKENS = 1280
    private const val PREFILL_TOKENS = 1024
    private const val SPECIAL_RESERVE = 32

    data class Plan(val history: List<Pair<String, String>>, val metrics: Map<String, Any>)

    fun fit(
        modelPath: String?, system: String?, prompt: String,
        history: List<Pair<String, String>>, outputTokens: Int,
    ): Plan {
        if (modelPath == null || File(modelPath).name != QWEN3) {
            return Plan(history, emptyMap())
        }
        // Estimador de tokens, no bytes: el tokenizer byte-BPE de Qwen cubre
        // ~1.7 bytes/token en español (0.6 token/byte). Cota alta deliberada:
        // solo subestima con bytes aleatorios, nunca con texto de chat.
        fun tokens(text: String) =
            (text.toByteArray(Charsets.UTF_8).size * 0.6).toLong().coerceAtLeast(1L)
        // Solo se calcula el tamaño del envoltorio; NO se envía ChatML manual
        // a LiteRT. Conversation continúa aplicando la plantilla del paquete.
        fun framed(role: String, text: String) =
            tokens("<|im_start|>$role\n$text<|im_end|>\n")
        val allowance = minOf(PREFILL_TOKENS, KV_TOKENS - outputTokens) - SPECIAL_RESERVE
        val required = (system?.let { framed("system", it) } ?: 0L) +
            framed("user", prompt) + tokens("<|im_start|>assistant\n<think>\n\n</think>\n\n")
        require(allowance > 0 && required <= allowance.toLong()) {
            "CONTEXT_CAPACITY_EXCEEDED: entrada obligatoria no cabe en Qwen3; " +
                "reduce contexto o usa un paquete de mayor capacidad"
        }
        // Una pasada: evita recalcular o truncar párrafos durante cada descarte.
        val costs = history.map { framed(it.first, it.second) }
        var upperBound = required + costs.sum()
        var first = 0
        while (upperBound > allowance && first < history.size) {
            upperBound -= costs[first++]
        }
        return Plan(history.drop(first), mapOf(
            "contextCapacity" to KV_TOKENS,
            "inputTokensUpperBound" to upperBound,
            "outputReserved" to outputTokens,
            "historyDropped" to first,
            "budgetKind" to "qwen_byte_bpe_token_estimate_0_6",
        ))
    }
}
