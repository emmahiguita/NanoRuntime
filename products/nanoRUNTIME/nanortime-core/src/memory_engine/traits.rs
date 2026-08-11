// memory_engine/traits.rs — Interfaces para orquestación extensible
//
// Define los contratos que los módulos del memory_engine implementan.
// Permite cambiar implementaciones sin tocar el orchestrator.
//
// Principio: Dependency Inversion (la D de SOLID).
// El orchestrator depende de estas interfaces, no de structs concretos.

use crate::memory_engine::battery_guardian::BatteryMode;
use crate::memory_engine::hierarchical_kv::KvSavingsEstimate;
use crate::memory_engine::thermal_controller::ThermalReading;

/// Sensor de temperatura del dispositivo.
/// Implementado por: ThermalController
pub trait TemperatureSensor {
    /// Muestra la temperatura actual del CPU.
    /// Retorna None si el sensor no está disponible (ej: PC sin sensores).
    fn sample(&mut self) -> Option<ThermalReading>;

    /// Recomienda acción basada en la lectura actual.
    fn recommend_action(&self, reading: &ThermalReading) -> ThermalAction;
}

/// Monitor de nivel de batería.
/// Implementado por: BatteryGuardian
pub trait PowerMonitor {
    /// Determina el modo de consumo según nivel de batería.
    fn determine_mode(&self) -> BatteryMode;

    /// Estima cuántos tokens adicionales se pueden generar
    /// con la batería restante.
    fn estimated_remaining_tokens(&self) -> Option<u64>;
}

/// Estimador de ahorro de memoria para KV cache.
/// Implementado por: HierarchicalKvCache
pub trait KvEstimator {
    /// Estima el ahorro de RAM al aplicar compresión jerárquica.
    fn estimate_savings(&self, context_tokens: usize, ram_total_mb: u64) -> KvSavingsEstimate;

    /// Recomienda el número óptimo de tokens de contexto.
    fn recommended_tokens(&self, context_tokens: usize, ram_total_mb: u64) -> usize;
}

// Re-export de tipos necesarios
pub use crate::memory_engine::thermal_controller::ThermalAction;

#[cfg(test)]
mod tests {
    use super::*;

    /// Verifica que los structs concretos implementan los traits.
    /// Estos tests son de compilación — si no compilan, el trait no está implementado.

    #[test]
    fn test_thermal_controller_implements_temperature_sensor() {
        // Si este test compila, ThermalController implementa TemperatureSensor
        fn _assert_sensor<T: TemperatureSensor>(_: &T) {}
        let controller = crate::memory_engine::thermal_controller::ThermalController::new();
        _assert_sensor(&controller);
    }

    #[test]
    fn test_battery_guardian_implements_power_monitor() {
        fn _assert_monitor<T: PowerMonitor>(_: &T) {}
        let guardian = crate::memory_engine::battery_guardian::BatteryGuardian::new();
        _assert_monitor(&guardian);
    }

    #[test]
    fn test_hierarchical_kv_implements_kv_estimator() {
        fn _assert_estimator<T: KvEstimator>(_: &T) {}
        let kv = crate::memory_engine::hierarchical_kv::HierarchicalKvCache::new(32, 128);
        _assert_estimator(&kv);
    }
}
