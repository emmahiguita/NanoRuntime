package com.nanoai.ui.presentation.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.nanoai.data.repository.SettingsRepository
import com.nanoai.ui.theme.ThemeViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * SettingsViewModel implementing SOLID principles:
 * - Single Responsibility: Manages user preferences for runtime hardware, inference, and thermal controllers.
 * - Dependency Inversion: Depends on SettingsRepository abstraction.
 */
class SettingsViewModel(
    private val settingsRepository: SettingsRepository = SettingsRepository()
) : ViewModel() {

    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState: StateFlow<SettingsUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            settingsRepository.settings.collect { savedSettings ->
                _uiState.value = savedSettings
            }
        }
    }

    fun onAction(action: SettingsUiAction) {
        when (action) {
            is SettingsUiAction.UpdateTemperature -> updateAndPersist { it.copy(temperature = action.temp) }
            is SettingsUiAction.UpdateTopP -> updateAndPersist { it.copy(topP = action.topP) }
            is SettingsUiAction.UpdateContextWindow -> updateAndPersist { it.copy(contextWindowSize = action.size) }
            is SettingsUiAction.ToggleMadvise -> updateAndPersist { it.copy(enableMadviseLayerStreaming = action.enabled) }
            is SettingsUiAction.ToggleOomGuard -> updateAndPersist { it.copy(enableOomGuard = action.enabled) }
            is SettingsUiAction.UpdateThermalLimit -> updateAndPersist { it.copy(maxThermalLimitC = action.limitC) }
            is SettingsUiAction.UpdateBatteryMode -> updateAndPersist { it.copy(batteryMode = action.mode) }
            is SettingsUiAction.TogglePiiAnonymizer -> updateAndPersist { it.copy(enablePiiAnonymizer = action.enabled) }
            is SettingsUiAction.UpdateGpuLayers -> updateAndPersist { it.copy(gpuLayers = action.layers) }
            is SettingsUiAction.UpdateThemeMode -> {
                ThemeViewModel.setModeFromString(action.mode)
                updateAndPersist { it.copy(themeMode = action.mode) }
            }
            is SettingsUiAction.ResetToDefaults -> {
                settingsRepository.resetDefaults()
                _uiState.value = SettingsUiState()
            }
        }
    }

    private fun updateAndPersist(transform: (SettingsUiState) -> SettingsUiState) {
        val updated = transform(_uiState.value)
        _uiState.value = updated
        settingsRepository.updateSettings(updated)
    }
}
