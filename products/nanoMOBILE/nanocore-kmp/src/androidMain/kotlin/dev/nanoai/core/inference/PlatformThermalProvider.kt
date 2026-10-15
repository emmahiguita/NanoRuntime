// ─────────────────────────────────────────────────────────────────────────────
// androidMain · dev.nanoai.core.inference · PlatformThermalProvider.kt
//
// QUÉ  : `actual` Android de PlatformThermalProvider usando PowerManager.
// CÓMO : Traduce THERMAL_STATUS_* a ThermalLevel normalizado.
//         La lógica de decisión (warmIdleTimeoutMs, checkAdmission) ya
//         reside en ThermalPolicy (commonMain) y no se toca.
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core.inference

import android.os.Build
import android.os.PowerManager
import dev.nanoai.core.inference.ThermalLevel

actual object PlatformThermalProvider {
    @Volatile private var powerManager: PowerManager? = null

    /** Llamado desde Application.onCreate() o desde el canal Flutter. */
    fun configure(pm: PowerManager) { powerManager = pm }

    actual val currentLevel: ThermalLevel
        get() {
            if (Build.VERSION.SDK_INT < 29) return ThermalLevel.NONE
            return when ((powerManager?.currentThermalStatus ?: PowerManager.THERMAL_STATUS_NONE)) {
                in PowerManager.THERMAL_STATUS_SEVERE..Int.MAX_VALUE -> ThermalLevel.SEVERE
                PowerManager.THERMAL_STATUS_MODERATE -> ThermalLevel.MODERATE
                PowerManager.THERMAL_STATUS_LIGHT    -> ThermalLevel.LIGHT
                else                                 -> ThermalLevel.NONE
            }
        }
}
