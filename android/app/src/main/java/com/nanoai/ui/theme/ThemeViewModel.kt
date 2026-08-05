package com.nanoai.ui.theme

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Shared theme mode state holder — survives recomposition.
 * Updated by SettingsScreen, consumed by MainActivity/NanoAITheme.
 */
object ThemeViewModel {
    private val _mode = MutableStateFlow(NanoThemeMode.SYSTEM)
    val mode: StateFlow<NanoThemeMode> = _mode.asStateFlow()

    fun setMode(mode: NanoThemeMode) {
        _mode.value = mode
    }

    fun setModeFromString(value: String) {
        _mode.value = when (value) {
            "Oscuro" -> NanoThemeMode.DARK
            "Claro"  -> NanoThemeMode.LIGHT
            else     -> NanoThemeMode.SYSTEM
        }
    }

    fun modeToString(): String = when (_mode.value) {
        NanoThemeMode.DARK   -> "Oscuro"
        NanoThemeMode.LIGHT  -> "Claro"
        NanoThemeMode.SYSTEM -> "Sistema"
    }
}
