//! Benchmark de consumo de memoria y tiempo de ejecución del Nano Memory Engine.

use nanortime_core::memory_engine::{HardwareProfiler, NanoMemoryEngine};
use std::time::Instant;

fn main() {
    println!("=== NanoAI Runtime — Memory Engine Benchmark ===");

    let mut profiler = HardwareProfiler::new();
    let profile = profiler.profile();

    println!("[Hardware Profile]");
    println!("  RAM Total:     {} MB", profile.ram_total_mb);
    println!("  RAM Available: {} MB", profile.ram_available_mb);
    println!("  SSD Speed:     {:.1} MB/s", profile.ssd_speed_mbps);
    println!("  CPU Cores:     {}", profile.cpu_cores);
    println!("  Device Class:  {:?}", profile.device_class);

    println!("\n[Benchmarking 1000 Generation Cycles]");
    let mut engine = NanoMemoryEngine::new(32);
    let start = Instant::now();

    for i in 0..1000 {
        let mut scores = vec![0.2f32; 32];
        scores[i % 32] = 0.95; // Hot layer rotates
        let _schedule = engine.compute_schedule(&scores);
        let _report = engine.evaluate_quality(10.0 + (i % 5) as f32 * 0.1);
    }

    let elapsed = start.elapsed();
    println!("  Completed 1,000 cycles in {:.2?}", elapsed);
    println!(
        "  Average latency per token cycle: {:.3} µs",
        elapsed.as_micros() as f64 / 1000.0
    );
    println!("  Status Report: {}", engine.status_report());
}
