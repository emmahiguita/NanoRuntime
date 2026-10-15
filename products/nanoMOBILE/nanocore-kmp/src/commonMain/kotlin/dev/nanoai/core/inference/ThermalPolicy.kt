// ─────────────────────────────────────────────────────────────────────────────
// commonMain · dev.nanoai.core.inference · ThermalPolicy.kt
//
// QUÉ  : Contrato multiplataforma para comprobar el estado térmico del
//         dispositivo y ajustar el timeout de inactividad del motor de
//         inferencia local.
// POR QUÉ: Las APIs de temperatura son distintas en Android (PowerManager) y
//           en iOS (ProcessInfo / NSProcessInfo.thermalState). Centralizar aquí
//           la interfaz permite compartir toda la lógica de decisión en
//           commonMain sin importar `android.*`.
// ─────────────────────────────────────────────────────────────────────────────
package dev.nanoai.core.inference

/**
 * Niveles térmicos normalizados, independientes de la plataforma.
 * El orden es ascendente: NONE < LIGHT < MODERATE < SEVERE.
 */
enum class ThermalLevel { NONE, LIGHT, MODERATE, SEVERE }

/**
 * Proveedor de información térmica que cada plataforma implementa.
 * Android usa [PowerManager], iOS usa [NSProcessInfo.thermalState].
 */
expect object PlatformThermalProvider {
    /** Nivel térmico actual del dispositivo. */
    val currentLevel: ThermalLevel
}

/**
 * Reglas de throttling compartidas (commonMain).
 * Estas lógicas son 100 % puras y testables sin emulador.
 */
object ThermalPolicy {
    /**
     * Lanza [IllegalStateException] si el dispositivo está en nivel SEVERE.
     * Debe llamarse antes de iniciar una sesión de decodificación.
     */
    fun checkAdmission() {
        check(PlatformThermalProvider.currentLevel < ThermalLevel.SEVERE) {
            "THERMAL_PAUSED: esperando enfriamiento del dispositivo"
        }
    }

    /**
     * Calcula el timeout de inactividad tras el cual el motor se descarga.
     * - SEVERE  → 0 ms (descarga inmediata)
     * - MODERATE → mín(default, 30 s)
     * - LIGHT    → mín(default, 90 s)
     * - NONE     → default sin cambios
     */
    fun warmIdleTimeoutMs(defaultMs: Long): Long = when (PlatformThermalProvider.currentLevel) {
        ThermalLevel.SEVERE   -> 0L
        ThermalLevel.MODERATE -> minOf(defaultMs, 30_000L)
        ThermalLevel.LIGHT    -> minOf(defaultMs, 90_000L)
        ThermalLevel.NONE     -> defaultMs
    }
}
