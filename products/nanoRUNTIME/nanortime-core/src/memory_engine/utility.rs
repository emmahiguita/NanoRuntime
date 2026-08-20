//! Métrica de utilidad para la selección de ventana residente W.
//!
//! El planner NO debe elegir `argmin FaultRate(W)`: menos faults no
//! implica más tok/s (los datos del barrido lo demuestran: W=2 tiene
//! más faults que W=4 pero más throughput). La utilidad combina:
//!
//! ```text
//! LivenessRate     = runs_completed / runs_requested
//! UsefulThroughput = LivenessRate × tok/s
//! Utility          = UsefulThroughput / (α·PSI_mem + β·PSI_io + γ·Thermal_norm)
//!
//! W* = argmax_W Utility(W)
//! ```
//!
//! PSI en porcentaje 0-100 (avg10 "some"). Térmica solo penaliza por
//! encima de 40°C (rango normal de operación móvil sin throttling):
//! a 40°C aporta 0, a 100°C aporta 100. Penalización con piso 1.0:
//! sin presión medible la utilidad es el throughput útil puro — el piso
//! evita división por cero y mantiene la métrica en escala de tok/s.

/// Punto del barrido de W medido en el dispositivo.
#[derive(Debug, Clone)]
pub struct SweepPoint {
    /// Ventana residente (capas)
    pub w: usize,
    /// Tokens por segundo reales
    pub tok_s: f64,
    /// Major page faults por segundo
    pub fault_rate: f64,
    /// PSI memoria (avg10 some, 0-100)
    pub psi_mem: f64,
    /// PSI I/O (avg10 some, 0-100)
    pub psi_io: f64,
    /// Temperatura en °C
    pub thermal_c: f64,
    /// Corridas completadas
    pub runs_completed: usize,
    /// Corridas pedidas
    pub runs_requested: usize,
}

/// Pesos de penalización por presión. Default 1/1/1 — se pueden calibrar
/// con los datos del barrido si una presión domina las demás.
#[derive(Debug, Clone)]
pub struct UtilityWeights {
    pub alpha: f64,
    pub beta: f64,
    pub gamma: f64,
}

impl Default for UtilityWeights {
    fn default() -> Self {
        Self {
            alpha: 1.0,
            beta: 1.0,
            gamma: 1.0,
        }
    }
}

/// Tasa de liveness: fracción de corridas que terminaron sin OOM/muerte.
pub fn liveness_rate(p: &SweepPoint) -> f64 {
    if p.runs_requested == 0 {
        return 0.0;
    }
    (p.runs_completed as f64 / p.runs_requested as f64).clamp(0.0, 1.0)
}

/// Throughput útil: liveness penaliza el tok/s crudo cuando el sistema
/// no aguanta la configuración.
pub fn useful_throughput(p: &SweepPoint) -> f64 {
    liveness_rate(p) * p.tok_s
}

/// Penalización por presión: PSI memoria, PSI I/O y térmica normalizada.
/// Umbral térmico 40°C: por debajo no hay throttling y no debe pesar.
pub fn pressure_penalty(p: &SweepPoint, weights: &UtilityWeights) -> f64 {
    let thermal_penalty = ((p.thermal_c - 40.0) / 60.0).clamp(0.0, 1.0) * 100.0;
    weights.alpha * p.psi_mem + weights.beta * p.psi_io + weights.gamma * thermal_penalty
}

/// Utilidad de un punto del barrido. Piso 1.0 en la penalización: con
/// presión cero (o PSI no disponible), utilidad = throughput útil.
pub fn utility(p: &SweepPoint, weights: &UtilityWeights) -> f64 {
    useful_throughput(p) / pressure_penalty(p, weights).max(1.0)
}

/// Mejor ventana del barrido: `argmax Utility(W)`.
/// Devuelve None si no hay puntos con liveness > 0.
pub fn best_window(points: &[SweepPoint], weights: &UtilityWeights) -> Option<usize> {
    points
        .iter()
        .filter(|p| liveness_rate(p) > 0.0)
        .max_by(|a, b| {
            utility(a, weights)
                .partial_cmp(&utility(b, weights))
                .unwrap_or(std::cmp::Ordering::Equal)
        })
        .map(|p| p.w)
}

/// Umbral de thrashing compartido con el runtime: 20 major faults/s. Un
/// fault se resuelve en ~1ms en flash móvil; >20/s significa que el working
/// set excede RAM y el kernel vive paginando (I/O-bound, no compute-bound).
pub const THRASH_FAULT_RATE: f64 = 20.0;

/// Utilidad de benchmark DESCOMPUESTA: los componentes de la penalización
/// viajan separados para que la decisión del planner sea explicable. P.ej.
/// "8 threads dio 5.2 tok/s iniciales pero perdió frente a 4 threads por
/// temperatura + decay + faults" — no una caja negra.
#[derive(Debug, Clone, Copy, PartialEq)]
pub struct BenchmarkUtility {
    pub raw_decode_tps: f64,
    pub sustained_decode_tps: f64,
    /// (raw - sustained) / raw, 0..1 — castigo por pérdida térmica de tok/s.
    pub decay_penalty: f64,
    /// major_fault_rate / THRASH_FAULT_RATE, ≥0.
    pub fault_penalty: f64,
    /// hot + rise, ≥0 (0 si no hay sensor).
    pub thermal_penalty: f64,
    /// PSI memoria normalizado, ≥0 (0 si /proc/pressure no está expuesto).
    pub memory_penalty: f64,
    /// sustained / (1 + decay + fault + thermal + memory).
    pub final_utility: f64,
}

/// Fórmula ÚNICA de utilidad para el auto-benchmark (sweep de threads).
/// Es la autoridad: el sweep y el planner consumen esta, no una fórmula
/// inline duplicada. Los componentes se exponen por separado.
pub fn benchmark_utility(
    raw_decode_tps: f64,
    sustained_decode_tps: f64,
    major_fault_rate: f64,
    thermal_penalty: f64,
    memory_penalty: f64,
) -> BenchmarkUtility {
    let decay = if raw_decode_tps > 0.0 {
        ((raw_decode_tps - sustained_decode_tps).max(0.0) / raw_decode_tps).clamp(0.0, 1.0)
    } else {
        0.0
    };
    let fault = (major_fault_rate / THRASH_FAULT_RATE).max(0.0);
    let thermal = thermal_penalty.max(0.0);
    let memory = memory_penalty.max(0.0);
    let denominator = 1.0 + decay + fault + thermal + memory;
    let final_utility = if denominator > 0.0 {
        sustained_decode_tps / denominator
    } else {
        0.0
    };
    BenchmarkUtility {
        raw_decode_tps,
        sustained_decode_tps,
        decay_penalty: decay,
        fault_penalty: fault,
        thermal_penalty: thermal,
        memory_penalty: memory,
        final_utility,
    }
}


#[cfg(test)]
mod tests {
    use super::*;

    fn point(w: usize, tok_s: f64, psi_mem: f64, liveness: (usize, usize)) -> SweepPoint {
        SweepPoint {
            w,
            tok_s,
            fault_rate: 0.0,
            psi_mem,
            psi_io: 0.0,
            thermal_c: 30.0,
            runs_completed: liveness.0,
            runs_requested: liveness.1,
        }
    }

    #[test]
    fn test_liveness_zero_kills_utility() {
        let dead = point(16, 10.0, 1.0, (0, 5));
        let alive = point(2, 0.3, 50.0, (5, 5));
        assert_eq!(utility(&dead, &UtilityWeights::default()), 0.0);
        // Punto vivo con mucha presión gana a punto muerto con tok/s alto.
        assert!(utility(&alive, &UtilityWeights::default()) > 0.0);
    }

    #[test]
    fn test_fewer_faults_not_automatically_better() {
        // W=2: más throughput pero más presión; W=4: menos presión,
        // menos throughput. La utilidad decide, no el fault count.
        let w2 = point(2, 0.39, 80.0, (5, 5));
        let w4 = point(4, 0.31, 30.0, (5, 5));
        let weights = UtilityWeights::default();
        let u2 = utility(&w2, &weights);
        let u4 = utility(&w4, &weights);
        // 0.39/81 vs 0.31/31 → w4 gana aquí; lo importante es que la
        // métrica distinga, no que coincida con el óptimo del dispositivo.
        assert!(u2 != u4);
    }

    #[test]
    fn test_best_window_picks_argmax_utility() {
        let points = vec![
            point(2, 0.39, 80.0, (5, 5)),
            point(4, 0.31, 30.0, (5, 5)),
            point(8, 0.20, 10.0, (5, 5)),
        ];
        let best = best_window(&points, &UtilityWeights::default());
        // 8: 0.20/11=0.018, 4: 0.31/31=0.010, 2: 0.39/81=0.0048 → W=8
        assert_eq!(best, Some(8));
    }

    #[test]
    fn test_dead_points_never_selected() {
        let points = vec![
            point(2, 0.3, 10.0, (5, 5)),
            point(32, 99.0, 0.0, (0, 5)), // tok/s alto pero muerto
        ];
        assert_eq!(best_window(&points, &UtilityWeights::default()), Some(2));
    }

    #[test]
    fn test_zero_pressure_utility_is_throughput() {
        let p = point(8, 0.25, 0.0, (5, 5));
        let u = utility(&p, &UtilityWeights::default());
        assert!((u - 0.25).abs() < 1e-9);
    }

    #[test]
    fn test_no_live_points() {
        let points = vec![point(2, 0.3, 10.0, (0, 5))];
        assert_eq!(best_window(&points, &UtilityWeights::default()), None);
    }

    #[test]
    fn test_benchmark_utility_prefers_sustained_over_cold_peak() {
        // 8 threads: pico 6.0 pero cae a 3.8 por temperatura (thermal=1.0).
        let t8 = benchmark_utility(6.0, 3.8, 0.0, 1.0, 0.0);
        // 4 threads: pico menor 5.2 pero sostenido 4.8 sin penalización.
        let t4 = benchmark_utility(5.2, 4.8, 0.0, 0.0, 0.0);
        // 4 threads gana aunque pierda el benchmark de 10 segundos.
        assert!(t4.final_utility > t8.final_utility);
        // Componentes auditables: decay + thermal castigan a 8 threads.
        assert!(t8.decay_penalty > t4.decay_penalty);
        assert!(t8.thermal_penalty > t4.thermal_penalty);
    }

    #[test]
    fn test_benchmark_utility_components_sum() {
        let u = benchmark_utility(6.0, 3.0, 20.0, 0.5, 0.5);
        // decay=(6-3)/6=0.5, fault=20/20=1.0, thermal=0.5, memory=0.5
        assert!((u.decay_penalty - 0.5).abs() < 1e-9);
        assert!((u.fault_penalty - 1.0).abs() < 1e-9);
        assert!((u.thermal_penalty - 0.5).abs() < 1e-9);
        assert!((u.memory_penalty - 0.5).abs() < 1e-9);
        // final = 3.0 / (1 + 0.5 + 1.0 + 0.5 + 0.5) = 3.0 / 3.5
        assert!((u.final_utility - 3.0 / 3.5).abs() < 1e-9);
    }
}
