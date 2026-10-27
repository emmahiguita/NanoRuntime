package dev.nanoai.mobile.performance

import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.util.Log
import java.util.concurrent.CopyOnWriteArrayList

/**
 * NanoThermalMonitor — Monitor térmico reactivo basado en PowerManager (API 29+).
 *
 * Responsabilidad Única (SRP):
 * Observar cambios térmicos del hardware y notificar a los suscriptores
 * para activar degradación elegante (Graceful Degradation) antes del thermal throttling.
 */
class NanoThermalMonitor(
    private val context: Context,
) {
    companion object {
        private const val TAG = "NanoThermalMonitor"

        // Constantes reflejadas de PowerManager para compatibilidad y semántica
        const val STATUS_NONE = 0
        const val STATUS_LIGHT = 1
        const val STATUS_MODERATE = 2
        const val STATUS_SEVERE = 3
        const val STATUS_CRITICAL = 4
        const val STATUS_EMERGENCY = 5
        const val STATUS_SHUTDOWN = 6
        const val STATUS_UNKNOWN = -1
    }

    private val powerManager: PowerManager? by lazy {
        try {
            context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        } catch (e: Exception) {
            Log.w(TAG, "No se pudo obtener PowerManager: ${e.message}")
            null
        }
    }

    private val listeners = CopyOnWriteArrayList<(Int) -> Unit>()
    // Android nombra oficialmente este callback OnThermalStatusChangedListener.
    private var thermalListener: PowerManager.OnThermalStatusChangedListener? = null
    @Volatile private var isRunning = false

    /** Indica si el sistema soporta la API de estado térmico (Android 10 / API 29+). */
    val isSupported: Boolean
        get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && powerManager != null

    /** Obtiene el estado térmico actual de forma síncrona y barata. */
    fun getCurrentStatus(): Int {
        if (!isSupported) return STATUS_UNKNOWN
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                powerManager?.currentThermalStatus ?: STATUS_UNKNOWN
            } else {
                STATUS_UNKNOWN
            }
        } catch (e: Exception) {
            Log.w(TAG, "Error leyendo estado térmico: ${e.message}")
            STATUS_UNKNOWN
        }
    }

    /** Inicia la escucha activa de eventos térmicos del sistema. Idempotente. */
    @Synchronized
    fun start() {
        if (isRunning || !isSupported) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            try {
                val listener = PowerManager.OnThermalStatusChangedListener { status ->
                    Log.i(TAG, "Cambio de estado térmico: $status (${statusToString(status)})")
                    notifyListeners(status)
                }
                thermalListener = listener
                val executor = context.mainExecutor
                powerManager?.addThermalStatusListener(executor, listener)
                isRunning = true
                Log.i(TAG, "NanoThermalMonitor iniciado con éxito.")
            } catch (e: Exception) {
                Log.w(TAG, "Fallo al registrar OnThermalStatusChangedListener: ${e.message}")
            }
        }
    }

    /** Detiene la escucha y libera recursos para evitar fugas de memoria. Idempotente. */
    @Synchronized
    fun stop() {
        if (!isRunning) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            thermalListener?.let { listener ->
                try {
                    powerManager?.removeThermalStatusListener(listener)
                } catch (e: Exception) {
                    Log.w(TAG, "Error al desregistrar OnThermalStatusListener: ${e.message}")
                }
            }
            thermalListener = null
        }
        isRunning = false
        Log.i(TAG, "NanoThermalMonitor detenido.")
    }

    fun addListener(listener: (Int) -> Unit) {
        listeners.add(listener)
    }

    fun removeListener(listener: (Int) -> Unit) {
        listeners.remove(listener)
    }

    private fun notifyListeners(status: Int) {
        for (l in listeners) {
            try {
                l(status)
            } catch (e: Exception) {
                Log.e(TAG, "Error en callback de thermal listener: ${e.message}", e)
            }
        }
    }

    /**
     * Factor de escala recomendado para hilos de inferencia (0.0 a 1.0)
     * según el nivel de estrés térmico del dispositivo.
     */
    fun getRecommendedThreadScale(status: Int): Double = when (status) {
        STATUS_NONE, STATUS_LIGHT -> 1.0 // 100% de hilos
        STATUS_MODERATE -> 0.75         // Reducción preventiva (ej. 4 -> 3 hilos)
        STATUS_SEVERE -> 0.50           // Reducción drástica (ej. 4 -> 2 hilos)
        STATUS_CRITICAL -> 0.25         // Supervivencia mínima (1 hilo)
        STATUS_EMERGENCY, STATUS_SHUTDOWN -> 0.0 // Detener inferencia pesada
        else -> 1.0
    }

    fun statusToString(status: Int): String = when (status) {
        STATUS_NONE -> "NONE"
        STATUS_LIGHT -> "LIGHT"
        STATUS_MODERATE -> "MODERATE"
        STATUS_SEVERE -> "SEVERE"
        STATUS_CRITICAL -> "CRITICAL"
        STATUS_EMERGENCY -> "EMERGENCY"
        STATUS_SHUTDOWN -> "SHUTDOWN"
        else -> "UNKNOWN"
    }
}
