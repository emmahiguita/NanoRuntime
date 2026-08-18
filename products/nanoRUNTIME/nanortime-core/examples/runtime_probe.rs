//! Probe REAL — verifica la inyección de RuntimeMetricsCollector en
//! ModelManager ejecutando inferencia real contra un GGUF en disco.
//! No es un test unitario: corre el código de producción con datos reales.
//!
//! Correr: cargo run --example runtime_probe
//! Logs:   RUST_LOG=nanortime_core=debug cargo run --example runtime_probe

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();

    println!("═══ 1. Collector directo — métricas REALES del OS ═══");
    let mut collector = nanortime_core::memory_engine::RuntimeMetricsCollector::new();
    let first = collector.collect();
    println!(
        "[probe] collect#1 rss_mb={:.1} pss={:?} avail_mb={:.1} pressure={:.3} minflt={} majflt={} fault_rate={:.2}/s thrash={}",
        first.memory.rss_bytes as f64 / 1048576.0,
        first
            .memory
            .pss_bytes
            .map(|b| format!("{:.1}MB", b as f64 / 1048576.0)),
        first.memory.available_bytes as f64 / 1048576.0,
        first.memory.pressure_ratio,
        first.memory.minor_faults,
        first.memory.major_faults,
        first.memory.fault_rate,
        collector.is_thrashing(20.0),
    );

    // Carga real de CPU → segundo collect con delta de faults real
    let mut sink: u64 = 0;
    for i in 0..2_000_000 {
        sink = sink.wrapping_add(i % 977);
    }
    std::hint::black_box(sink);

    let second = collector.collect();
    println!(
        "[probe] collect#2 rss_mb={:.1} minflt={} majflt={} delta_majflt={} fault_rate={:.2}/s thrash={}",
        second.memory.rss_bytes as f64 / 1048576.0,
        second.memory.minor_faults,
        second.memory.major_faults,
        second.memory.major_faults.saturating_sub(first.memory.major_faults),
        second.memory.fault_rate,
        collector.is_thrashing(20.0),
    );

    println!("\n═══ 2. ModelManager real — carga + generación ═══");
    let model_path = "C:\\llama-cpp-server\\models\\qwen2.5-1.5b-instruct-q4_k_m.gguf";
    let mut cfg = nanortime_core::Config::default_config();
    cfg.local_model.path = model_path.to_string();
    cfg.local_model.context_size = 2048;
    cfg.tools.auto_discover = false;

    let mgr = nanortime_core::execution::ModelManager::new(cfg)
        .await
        .expect("ModelManager::new");
    mgr.load_model(model_path).await.expect("load_model");

    // generate_with_confidence → dispara update_memory_engine_metrics
    // → collector.collect() real + is_thrashing + logs [RuntimeMetrics]
    match mgr.generate_with_confidence("Hello!", 24, None).await {
        Ok((text, probs)) => {
            println!(
                "[probe] generate OK: {} chars, {} probs",
                text.len(),
                probs.len()
            );
            println!(
                "[probe]   text: {}",
                text.chars().take(120).collect::<String>()
            );
        }
        Err(e) => println!("[probe] generate FAILED: {e}"),
    }

    // generate_streaming → baseline collect + record_token por callback
    // (latencia inter-token REAL) + snapshot post-gen [RuntimeMetrics]
    println!("\n═══ 3. Streaming real — callback de tokens ═══");
    match mgr
        .generate_streaming("Say hi.", 16, Some("probe-session"), None)
        .await
    {
        Ok((res_rx, mut tok_rx)) => {
            while let Some((t, _p)) = tok_rx.recv().await {
                print!("{t}");
            }
            println!();
            match res_rx.await {
                Ok(Ok((text, _, _))) => println!("[probe] streaming OK: {} chars", text.len()),
                Ok(Err(e)) => println!("[probe] streaming FAILED: {e}"),
                Err(e) => println!("[probe] oneshot closed: {e}"),
            }
        }
        Err(e) => println!("[probe] generate_streaming setup FAILED: {e}"),
    }
}
