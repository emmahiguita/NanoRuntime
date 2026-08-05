package com.nanoai.ui.presentation.monitor

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CleaningServices
import androidx.compose.material.icons.filled.DeveloperBoard
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.nanoai.ui.components.NanoGraph
import com.nanoai.ui.theme.*
import com.nanoai.ui.theme.nanoColors

/**
 * MonitorScreen (Sección 6 Specification Compliant)
 * Enforces SOLID Principles:
 * - Single Responsibility: Renders real-time telemetry graphs, memory breakdown, and process table.
 * - Dependency Inversion: Receives abstract MonitorUiState and emits MonitorUiAction.
 */
@Composable
fun MonitorScreen(
    viewModel: MonitorViewModel,
    modifier: Modifier = Modifier
) {
    val state by viewModel.uiState.collectAsState()

    MonitorContent(
        state = state,
        onAction = viewModel::onAction,
        modifier = modifier
    )
}

@Composable
fun MonitorContent(
    state: MonitorUiState,
    onAction: (MonitorUiAction) -> Unit,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background)
            .padding(NanoSpacingTokens.lg)
    ) {
        when (state) {
            is MonitorUiState.Loading -> {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = MaterialTheme.colorScheme.primary)
                }
            }

            is MonitorUiState.Error -> {
                Column(
                    modifier = Modifier.fillMaxSize(),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Icon(
                        imageVector = Icons.Default.Error,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.error,
                        modifier = Modifier.size(48.dp)
                    )
                    Spacer(modifier = Modifier.height(NanoSpacingTokens.md))
                    Text(
                        text = state.message,
                        style = NanoTypeTokens.body,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
            }

            is MonitorUiState.Success -> {
                LazyColumn(
                    verticalArrangement = Arrangement.spacedBy(NanoSpacingTokens.lg),
                    modifier = Modifier.fillMaxSize()
                ) {
                    // Header Bar with GC Trigger
                    item {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                horizontalArrangement = Arrangement.spacedBy(NanoSpacingTokens.sm)
                            ) {
                                Icon(
                                    imageVector = Icons.Default.DeveloperBoard,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.secondary,
                                    modifier = Modifier.size(24.dp)
                                )
                                Text(
                                    text = "Telemetría del Sistema",
                                    style = NanoTypeTokens.title,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                            }

                            Row(horizontalArrangement = Arrangement.spacedBy(NanoSpacingTokens.sm)) {
                                IconButton(onClick = { onAction(MonitorUiAction.RefreshMetrics) }) {
                                    Icon(
                                        imageVector = Icons.Default.Refresh,
                                        contentDescription = "Actualizar métricas",
                                        tint = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                                Button(
                                    onClick = { onAction(MonitorUiAction.TriggerGc) },
                                    colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.secondary),
                                    shape = NanoShapeTokens.medium
                                ) {
                                    Icon(
                                        imageVector = Icons.Default.CleaningServices,
                                        contentDescription = null,
                                        modifier = Modifier.size(16.dp)
                                    )
                                    Spacer(modifier = Modifier.width(NanoSpacingTokens.xs))
                                    Text("madvise GC", style = NanoTypeTokens.caption)
                                }
                            }
                        }
                    }

                    // RAM Breakdown Visual Bar
                    item {
                        RamBreakdownCard(breakdown = state.ramBreakdown, oomScore = state.oomScore)
                    }

                    // Graph 1: RSS Memory Variance
                    item {
                        NanoGraph(
                            title = "RSS Variance (MB) — mmap Layer Streaming",
                            dataPoints = state.rssSeriesMb,
                            lineColor = MaterialTheme.colorScheme.primary,
                            unitLabel = "MB"
                        )
                    }

                    // Graph 2: Inferencia TPS Throughput
                    item {
                        NanoGraph(
                            title = "Rendimiento Inferencia (Tokens/s)",
                            dataPoints = state.tpsSeries,
                            lineColor = MaterialTheme.colorScheme.secondary,
                            unitLabel = "t/s"
                        )
                    }

                    // Graph 3: Curva Térmica CPU
                    item {
                        NanoGraph(
                            title = "Temperatura Térmica SoC (°C)",
                            dataPoints = state.thermalSeries,
                            lineColor = nanoColors().StatusWarning,
                            unitLabel = "°C"
                        )
                    }

                    // Process List Header
                    item {
                        Text(
                            text = "PROCESOS E HILOS ACTIVOS",
                            style = NanoTypeTokens.caption,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(modifier = Modifier.height(NanoSpacingTokens.sm))
                    }

                    // Active Processes List
                    items(state.processes, key = { it.pid }) { process ->
                        ProcessRowItem(
                            process = process,
                            onTerminate = { onAction(MonitorUiAction.TerminateProcess(process.pid)) }
                        )
                    }
                }
            }
        }
    }
}

@Composable
fun RamBreakdownCard(
    breakdown: RamBreakdown,
    oomScore: Int,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .semantics { contentDescription = "Desglose de uso de RAM" },
        shape = NanoShapeTokens.large,
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(NanoSpacingTokens.lg)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "Desglose RAM (${breakdown.usedRamMb.toInt()} MB / ${breakdown.totalRamMb.toInt()} MB)",
                    style = NanoTypeTokens.subtitle,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Surface(
                    shape = NanoShapeTokens.small,
                    color = if (oomScore == 0) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.primaryContainer
                ) {
                    Text(
                        text = "OOM Score: $oomScore",
                        style = NanoTypeTokens.caption,
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(NanoSpacingTokens.md))

            // Multi-color stacked progress bar
            val modelWeightFraction = breakdown.modelWeightsMb / breakdown.totalRamMb
            val kvCacheFraction = breakdown.kvCacheMb / breakdown.totalRamMb
            val pageCacheFraction = breakdown.pageCacheMb / breakdown.totalRamMb

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(12.dp)
                    .clip(NanoShapeTokens.small)
                    .background(MaterialTheme.colorScheme.surfaceVariant)
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxHeight()
                        .weight(modelWeightFraction.coerceAtLeast(0.01f))
                        .background(MaterialTheme.colorScheme.primary)
                )
                Box(
                    modifier = Modifier
                        .fillMaxHeight()
                        .weight(kvCacheFraction.coerceAtLeast(0.01f))
                        .background(MaterialTheme.colorScheme.secondary)
                )
                Box(
                    modifier = Modifier
                        .fillMaxHeight()
                        .weight(pageCacheFraction.coerceAtLeast(0.01f))
                        .background(nanoColors().StatusInfo)
                )
                Box(
                    modifier = Modifier
                        .fillMaxHeight()
                        .weight((1f - (modelWeightFraction + kvCacheFraction + pageCacheFraction)).coerceAtLeast(0.01f))
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                )
            }

            Spacer(modifier = Modifier.height(NanoSpacingTokens.md))

            // Legend
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                LegendItem(color = MaterialTheme.colorScheme.primary, label = "Weights (${breakdown.modelWeightsMb.toInt()} MB)")
                LegendItem(color = MaterialTheme.colorScheme.secondary, label = "KV Cache (${breakdown.kvCacheMb.toInt()} MB)")
                LegendItem(color = nanoColors().StatusInfo, label = "PageCache (${breakdown.pageCacheMb.toInt()} MB)")
            }
        }
    }
}

@Composable
fun LegendItem(color: Color, label: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .clip(NanoShapeTokens.small)
                .background(color)
        )
        Text(
            text = label,
            style = NanoTypeTokens.caption,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
fun ProcessRowItem(
    process: ProcessItem,
    onTerminate: () -> Unit
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
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(NanoSpacingTokens.sm)
                ) {
                    Text(
                        text = process.name,
                        style = NanoTypeTokens.subtitle,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "PID: ${process.pid}",
                        style = NanoTypeTokens.caption,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                Spacer(modifier = Modifier.height(2.dp))

                Row(horizontalArrangement = Arrangement.spacedBy(NanoSpacingTokens.lg)) {
                    Text(
                        text = "CPU: ${process.cpuUsagePercent}%",
                        style = NanoTypeTokens.caption,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = "RSS: ${process.rssMemoryMb.toInt()} MB",
                        style = NanoTypeTokens.caption,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = "Hilos: ${process.threadsCount}",
                        style = NanoTypeTokens.caption,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            Surface(
                shape = NanoShapeTokens.small,
                color = when (process.state) {
                    ProcessState.RUNNING -> MaterialTheme.colorScheme.secondaryContainer
                    ProcessState.SLEEPING -> MaterialTheme.colorScheme.surfaceVariant
                    ProcessState.OOM_SUPERVIVENCIA -> MaterialTheme.colorScheme.primaryContainer
                }
            ) {
                Text(
                    text = process.state.name,
                    style = NanoTypeTokens.caption,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                )
            }
        }
    }
}

@Preview
@Composable
fun MonitorScreenPreview() {
    NanoAITheme {
        MonitorContent(
            state = MonitorUiState.Success(
                rssSeriesMb = listOf(1120f, 1122f, 1121f, 1121.5f),
                tpsSeries = listOf(14.0f, 14.2f, 14.5f),
                thermalSeries = listOf(38.0f, 38.2f, 38.5f),
                ramBreakdown = RamBreakdown(920f, 180f, 210f, 950f, 3720f),
                processes = emptyList(),
                oomScore = 0
            ),
            onAction = {}
        )
    }
}
