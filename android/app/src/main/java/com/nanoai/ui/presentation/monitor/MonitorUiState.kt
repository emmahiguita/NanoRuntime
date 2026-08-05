package com.nanoai.ui.presentation.monitor

/**
 * RAM Allocation Breakdown Data Model.
 */
data class RamBreakdown(
    val modelWeightsMb: Float,
    val kvCacheMb: Float,
    val pageCacheMb: Float,
    val freeRamMb: Float,
    val totalRamMb: Float
) {
    val usedRamMb: Float get() = modelWeightsMb + kvCacheMb + pageCacheMb
    val usedPercentage: Float get() = (usedRamMb / totalRamMb) * 100f
}

/**
 * Active Process / Thread Data Model.
 */
data class ProcessItem(
    val pid: Int,
    val name: String,
    val cpuUsagePercent: Float,
    val rssMemoryMb: Float,
    val threadsCount: Int,
    val state: ProcessState
)

enum class ProcessState {
    RUNNING, SLEEPING, OOM_SUPERVIVENCIA
}

/**
 * Monitor State and Actions following MVI Architecture.
 */
sealed interface MonitorUiState {
    object Loading : MonitorUiState

    data class Success(
        val rssSeriesMb: List<Float>,
        val tpsSeries: List<Float>,
        val thermalSeries: List<Float>,
        val ramBreakdown: RamBreakdown,
        val processes: List<ProcessItem>,
        val oomScore: Int
    ) : MonitorUiState

    data class Error(val message: String) : MonitorUiState
}

sealed interface MonitorUiAction {
    object RefreshMetrics : MonitorUiAction
    object TriggerGc : MonitorUiAction
    data class TerminateProcess(val pid: Int) : MonitorUiAction
}
