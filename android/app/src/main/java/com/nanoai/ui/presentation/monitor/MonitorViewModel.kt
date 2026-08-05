package com.nanoai.ui.presentation.monitor

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.nanoai.data.repository.SystemMonitorRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * MonitorViewModel implementing SOLID principles:
 * - Single Responsibility: Monitors hardware metrics (RAM, TPS, Thermal, Processes) in real-time.
 * - Dependency Inversion: Depends on SystemMonitorRepository abstraction.
 */
class MonitorViewModel(
    private val systemMonitorRepository: SystemMonitorRepository = SystemMonitorRepository()
) : ViewModel() {

    private val _uiState = MutableStateFlow<MonitorUiState>(MonitorUiState.Loading)
    val uiState: StateFlow<MonitorUiState> = _uiState.asStateFlow()

    private val rssHistory = mutableListOf(1120f, 1122f, 1121f, 1120.5f, 1121.2f, 1120.8f, 1121.0f)
    private val tpsHistory = mutableListOf(12.5f, 13.8f, 14.2f, 13.9f, 14.5f, 14.1f, 14.3f)
    private val thermalHistory = mutableListOf(37.8f, 38.0f, 38.2f, 38.5f, 38.4f, 38.3f, 38.5f)

    init {
        startRealtimeMonitoring()
    }

    fun onAction(action: MonitorUiAction) {
        when (action) {
            is MonitorUiAction.RefreshMetrics -> {} // Repo loop handles auto-refresh
            is MonitorUiAction.TriggerGc -> triggerGarbageCollection()
            is MonitorUiAction.TerminateProcess -> terminateProcess(action.pid)
        }
    }

    private fun startRealtimeMonitoring() {
        viewModelScope.launch {
            systemMonitorRepository.getSystemMetricsFlow().collect { snapshot ->
                // Append new data points to rolling history windows
                rssHistory.add(snapshot.rssNewPoint)
                if (rssHistory.size > 15) rssHistory.removeAt(0)

                tpsHistory.add(snapshot.tpsNewPoint)
                if (tpsHistory.size > 15) tpsHistory.removeAt(0)

                thermalHistory.add(snapshot.thermalNewPoint)
                if (thermalHistory.size > 15) thermalHistory.removeAt(0)

                _uiState.value = MonitorUiState.Success(
                    rssSeriesMb = rssHistory.toList(),
                    tpsSeries = tpsHistory.toList(),
                    thermalSeries = thermalHistory.toList(),
                    ramBreakdown = snapshot.ramBreakdown,
                    processes = snapshot.processes,
                    oomScore = snapshot.oomScore
                )
            }
        }
    }

    private fun triggerGarbageCollection() {
        // Simulate madvise(DONTNEED) effect: drop RSS 40 MB
        if (rssHistory.isNotEmpty()) {
            rssHistory[rssHistory.lastIndex] = (rssHistory.last() - 40f).coerceAtLeast(800f)
        }
    }

    private fun terminateProcess(pid: Int) {
        val currentState = _uiState.value
        if (currentState is MonitorUiState.Success) {
            _uiState.value = currentState.copy(
                processes = currentState.processes.filterNot { it.pid == pid }
            )
        }
    }
}
