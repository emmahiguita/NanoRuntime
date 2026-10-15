// ─────────────────────────────────────────────────────────────────────────────
// iosMain · dev.nanoai.core.inference · PlatformThermalProvider.kt
//
// QUÉ  : `actual` iOS de PlatformThermalProvider usando NSProcessInfo.
// CÓMO : NSProcessInfo.processInfo.thermalState devuelve NSProcessInfoThermal-
//         State (nominal/fair/serious/critical). Se mapea a ThermalLevel.
// POR QUÉ: La misma política de throttling de commonMain (ThermalPolicy) opera
//           sin cambios — solo cambia la fuente del nivel.
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core.inference

import platform.Foundation.NSProcessInfo
import platform.Foundation.NSProcessInfoThermalStateCritical
import platform.Foundation.NSProcessInfoThermalStateFair
import platform.Foundation.NSProcessInfoThermalStateNominal
import platform.Foundation.NSProcessInfoThermalStateSerious

actual object PlatformThermalProvider {
    actual val currentLevel: ThermalLevel
        get() = when (NSProcessInfo.processInfo.thermalState) {
            NSProcessInfoThermalStateCritical -> ThermalLevel.SEVERE
            NSProcessInfoThermalStateSerious  -> ThermalLevel.MODERATE
            NSProcessInfoThermalStateFair     -> ThermalLevel.LIGHT
            NSProcessInfoThermalStateNominal  -> ThermalLevel.NONE
            else                              -> ThermalLevel.NONE
        }
}
