package com.nanoai.ui.presentation.terminal

/**
 * Terminal UI Line Model representing output logs, command responses, and system outputs.
 */
data class TerminalLine(
    val id: String,
    val text: String,
    val type: TerminalLineType = TerminalLineType.OUTPUT,
    val timestamp: String = ""
)

enum class TerminalLineType {
    INPUT_PROMPT,   // User entered command e.g. "$ nanortime --tune-system"
    OUTPUT,         // Normal stdout
    SYSTEM_INFO,    // Hardware / FFI status message
    ERROR,          // stderr / error message
    SUCCESS         // Success confirmation
}

/**
 * Terminal State and User Actions following MVI & SOLID Principles.
 */
data class TerminalUiState(
    val lines: List<TerminalLine> = emptyList(),
    val currentInput: String = "",
    val autoSuggestions: List<String> = emptyList(),
    val isExecuting: Boolean = false,
    val currentDirectory: String = "/data/local/tmp/nanoai"
)

sealed interface TerminalUiAction {
    data class OnInputChanged(val newInput: String) : TerminalUiAction
    object ExecuteCommand : TerminalUiAction
    data class SelectSuggestion(val suggestion: String) : TerminalUiAction
    object ClearTerminal : TerminalUiAction
}
