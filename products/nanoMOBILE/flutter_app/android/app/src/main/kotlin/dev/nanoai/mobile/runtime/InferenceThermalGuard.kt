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

    private fun isCritical(): Boolean = Build.VERSION.SDK_INT >= 29 &&
        (power?.currentThermalStatus ?: -1) >= PowerManager.THERMAL_STATUS_CRITICAL

    /**
     * SEVERE degrada, no mata: algunos OEM (ColorOS shell_skin) marcan SEVERE de
     * forma permanente con piel a 45°C. En SEVERE solo se admite el paquete
     * liviano (LiteRT 0.6B/230M); los pesados (MNN 3B, Gemma 4 E2B) siguen
     * bloqueados. CRITICAL+ bloquea todo: el sistema está a punto de apagar.
     */
    fun checkAdmission(light: Boolean = false) {
        val blocked = isCritical() || (isSevere() && !light)
        check(!blocked) {
            "THERMAL_PAUSED: esperando enfriamiento del dispositivo" +
                if (isSevere() && !isCritical()) " (solo modelo liviano admitido en SEVERE)" else ""
        }
    }

    /**
     * Conserva la respuesta inmediata en frío normal, pero no mantiene cientos
     * de MB/GB de pesos acelerados durante cinco minutos cuando Android ya
     * reporta presión térmica. SEVERE acorta la retención; CRITICAL la elimina.
     * LIGHT/MODERATE acortan exclusivamente la retención ociosa.
     */
    fun warmIdleTimeoutMs(defaultMs: Long): Long {
        if (Build.VERSION.SDK_INT < 29) return defaultMs
        return when (power?.currentThermalStatus ?: PowerManager.THERMAL_STATUS_NONE) {
            in PowerManager.THERMAL_STATUS_CRITICAL..Int.MAX_VALUE -> 0L
            PowerManager.THERMAL_STATUS_SEVERE -> minOf(defaultMs, 15_000L)
            PowerManager.THERMAL_STATUS_MODERATE -> minOf(defaultMs, 30_000L)
            PowerManager.THERMAL_STATUS_LIGHT -> minOf(defaultMs, 90_000L)
            else -> defaultMs
        }
    }

    suspend fun <T> protect(
        cancel: () -> Unit,
        light: Boolean = false,
        work: suspend () -> T,
    ): T = coroutineScope {
        checkAdmission(light)
        val overheated = AtomicBoolean(false)
        val monitor = launch(Dispatchers.Default) {
            while (isActive) {
                delay(5_000)
                if (isCritical() || (isSevere() && !light)) {
                    overheated.set(true)
                    android.util.Log.w("NanoThermal", "inference paused; status=${power?.currentThermalStatus}")
                    cancel()
                    break
                }
            }
        }
        try {
            val result = work()
            checkAdmission(light)
            check(!overheated.get()) { "THERMAL_PAUSED: generación cancelada por temperatura" }
            result
        } catch (error: Throwable) {
            // La cancelación del motor no debe ocultar que el monitor térmico
            // la originó. Solo se propaga un código estable, sin texto del chat.
            if (overheated.get()) throw IllegalStateException(
                "THERMAL_PAUSED: generación cancelada por temperatura", error)
            throw error
        } finally {
            monitor.cancelAndJoin()
        }
    }
}
