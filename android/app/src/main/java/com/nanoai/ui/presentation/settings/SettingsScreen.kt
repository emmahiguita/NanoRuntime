package com.nanoai.ui.presentation.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.nanoai.ui.theme.*

/**
 * SettingsScreen (Sección 7 Specification Compliant — 7 Secciones)
 */
@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel,
    modifier: Modifier = Modifier
) {
    val state by viewModel.uiState.collectAsState()

    SettingsContent(
        state = state,
        onAction = viewModel::onAction,
        modifier = modifier
    )
}

@Composable
fun SettingsContent(
    state: SettingsUiState,
    onAction: (SettingsUiAction) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyColumn(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(horizontal = NanoSpacingTokens.lg),
        verticalArrangement = Arrangement.spacedBy(NanoSpacingTokens.lg)
    ) {
        // Section 1: General
        item {
            SettingsSectionHeader(title = "1. GENERAL", icon = Icons.Default.Tune)
            SettingsSelectorRow(
                title = "Tema de la aplicación",
                subtitle = "Claro, oscuro o automático según el sistema",
                options = listOf("Sistema", "Oscuro", "Claro"),
                selected = state.themeMode,
                onOptionSelected = { onAction(SettingsUiAction.UpdateThemeMode(it)) }
            )
        }

        // Section 2: Memoria & RAM
        item {
            SettingsSectionHeader(title = "2. GESTIÓN DE MEMORIA (RAM)", icon = Icons.Default.Memory)
            SettingsSwitchRow(
                title = "madvise(DONTNEED) Layer Streaming",
                subtitle = "Descarga quirúrgica por capa (VMA < 1GB)",
                checked = state.enableMadviseLayerStreaming,
                onCheckedChange = { onAction(SettingsUiAction.ToggleMadvise(it)) }
            )
            SettingsSwitchRow(
                title = "OOM Guard System",
                subtitle = "Activa modo supervivencia antes del crash",
                checked = state.enableOomGuard,
                onCheckedChange = { onAction(SettingsUiAction.ToggleOomGuard(it)) }
            )
        }

        // Section 3: Control Térmico
        item {
            SettingsSectionHeader(title = "3. CONTROL TÉRMICO DE SOC", icon = Icons.Default.Thermostat)
            SettingsSliderRow(
                title = "Límite de Temperatura Max (°C)",
                value = state.maxThermalLimitC,
                range = 35f..50f,
                steps = 15,
                unitLabel = "°C",
                onValueChange = { onAction(SettingsUiAction.UpdateThermalLimit(it)) }
            )
        }

        // Section 4: Battery Guardian
        item {
            SettingsSectionHeader(title = "4. GUARDIÁN DE BATERÍA", icon = Icons.Default.BatteryStd)
            Row(
                horizontalArrangement = Arrangement.spacedBy(NanoSpacingTokens.sm),
                modifier = Modifier.fillMaxWidth()
            ) {
                listOf("Eco", "Balanced", "Survival").forEach { mode ->
                    FilterChip(
                        selected = state.batteryMode == mode,
                        onClick = { onAction(SettingsUiAction.UpdateBatteryMode(mode)) },
                        label = { Text(mode) },
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }

        // Section 5: Inferencia LLM
        item {
            SettingsSectionHeader(title = "5. PARÁMETROS DE INFERENCIA LLM", icon = Icons.Default.Psychology)
            SettingsSliderRow(
                title = "Temperatura (Creatividad)",
                value = state.temperature,
                range = 0.1f..1.5f,
                steps = 14,
                unitLabel = "",
                onValueChange = { onAction(SettingsUiAction.UpdateTemperature(it)) }
            )
            SettingsSliderRow(
                title = "Top-P Sampling",
                value = state.topP,
                range = 0.1f..1.0f,
                steps = 9,
                unitLabel = "",
                onValueChange = { onAction(SettingsUiAction.UpdateTopP(it)) }
            )
        }

        // Section 6: Privacidad & Enrutamiento
        item {
            SettingsSectionHeader(title = "6. PRIVACIDAD & ENTROPY ROUTING", icon = Icons.Default.Security)
            SettingsSwitchRow(
                title = "Filtro PII de Datos Sensibles",
                subtitle = "Anonimiza emails y credenciales localmente",
                checked = state.enablePiiAnonymizer,
                onCheckedChange = { onAction(SettingsUiAction.TogglePiiAnonymizer(it)) }
            )
        }

        // Section 7: Avanzado & GPU
        item {
            SettingsSectionHeader(title = "7. CONFIGURACIÓN AVANZADA & GPU", icon = Icons.Default.DeveloperMode)
            SettingsSliderRow(
                title = "Capas GPU Offload",
                value = state.gpuLayers.toFloat(),
                range = 0f..32f,
                steps = 32,
                unitLabel = "capas",
                onValueChange = { onAction(SettingsUiAction.UpdateGpuLayers(it.toInt())) }
            )
        }

        item {
            OutlinedButton(
                onClick = { onAction(SettingsUiAction.ResetToDefaults) },
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.outlinedButtonColors(contentColor = MaterialTheme.colorScheme.error)
            ) {
                Icon(imageVector = Icons.Default.Restore, contentDescription = null)
                Spacer(modifier = Modifier.width(NanoSpacingTokens.sm))
                Text("Restablecer Ajustes de Fábrica")
            }
        }
    }
}

@Composable
fun SettingsSectionHeader(title: String, icon: ImageVector) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(NanoSpacingTokens.sm),
        modifier = Modifier.padding(vertical = NanoSpacingTokens.xs)
    ) {
        Icon(imageVector = icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(20.dp))
        Text(text = title, style = NanoTypeTokens.subtitle, color = MaterialTheme.colorScheme.onSurface)
    }
}

@Composable
fun SettingsSwitchRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Card(
        shape = NanoShapeTokens.medium,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(NanoSpacingTokens.md),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(text = title, style = NanoTypeTokens.body, color = MaterialTheme.colorScheme.onSurface)
                Text(text = subtitle, style = NanoTypeTokens.caption, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Switch(
                checked = checked,
                onCheckedChange = onCheckedChange,
                colors = SwitchDefaults.colors(checkedThumbColor = MaterialTheme.colorScheme.primary)
            )
        }
    }
}

@Composable
fun SettingsSliderRow(
    title: String,
    value: Float,
    range: ClosedFloatingPointRange<Float>,
    steps: Int,
    unitLabel: String,
    onValueChange: (Float) -> Unit
) {
    Card(
        shape = NanoShapeTokens.medium,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(NanoSpacingTokens.md)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text(text = title, style = NanoTypeTokens.body, color = MaterialTheme.colorScheme.onSurface)
                Text(
                    text = String.format("%.1f %s", value, unitLabel),
                    style = NanoTypeTokens.subtitle,
                    color = MaterialTheme.colorScheme.primary
                )
            }
            Slider(
                value = value,
                onValueChange = onValueChange,
                valueRange = range,
                steps = steps,
                colors = SliderDefaults.colors(
                    thumbColor = MaterialTheme.colorScheme.primary,
                    activeTrackColor = MaterialTheme.colorScheme.primary
                )
            )
        }
    }
}

@Composable
fun SettingsSelectorRow(
    title: String,
    subtitle: String,
    options: List<String>,
    selected: String,
    onOptionSelected: (String) -> Unit
) {
    Card(
        shape = NanoShapeTokens.medium,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier.fillMaxWidth().padding(NanoSpacingTokens.md)
        ) {
            Text(text = title, style = NanoTypeTokens.body, color = MaterialTheme.colorScheme.onSurface)
            Text(text = subtitle, style = NanoTypeTokens.caption, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(NanoSpacingTokens.sm))
            Row(horizontalArrangement = Arrangement.spacedBy(NanoSpacingTokens.sm)) {
                options.forEach { option ->
                    FilterChip(
                        selected = selected == option,
                        onClick = { onOptionSelected(option) },
                        label = { Text(option, style = NanoTypeTokens.caption) },
                        colors = FilterChipDefaults.filterChipColors(
                            selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
                            selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer
                        ),
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }
    }
}
