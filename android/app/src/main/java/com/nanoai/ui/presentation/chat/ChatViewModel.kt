package com.nanoai.ui.presentation.chat

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.nanoai.data.repository.ChatRepository
import com.nanoai.data.repository.ModelRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

class ChatViewModel(
    private val chatRepository: ChatRepository = ChatRepository(),
    private val modelRepository: ModelRepository = ModelRepository()
) : ViewModel() {

    private val _uiState = MutableStateFlow(ChatUiState())
    val uiState: StateFlow<ChatUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            chatRepository.messages.collect { msgs ->
                _uiState.update { it.copy(messages = msgs) }
            }
        }
        viewModelScope.launch {
            modelRepository.models.collect { models ->
                val active = models.firstOrNull { it.isActive }
                val names = models.filter { it.isDownloaded }.map { it.name.replace(".gguf", "") }
                _uiState.update {
                    it.copy(
                        activeModelName = active?.name?.replace(".gguf", "") ?: "Sin modelo",
                        connectionState = if (active != null) ConnectionState.READY else ConnectionState.NO_MODEL,
                        availableModels = names
                    )
                }
            }
        }
    }

    fun onAction(action: ChatUiAction) {
        when (action) {
            is ChatUiAction.OnInputChanged -> _uiState.update { it.copy(currentInput = action.newInput) }
            is ChatUiAction.SendMessage -> sendMessage()
            is ChatUiAction.StopGeneration -> _uiState.update { it.copy(isGenerating = false) }
            is ChatUiAction.ClearChat -> {
                chatRepository.clearMessages()
                _uiState.update { it.copy(messages = emptyList()) }
            }
            is ChatUiAction.RetryMessage -> retryMessage(action.messageId)
            is ChatUiAction.DeleteMessage -> deleteMessage(action.messageId)
            is ChatUiAction.CopyMessage -> { /* handled by platform clipboard */ }
            is ChatUiAction.SelectModel -> selectModel(action.modelName)
            is ChatUiAction.ToggleModelSelector -> _uiState.update { it.copy(showModelSelector = !it.showModelSelector) }
            is ChatUiAction.QuickSuggestion -> {
                _uiState.update { it.copy(currentInput = action.text) }
                sendMessage()
            }
        }
    }

    private fun sendMessage() {
        val input = _uiState.value.currentInput.trim()
        if (input.isEmpty() || _uiState.value.isGenerating) return
        if (_uiState.value.connectionState != ConnectionState.READY) return

        val modelPath = modelRepository.getActiveModelPath() ?: ""
        chatRepository.addUserMessage(input)
        _uiState.update { it.copy(currentInput = "", isGenerating = true) }

        viewModelScope.launch {
            val fullResponse = StringBuilder()
            try {
                chatRepository.generateStream(input, modelPath).collect { token ->
                    if (_uiState.value.isGenerating) fullResponse.append(token)
                }
                chatRepository.appendAssistantMessage(text = fullResponse.toString().trim(), tps = 14f)
            } catch (e: Exception) {
                chatRepository.appendAssistantMessage(
                    text = "[Error: ${e.localizedMessage}]", tps = 0f
                )
            } finally {
                _uiState.update { it.copy(isGenerating = false) }
            }
        }
    }

    private fun retryMessage(messageId: String) {
        val msg = _uiState.value.messages.find { it.id == messageId } ?: return
        deleteMessage(messageId)
        _uiState.update { it.copy(currentInput = msg.displayText) }
        sendMessage()
    }

    private fun deleteMessage(messageId: String) {
        chatRepository.removeMessage(messageId)
    }

    private fun selectModel(modelName: String) {
        val model = modelRepository.models.value.find {
            it.name.replace(".gguf", "") == modelName && it.isDownloaded
        }
        if (model != null) {
            _uiState.update { it.copy(connectionState = ConnectionState.LOADING_MODEL, showModelSelector = false) }
            modelRepository.setActiveModel(model.id)
            viewModelScope.launch {
                kotlinx.coroutines.delay(800) // simulate model load time
                _uiState.update {
                    it.copy(activeModelName = modelName, connectionState = ConnectionState.READY)
                }
            }
        }
    }
}
