package dev.nanoai.mobile.runtime

import android.content.Context
import android.os.Build
import android.os.PowerManager
import kotlinx.coroutines.*
import java.util.concurrent.atomic.AtomicBoolean

/** QUÉ: impide iniciar o continuar decode con estrés térmico severo.
 * CÓMO: consulta PowerManager antes del turno y cada cinco segundos durante JNI.
 * POR QUÉ: cerrar ADPF no cancela el modelo; una salida térmicamente abortada no se envía. */
object InferenceThermalGuard {
    @Volatile private var power: PowerManager? = null

    fun configure(context: Context) {
        power = context.applicationContext.getSystemService(Context.POWER_SERVICE) as? PowerManager
    }

    private fun isSevere(): Boolean = Build.VERSION.SDK_INT >= 29 &&
        (power?.currentThermalStatus ?: -1) >= PowerManager.THERMAL_STATUS_SEVERE

    /**
     * Conserva la respuesta inmediata en frío normal, pero no mantiene cientos
     * de MB/GB de pesos acelerados durante cinco minutos cuando Android ya
     * reporta presión térmica. La inferencia activa solo se aborta en SEVERE;
     * LIGHT/MODERATE acortan exclusivamente la retención ociosa.
     */
    fun warmIdleTimeoutMs(defaultMs: Long): Long {
        if (Build.VERSION.SDK_INT < 29) return defaultMs
        return when (power?.currentThermalStatus ?: PowerManager.THERMAL_STATUS_NONE) {
            in PowerManager.THERMAL_STATUS_SEVERE..Int.MAX_VALUE -> 0L
            PowerManager.THERMAL_STATUS_MODERATE -> minOf(defaultMs, 30_000L)
            PowerManager.THERMAL_STATUS_LIGHT -> minOf(defaultMs, 90_000L)
            else -> defaultMs
        }
    }

    fun checkAdmission() {
        check(!isSevere()) { "THERMAL_PAUSED: esperando enfriamiento del dispositivo" }
    }

    suspend fun <T> protect(cancel: () -> Unit, work: suspend () -> T): T = coroutineScope {
        checkAdmission()
        val overheated = AtomicBoolean(false)
        val monitor = launch(Dispatchers.Default) {
            while (isActive) {
                delay(5_000)
                if (isSevere()) {
                    overheated.set(true)
                    cancel()
                    break
                }
            }
        }
        try {
            val result = work()
            checkAdmission()
            check(!overheated.get()) { "THERMAL_PAUSED: generación cancelada por temperatura" }
            result
        } finally {
            monitor.cancelAndJoin()
        }
    }
}
