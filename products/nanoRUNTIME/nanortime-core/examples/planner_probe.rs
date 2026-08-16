//! Probe REAL del RuntimePlanner — el lazo OBSERVE → PLAN → ADAPT con
//! señales reales del OS, sin simulación.
//!
//! Correr: cargo run --example planner_probe
//! En dispositivo: adb shell /data/local/tmp/planner_probe

use nanortime_core::memory_engine::{
    InferenceBudget, Measurements, Observations, RuntimePlanner, ThermalCondition,
};

fn main() {
    tracing_subscriber::fmt::init();

    println!("═══ OBSERVE — señales REALES del OS ═══");
    let obs = Observations::sample();
    println!(
        "[observe] ram_total={}MB avail={}MB big_cores={} tier={:?} zram={} npu={}",
        obs.device.ram_total_mb,
        obs.device.ram_available_mb,
        obs.device.big_cores,
        obs.device.tier,
        obs.device.zram_active,
        obs.device.npu_available,
    );
    println!(
        "[observe] thermal={:?} battery={:?} thrashing={:?}",
        obs.thermal, obs.battery, obs.thrashing,
    );
    println!(
        "[observe] runtime: rss={:.1}MB pss={:?} avail={:.1}MB fault_rate={:.2}/s pressure={:.2}",
        obs.runtime.memory.rss_bytes as f64 / 1048576.0,
        obs.runtime.memory.pss_bytes.map(|b| format!("{:.1}MB", b as f64 / 1048576.0)),
        obs.runtime.memory.available_bytes as f64 / 1048576.0,
        obs.runtime.memory.fault_rate,
        obs.runtime.memory.pressure_ratio,
    );

    println!("\n═══ PLAN — un presupuesto, no un modelo ═══");
    let planner = RuntimePlanner::new();
    for budget_mb in [1_200u64, 2_500, 4_500, 6_000] {
        let budget = InferenceBudget {
            max_memory_mb: budget_mb,
            ..InferenceBudget::default()
        };
        let plan = planner.plan(&budget, &obs);
        println!("[plan {}MB] {}", budget_mb, plan.summary);
    }

    println!("\n═══ ADAPT — medir y replanificar ═══");
    let budget = InferenceBudget {
        max_memory_mb: 2_500,
        ..InferenceBudget::default()
    };
    let prev = planner.plan(&budget, &obs);
    println!("[before] {}", prev.summary);

    // Caso 1: thrashing severo → debe encoger el plan.
    let thrash = Measurements {
        tok_s: 1.2,
        ttft_ms: 2400.0,
        quality: 0.82,
        fault_rate: 180.0,
        thermal: ThermalCondition::Warm,
    };
    let adapted = planner.adapt(&budget, &obs, &prev, &thrash);
    println!("[thrash] {}", adapted.summary);

    // Caso 2: sano → sin cambios.
    let healthy = Measurements {
        tok_s: 8.0,
        ttft_ms: 400.0,
        quality: 0.91,
        fault_rate: 2.0,
        thermal: ThermalCondition::Cool,
    };
    let kept = planner.adapt(&budget, &obs, &prev, &healthy);
    println!("[healthy] {}", kept.summary);
}
