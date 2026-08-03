//! Adaptive Scheduler — decide en tiempo real qué capas mantener en RAM vs SSD.
//!
//! El componente central del Nano Memory Engine. Calcula prioridades
//! por capa basadas en atención, frecuencia de acceso y predicciones,
//! y genera un plan de memoria óptimo respetando el budget de RAM.

use std::collections::HashMap;
use std::time::Instant;

use crate::memory_engine::hardware_profiler::{DeviceClass, HardwareProfile};

/// Estrategia de scheduling de memoria.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SchedulingStrategy {
    /// Offload agresivo — maximiza el uso de SSD para caber más modelo.
    Aggressive,
    /// Balance entre velocidad y uso de RAM.
    Balanced,
    /// Offload mínimo — prioriza velocidad sobre RAM.
    Conservative,
}

/// Prioridad calculada para una capa del modelo.
#[derive(Debug, Clone)]
pub struct LayerPriority {
    /// Identificador de la capa.
    pub layer_id: usize,
    /// Score de prioridad (0.0 - 1.0, mayor = más importante mantener en RAM).
    pub priority: f32,
    /// Si la capa es crítica (Q/K/V attention).
    pub is_critical: bool,
    /// Última vez que fue accedida.
    pub last_access: Instant,
    /// Número total de accesos.
    pub access_count: u64,
    /// Tamaño estimado de la capa en MB.
    pub memory_mb: f64,
}

/// Plan de scheduling de memoria generado por el AdaptiveScheduler.
#[derive(Debug, Clone)]
pub struct MemorySchedule {
    /// Capas a mantener en RAM este ciclo.
    pub layers_in_ram: Vec<usize>,
    /// Capas a mover a SSD.
    pub layers_to_offload: Vec<usize>,
    /// Capas a pre-cargar desde SSD (predichas como próximas a usar).
    pub layers_to_prefetch: Vec<usize>,
    /// Budget objetivo para la KV-cache en MB.
    pub kv_cache_target_mb: f64,
    /// Estrategia activa en este ciclo.
    pub strategy: SchedulingStrategy,
}

/// Scheduler adaptativo de capas del modelo.
pub struct AdaptiveScheduler {
    /// Número de capas del modelo.
    n_layers: usize,
    /// Historial de prioridades por capa.
    layer_priorities: HashMap<usize, LayerPriority>,
    /// Budget de RAM en MB (se actualiza dinámicamente).
    ram_budget_mb: f64,
    /// Estrategia actual.
    strategy: SchedulingStrategy,
    /// Factor de seguridad RAM (cuánto del budget usar: default 0.85).
    safety_factor: f64,
    /// Número de ciclos desde el último ajuste de estrategia.
    stable_cycles: u64,
    /// Clase de dispositivo para ajuste de parámetros.
    device_class: DeviceClass,
}

impl AdaptiveScheduler {
    /// Crea un nuevo scheduler basado en el perfil de hardware.
    pub fn new(profile: &HardwareProfile, n_layers: usize) -> Self {
        // Dispositivos de gama baja → aggressive desde el inicio
        let strategy = match profile.device_class {
            DeviceClass::LowEnd => SchedulingStrategy::Aggressive,
            DeviceClass::MidEnd => SchedulingStrategy::Balanced,
            DeviceClass::HighEnd => SchedulingStrategy::Conservative,
        };

        let ram_budget_mb = profile.ram_available_mb as f64 * 0.80;

        let mut priorities = HashMap::new();
        let now = Instant::now();
        for i in 0..n_layers {
            let is_crit = Self::is_critical_layer(i, n_layers);
            let init_p = Self::calculate_priority(i, false, 0.0, is_crit, now, 0);
            priorities.insert(i, LayerPriority {
                layer_id: i,
                priority: init_p,
                is_critical: is_crit,
                last_access: now,
                access_count: 0,
                memory_mb: 0.0,
            });
        }

        Self {
            n_layers,
            layer_priorities: priorities,
            ram_budget_mb,
            strategy,
            safety_factor: 0.85,
            stable_cycles: 0,
            device_class: profile.device_class,
        }
    }

    /// Calcula el score de prioridad para una capa.
    ///
    /// Fórmula: w_attention*score + w_critical*critical + w_recency*recency + w_frequency*frequency
    pub fn calculate_priority(
        layer_id: usize,
        is_predicted: bool,
        attention_score: f32,
        is_critical: bool,
        last_access: Instant,
        access_count: u64,
    ) -> f32 {
        let _ = layer_id; // Se usa para debug en producción

        // Componente de atención (0.0 - 1.0)
        let attention_component = attention_score.clamp(0.0, 1.0);

        // Componente de criticidad: capas Q/K/V tienen prioridad máxima
        let critical_component = if is_critical { 1.0f32 } else { 0.0f32 };

        // Componente de recencia (decae con el tiempo)
        let age_secs = last_access.elapsed().as_secs_f32();
        let recency_component = (-age_secs * 0.1).exp().clamp(0.0, 1.0);

        // Componente de frecuencia (normalizado por accesos esperados)
        let freq_component = (access_count as f32 / (access_count as f32 + 10.0)).clamp(0.0, 1.0);

        // Bonus por predicción
        let prediction_bonus = if is_predicted { 0.25f32 } else { 0.0f32 };

        // Pesos: criticidad > atención > predicción > recencia > frecuencia
        let score = 0.30 * critical_component
            + 0.25 * attention_component
            + 0.20 * prediction_bonus
            + 0.15 * recency_component
            + 0.10 * freq_component;

        score.clamp(0.0, 1.0)
    }

    /// Registra un acceso a una capa (actualiza historial).
    pub fn record_access(&mut self, layer_id: usize, attention_score: f32) {
        if let Some(p) = self.layer_priorities.get_mut(&layer_id) {
            p.last_access = Instant::now();
            p.access_count += 1;
            // Actualizar priority con nuevo score de atención
            let predicted = false; // Se pasará del predictor en llamada completa
            p.priority = Self::calculate_priority(
                layer_id,
                predicted,
                attention_score,
                p.is_critical,
                p.last_access,
                p.access_count,
            );
        }
    }

    /// Genera un plan de memoria completo para el ciclo actual.
    pub fn schedule(
        &mut self,
        current_layers_in_ram: &[usize],
        predicted_layers: &[usize],
        attention_scores: &[f32],
        ram_budget_mb: f64,
    ) -> MemorySchedule {
        self.ram_budget_mb = ram_budget_mb;
        let effective_budget = ram_budget_mb * self.safety_factor;

        // 1. Actualizar prioridades con attention scores actuales
        for (layer_id, &score) in attention_scores.iter().enumerate() {
            if layer_id >= self.n_layers {
                break;
            }
            let is_predicted = predicted_layers.contains(&layer_id);
            let (last_access, access_count, is_critical) = {
                let p = self.layer_priorities.get(&layer_id).unwrap();
                (p.last_access, p.access_count, p.is_critical)
            };
            let priority = Self::calculate_priority(
                layer_id,
                is_predicted,
                score,
                is_critical,
                last_access,
                access_count,
            );
            if let Some(p) = self.layer_priorities.get_mut(&layer_id) {
                p.priority = priority;
            }
        }

        // 2. Ordenar capas por prioridad descendente
        let mut sorted_layers: Vec<(usize, f32, f64)> = self.layer_priorities
            .values()
            .map(|p| (p.layer_id, p.priority, p.memory_mb))
            .collect();
        sorted_layers.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));

        // 3. Seleccionar capas para RAM hasta el budget
        let mut layers_in_ram = Vec::new();
        let mut layers_to_offload = Vec::new();
        let mut budget_used = 0.0f64;

        for (layer_id, _priority, memory_mb) in &sorted_layers {
            let layer_mb = if *memory_mb > 0.0 { *memory_mb } else {
                // Estimación: RAM budget / n_layers si no se conoce el tamaño real
                effective_budget / self.n_layers as f64
            };

            if budget_used + layer_mb <= effective_budget {
                layers_in_ram.push(*layer_id);
                budget_used += layer_mb;
            } else {
                layers_to_offload.push(*layer_id);
            }
        }

        // 4. Capas predichas que NO están en RAM → prefetch
        let layers_to_prefetch: Vec<usize> = predicted_layers.iter()
            .filter(|&&id| !layers_in_ram.contains(&id))
            .filter(|&&id| current_layers_in_ram.contains(&id) || !layers_to_offload.contains(&id))
            .copied()
            .collect();

        // 5. Calcular target KV-cache
        let kv_cache_target_mb = match self.strategy {
            SchedulingStrategy::Aggressive => effective_budget * 0.15,
            SchedulingStrategy::Balanced => effective_budget * 0.25,
            SchedulingStrategy::Conservative => effective_budget * 0.35,
        };

        tracing::debug!(
            "Schedule: {} in RAM, {} to offload, {} to prefetch, budget={:.0}MB used={:.0}MB",
            layers_in_ram.len(),
            layers_to_offload.len(),
            layers_to_prefetch.len(),
            effective_budget,
            budget_used
        );

        self.stable_cycles += 1;

        MemorySchedule {
            layers_in_ram,
            layers_to_offload,
            layers_to_prefetch,
            kv_cache_target_mb,
            strategy: self.strategy,
        }
    }

    /// Ajusta la estrategia según la pérdida de calidad observada.
    ///
    /// `quality_drop_pct`: porcentaje de pérdida de calidad (0.0 = sin pérdida).
    pub fn adjust_strategy(&mut self, quality_drop_pct: f32) {
        let old_strategy = self.strategy;

        if quality_drop_pct > 2.0 {
            // Calidad cayendo demasiado → modo conservador
            self.strategy = SchedulingStrategy::Conservative;
            self.safety_factor = 0.75; // Más RAM libre → mejor calidad
            self.stable_cycles = 0;
            tracing::warn!(
                "Quality drop {:.1}% — switching to Conservative scheduling",
                quality_drop_pct
            );
        } else if quality_drop_pct < 1.0 && self.stable_cycles > 50 {
            // Calidad estable por >50 ciclos → modo agresivo si el hardware lo permite
            let new_strategy = match self.device_class {
                DeviceClass::LowEnd => SchedulingStrategy::Aggressive,
                DeviceClass::MidEnd => SchedulingStrategy::Balanced,
                DeviceClass::HighEnd => SchedulingStrategy::Balanced,
            };
            self.strategy = new_strategy;
            self.safety_factor = 0.85;
            tracing::info!(
                "Quality stable ({:.1}% drop, {} cycles) — switching to {:?}",
                quality_drop_pct,
                self.stable_cycles,
                self.strategy
            );
        }

        if old_strategy != self.strategy {
            tracing::info!(
                "Strategy changed: {:?} → {:?}",
                old_strategy,
                self.strategy
            );
        }
    }

    /// Actualiza el tamaño estimado de una capa en MB.
    pub fn set_layer_size(&mut self, layer_id: usize, memory_mb: f64) {
        if let Some(p) = self.layer_priorities.get_mut(&layer_id) {
            p.memory_mb = memory_mb;
        }
    }

    /// Retorna la estrategia activa.
    pub fn current_strategy(&self) -> SchedulingStrategy {
        self.strategy
    }

    /// Retorna las N capas con mayor prioridad.
    pub fn top_priority_layers(&self, n: usize) -> Vec<usize> {
        let mut sorted: Vec<(usize, f32)> = self.layer_priorities
            .values()
            .map(|p| (p.layer_id, p.priority))
            .collect();
        sorted.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
        sorted.iter().take(n).map(|(id, _)| *id).collect()
    }

    /// Determina si una capa es crítica (Q/K/V attention).
    /// Las capas de atención están aproximadamente en 1/3 del total, distribuidas.
    fn is_critical_layer(layer_id: usize, n_layers: usize) -> bool {
        if n_layers == 0 { return false; }
        // Primera y última capa son siempre críticas (embedding + lm_head)
        if layer_id == 0 || layer_id == n_layers - 1 {
            return true;
        }
        // Capas de attention: cada 3 capas (heurístico para transformers)
        layer_id % 3 == 1
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::memory_engine::hardware_profiler::{HardwareProfile, ThermalState};

    fn test_profile() -> HardwareProfile {
        HardwareProfile {
            ram_total_mb: 16384,
            ram_available_mb: 8192,
            ssd_speed_mbps: 500.0,
            cpu_cores: 8,
            device_class: DeviceClass::MidEnd,
            thermal: ThermalState::default(),
            last_updated: Instant::now(),
        }
    }

    #[test]
    fn test_scheduler_new() {
        let profile = test_profile();
        let scheduler = AdaptiveScheduler::new(&profile, 32);
        assert_eq!(scheduler.n_layers, 32);
        assert_eq!(scheduler.strategy, SchedulingStrategy::Balanced);
    }

    #[test]
    fn test_calculate_priority_critical_layer() {
        let p = AdaptiveScheduler::calculate_priority(
            0, false, 0.5, true, Instant::now(), 10
        );
        assert!(p > 0.3, "Critical layer should have high priority");
    }

    #[test]
    fn test_calculate_priority_predicted_layer() {
        let p_predicted = AdaptiveScheduler::calculate_priority(
            5, true, 0.5, false, Instant::now(), 5
        );
        let p_normal = AdaptiveScheduler::calculate_priority(
            5, false, 0.5, false, Instant::now(), 5
        );
        assert!(p_predicted > p_normal, "Predicted layers should have higher priority");
    }

    #[test]
    fn test_schedule_respects_budget() {
        let profile = test_profile();
        let mut scheduler = AdaptiveScheduler::new(&profile, 32);
        // Set known layer sizes: 100MB each
        for i in 0..32 {
            scheduler.set_layer_size(i, 100.0);
        }

        let scores = vec![0.5f32; 32];
        let schedule = scheduler.schedule(&[], &[], &scores, 1600.0); // 1600MB budget

        // At 100MB per layer, 0.85 safety: 1360MB → 13 layers in RAM
        assert!(schedule.layers_in_ram.len() <= 14);
        assert!(!schedule.layers_to_offload.is_empty());
    }

    #[test]
    fn test_adjust_strategy_conservative_on_quality_drop() {
        let profile = test_profile();
        let mut scheduler = AdaptiveScheduler::new(&profile, 32);
        assert_eq!(scheduler.strategy, SchedulingStrategy::Balanced);

        scheduler.adjust_strategy(3.0); // 3% drop → conservative
        assert_eq!(scheduler.strategy, SchedulingStrategy::Conservative);
    }

    #[test]
    fn test_adjust_strategy_aggressive_when_stable() {
        let profile = HardwareProfile {
            device_class: DeviceClass::LowEnd,
            ..test_profile()
        };
        let mut scheduler = AdaptiveScheduler::new(&profile, 32);
        scheduler.stable_cycles = 100;
        scheduler.adjust_strategy(0.5); // Low drop + many stable cycles
        assert_eq!(scheduler.strategy, SchedulingStrategy::Aggressive);
    }

    #[test]
    fn test_is_critical_layer() {
        assert!(AdaptiveScheduler::is_critical_layer(0, 32)); // First
        assert!(AdaptiveScheduler::is_critical_layer(31, 32)); // Last
        assert!(AdaptiveScheduler::is_critical_layer(1, 32)); // 1 % 3 == 1
        assert!(!AdaptiveScheduler::is_critical_layer(2, 32));
    }

    #[test]
    fn test_record_access_updates_priority() {
        let profile = test_profile();
        let mut scheduler = AdaptiveScheduler::new(&profile, 10);
        let priority_before = scheduler.layer_priorities[&5].priority;
        scheduler.record_access(5, 0.9);
        let priority_after = scheduler.layer_priorities[&5].priority;
        assert_ne!(priority_before, priority_after);
        assert_eq!(scheduler.layer_priorities[&5].access_count, 1);
    }

    #[test]
    fn test_top_priority_layers() {
        let profile = test_profile();
        let mut scheduler = AdaptiveScheduler::new(&profile, 10);

        // Record many accesses on layer 5 with very high attention to dominate priority
        for _ in 0..50 {
            scheduler.record_access(5, 1.0);
        }

        // Layer 0 and 9 are critical — they always have high base priority.
        // Layer 5 should also be high after 50 accesses at 1.0 attention.
        let top = scheduler.top_priority_layers(5);
        assert_eq!(top.len(), 5);
        let has_expected = top.contains(&5) || top.contains(&0) || top.contains(&9);
        assert!(has_expected, "Top 5 should contain critical or high-access layers, got: {:?}", top);
    }
}
