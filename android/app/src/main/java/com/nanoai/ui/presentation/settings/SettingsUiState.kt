package com.nanoai.ui.presentation.settings

data class SettingsUiState(
    // Section 1: General
    val autoStartOnBoot: Boolean = true,
    val themeMode: String = "Sistema", // "Sistema", "Oscuro", "Claro"

    // Section 2: Memory & RAM
    val enableMadviseLayerStreaming: Boolean = true,
    val enableOomGuard: Boolean = true,
    val oomThresholdScore: Int = 180,

    // Section 3: Thermal & Performance
    val maxThermalLimitC: Float = 42.0f,
    val autoThermalThrottling: Boolean = true,

    // Section 4: Battery Guardian
    val batteryMode: String = "Balanced",

    // Section 5: LLM Inference
    val temperature: Float = 0.7f,
    val topP: Float = 0.9f,
    val naturalStops: Boolean = true,
    val contextWindowSize: Int = 2048,

    // Section 6: Privacy & Entropy
    val enablePiiAnonymizer: Boolean = true,
    val entropyConfidenceThreshold: Float = 0.85f,

    // Section 7: Advanced / GPU
    val gpuLayers: Int = 0
)

sealed interface SettingsUiAction {
    data class UpdateTemperature(val temp: Float) : SettingsUiAction
    data class UpdateTopP(val topP: Float) : SettingsUiAction
    data class UpdateContextWindow(val size: Int) : SettingsUiAction
    data class ToggleMadvise(val enabled: Boolean) : SettingsUiAction
    data class ToggleOomGuard(val enabled: Boolean) : SettingsUiAction
    data class UpdateThermalLimit(val limitC: Float) : SettingsUiAction
    data class UpdateBatteryMode(val mode: String) : SettingsUiAction
    data class TogglePiiAnonymizer(val enabled: Boolean) : SettingsUiAction
    data class UpdateGpuLayers(val layers: Int) : SettingsUiAction
    data class UpdateThemeMode(val mode: String) : SettingsUiAction
    object ResetToDefaults : SettingsUiAction
}
