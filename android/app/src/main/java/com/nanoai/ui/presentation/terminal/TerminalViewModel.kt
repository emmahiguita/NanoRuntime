package com.nanoai.ui.presentation.terminal

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.nanoai.data.repository.TerminalRepository
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * TerminalViewModel implementing SOLID principles:
 * - Single Responsibility: Manages shell state, command execution, and autocomplete suggestion logic.
 * - Dependency Inversion: Depends on TerminalRepository abstraction.
 */
class TerminalViewModel(
    private val terminalRepository: TerminalRepository = TerminalRepository()
) : ViewModel() {

    private val _uiState = MutableStateFlow(TerminalUiState())
    val uiState: StateFlow<TerminalUiState> = _uiState.asStateFlow()

    init {
        // Sync initial lines from repository
        viewModelScope.launch {
            terminalRepository.lines.collect { lines ->
                _uiState.update { it.copy(lines = lines) }
            }
        }
        // Seed initial suggestions
        _uiState.update {
            it.copy(autoSuggestions = terminalRepository.availableCommands.take(4))
        }
    }

    fun onAction(action: TerminalUiAction) {
        when (action) {
            is TerminalUiAction.OnInputChanged -> handleInputChanged(action.newInput)
            is TerminalUiAction.ExecuteCommand -> executeCurrentCommand()
            is TerminalUiAction.SelectSuggestion -> handleSuggestionSelected(action.suggestion)
            is TerminalUiAction.ClearTerminal -> clearTerminal()
        }
    }

    private fun handleInputChanged(input: String) {
        val filteredSuggestions = if (input.isBlank()) {
            terminalRepository.availableCommands.take(4)
        } else {
            terminalRepository.availableCommands.filter { it.contains(input, ignoreCase = true) }
        }
        _uiState.update {
            it.copy(currentInput = input, autoSuggestions = filteredSuggestions)
        }
    }

    private fun handleSuggestionSelected(suggestion: String) {
        _uiState.update { it.copy(currentInput = suggestion) }
        executeCurrentCommand()
    }

    private fun executeCurrentCommand() {
        val command = _uiState.value.currentInput.trim()
        if (command.isEmpty()) return

        _uiState.update { it.copy(currentInput = "", isExecuting = true) }

        viewModelScope.launch {
            delay(200) // Simulate command dispatch latency
            terminalRepository.executeCommand(command)
            _uiState.update { it.copy(isExecuting = false) }
        }
    }

    private fun clearTerminal() {
        terminalRepository.clearLines()
        _uiState.update { it.copy(lines = emptyList(), currentInput = "") }
    }
}
