package com.nanoai.ui.presentation.chat

/**
 * ── Message Status Enum ──
 */
enum class MessageSender { USER, AI, SYSTEM }
enum class MessageStatus { SENDING, SENT, ERROR }

/**
 * ── Tool Call Detail ──
 */
data class ToolCall(
    val name: String,
    val argumentsJson: String,
    val resultOutput: String
)

/**
 * ── Content types for rich messages ──
 */
enum class ContentType { TEXT, CODE, MARKDOWN }

data class MessageContent(
    val text: String,
    val type: ContentType = ContentType.TEXT,
    val language: String? = null // e.g. "kotlin", "python"
)

/**
 * ── Chat Message Entity ──
 */
data class ChatMessage(
    val id: String,
    val sender: MessageSender,
    val contents: List<MessageContent> = emptyList(),
    val timestamp: Long = System.currentTimeMillis(),
    val tokensPerSecond: Float? = null,
    val toolCall: ToolCall? = null,
    val status: MessageStatus = MessageStatus.SENT,
    // Convenience: single text content
    val text: String = ""
) {
    val isUser: Boolean get() = sender == MessageSender.USER
    val displayText: String get() = if (contents.isEmpty()) text else contents.joinToString("") { it.text }
}

/**
 * ── Connection State ──
 */
enum class ConnectionState {
    READY,          // Model loaded, ready for inference
    LOADING_MODEL,  // Switching/loading model
    NO_MODEL,       // No model selected
    ERROR           // Inference error
}

/**
 * ── MVI State ──
 */
data class ChatUiState(
    val messages: List<ChatMessage> = emptyList(),
    val currentInput: String = "",
    val isGenerating: Boolean = false,
    val activeModelName: String = "Sin modelo",
    val connectionState: ConnectionState = ConnectionState.NO_MODEL,
    val availableModels: List<String> = emptyList(),
    val quickSuggestions: List<String> = listOf(
        "¿Qué modelos tengo disponibles?",
        "Explica cómo funciona NanoRuntime",
        "Escribe una función en Kotlin",
        "¿Cuál es el estado del sistema?"
    ),
    val characterLimit: Int = 4096,
    val showModelSelector: Boolean = false
)

/**
 * ── MVI Actions ──
 */
sealed interface ChatUiAction {
    data class OnInputChanged(val newInput: String) : ChatUiAction
    object SendMessage : ChatUiAction
    object StopGeneration : ChatUiAction
    object ClearChat : ChatUiAction
    data class RetryMessage(val messageId: String) : ChatUiAction
    data class DeleteMessage(val messageId: String) : ChatUiAction
    data class CopyMessage(val text: String) : ChatUiAction
    data class SelectModel(val modelName: String) : ChatUiAction
    object ToggleModelSelector : ChatUiAction
    data class QuickSuggestion(val text: String) : ChatUiAction
}
