package dev.nanoai.mobile.performance

import android.content.Context
import android.os.Build
import android.os.PerformanceHintManager
import android.os.Process
import android.util.Log

/**
 * NanoPerformanceEngine — Motor de rendimiento ADPF (Android Dynamic Performance Framework).
 *
 * Responsabilidad Única (SRP):
 * Administrar sesiones de PerformanceHintManager (API 31+) e informar al scheduler
 * de Linux (EAS) de los hilos reales de cómputo y duraciones de ciclo en nanosegundos.
 */
class NanoPerformanceEngine(
    private val context: Context,
    private val thermalMonitor: NanoThermalMonitor,
) {
    companion object {
        private const val TAG = "NanoPerformanceEngine"

        const val MODE_ECO = "eco"
        const val MODE_BALANCED = "balanced"
        const val MODE_TURBO = "turbo"

        // Duraciones objetivo predeterminadas por ciclo de trabajo (nanosegundos)
        const val DURATION_TURBO_NS = 16_666_666L    // ~16.6ms (Alta reactividad)
        const val DURATION_BALANCED_NS = 33_333_333L // ~33.3ms (Sostenible)
        const val DURATION_ECO_NS = 66_666_666L      // ~66.6ms (Ahorro de batería)
    }

    private val hintManager: PerformanceHintManager? by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                context.getSystemService(Context.PERFORMANCE_HINT_SERVICE) as? PerformanceHintManager
            } catch (e: Exception) {
                Log.w(TAG, "No se pudo obtener PerformanceHintManager: ${e.message}")
                null
            }
        } else null
    }

    private var currentSession: PerformanceHintManager.Session? = null
    private var registeredTids = intArrayOf(Process.myTid())
    private var currentMode = MODE_BALANCED
    private var currentTargetDurationNs = DURATION_BALANCED_NS

    val isAdpfSupported: Boolean
        get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && hintManager != null

    init {
        // Escucha cambios térmicos para autoprotección de hardware
        thermalMonitor.addListener { status ->
            onThermalStateChanged(status)
        }
    }

    /** Registra los thread IDs (TIDs) reales de inferencia para darles prioridad CPU. */
    @Synchronized
    fun registerWorkerThreads(tids: IntArray) {
        val validTids = if (tids.isNotEmpty()) tids else intArrayOf(Process.myTid())
        registeredTids = validTids
        Log.i(TAG, "Worker threads registrados: ${validTids.joinToString()}")
        // Si hay una sesión activa, recrearla con los nuevos TIDs
        if (currentSession != null) {
            startSession(currentMode, currentTargetDurationNs)
        }
    }

    /** Activa o actualiza el modo de rendimiento (eco, balanced, turbo). */
    @Synchronized
    fun setMode(mode: String): Boolean {
        currentMode = mode.lowercase()
        val targetNs = when (currentMode) {
            MODE_TURBO -> DURATION_TURBO_NS
            MODE_BALANCED -> DURATION_BALANCED_NS
            MODE_ECO -> DURATION_ECO_NS
            else -> DURATION_BALANCED_NS
        }
        return startSession(currentMode, targetNs)
    }

    fun getMode(): String = currentMode

    /** Inicia o reconfigura la sesión ADPF según el modo y duración requerida. */
    @Synchronized
    fun startSession(mode: String, targetDurationNs: Long): Boolean {
        if (!isAdpfSupported) return false
        currentTargetDurationNs = targetDurationNs
        currentMode = mode

        // En modo ECO o bajo estrés térmico severo, no forzamos sesión turbo
        val thermalStatus = thermalMonitor.getCurrentStatus()
        if (thermalStatus >= NanoThermalMonitor.STATUS_SEVERE) {
            Log.w(TAG, "Estrés térmico SEVERE/CRITICAL ($thermalStatus): Modo forzado a ECO.")
            closeSession()
            return false
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                closeSession()
                currentSession = hintManager?.createHintSession(registeredTids, targetDurationNs)
                Log.i(TAG, "Sesión ADPF iniciada. Modo=$mode, Target=${targetDurationNs / 1_000_000}ms, TIDs=${registeredTids.size}")
                return currentSession != null
            } catch (e: Exception) {
                Log.w(TAG, "Fallo al crear sesión ADPF: ${e.message}")
                currentSession = null
            }
        }
        return false
    }

    /** Reporta la duración real del ciclo de inferencia/cómputo procesado. */
    fun reportActualWorkDuration(durationNs: Long) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                currentSession?.reportActualWorkDuration(durationNs)
            } catch (e: Exception) {
                Log.d(TAG, "Error al reportar duración a ADPF: ${e.message}")
            }
        }
    }

    /** Actualiza la duración objetivo de la sesión actual sin recrearla. */
    fun updateTargetWorkDuration(targetDurationNs: Long) {
        currentTargetDurationNs = targetDurationNs
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                currentSession?.updateTargetWorkDuration(targetDurationNs)
            } catch (e: Exception) {
                Log.d(TAG, "Error actualizando targetWorkDuration: ${e.message}")
            }
        }
    }

    /** Maneja la autoprotección ante calentamiento del SoC. */
    private fun onThermalStateChanged(status: Int) {
        when (status) {
            NanoThermalMonitor.STATUS_MODERATE -> {
                Log.w(TAG, "Alerta térmica MODERATE: reduciendo objetivo de sesión a BALANCED.")
                if (currentMode == MODE_TURBO) {
                    setMode(MODE_BALANCED)
                }
            }
            NanoThermalMonitor.STATUS_SEVERE,
            NanoThermalMonitor.STATUS_CRITICAL,
            NanoThermalMonitor.STATUS_EMERGENCY,
            NanoThermalMonitor.STATUS_SHUTDOWN -> {
                Log.e(TAG, "Peligro térmico ($status): cerrando sesión ADPF para permitir enfriamiento.")
                closeSession()
            }
        }
    }

    @Synchronized
    fun closeSession() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                currentSession?.close()
            } catch (e: Exception) {
                Log.d(TAG, "Error cerrando sesión ADPF: ${e.message}")
            }
            currentSession = null
        }
    }

    fun close() {
        closeSession()
    }
}
