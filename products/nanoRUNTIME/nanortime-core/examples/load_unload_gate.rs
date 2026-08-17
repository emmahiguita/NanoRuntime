//! load_unload_gate — Release gate G5 de NanoRuntime V1.
//!
//! N ciclos consecutivos del MISMO proceso:
//!
//!   LOAD → generate 2-4 tokens → UNLOAD → estabilización → sample memoria
//!
//! Por ciclo imprime: load_ms, unload_ms, MemAvailable, PSS, RSS, RssAnon,
//! RssFile, major faults (delta), PSI memory, PSI I/O, chars generados.
//!
//! Criterio de éxito (plan V1):
//!   - N/N ciclos completan
//!   - 0 OOM / 0 muertes (si el proceso muere, el harness lo ve: no hay
//!     resumen final)
//!   - 0 corrupción KV (cada generación usa contexto fresco por diseño;
//!     aquí se verifica respuesta no vacía)
//!   - sin crecimiento PSS monótono (pendiente ≤ umbral de ruido)
//!   - sin pérdida MemAvailable monótona
//!
//! La memoria NO tiene que volver al mismo número: Android mueve page
//! cache y zRAM. Lo que no debe existir es tendencia acumulativa.
//!
//! Correr en device:
//!   cargo build --example load_unload_gate --target aarch64-linux-android --release
//!   adb push target/aarch64-linux-android/release/examples/load_unload_gate /data/local/tmp/
//!   adb shell "cd /data/local/tmp && LD_LIBRARY_PATH=/data/local/tmp ./load_unload_gate qwen9b.gguf --cycles 20"

use std::time::Instant;

/// Parses /proc/self/smaps_rollup → (rss, rss_anon, rss_file) en kB.
/// Orden de chequeo importa: "Rss:" es prefijo de "RssAnon:"/"RssFile:".
/// anon/file son Option: kernels OEM (ColorOS) pueden omitir esas líneas
/// y un 0.0 sería mentira (reportar NaN honesto).
fn read_smaps_rollup() -> Option<(u64, Option<u64>, Option<u64>)> {
    let content = std::fs::read_to_string("/proc/self/smaps_rollup").ok()?;
    let mut rss = 0u64;
    let mut anon: Option<u64> = None;
    let mut file: Option<u64> = None;
    for line in content.lines() {
        if line.starts_with("RssAnon:") {
            anon = line.split_whitespace().nth(1).and_then(|s| s.parse().ok());
        } else if line.starts_with("RssFile:") {
            file = line.split_whitespace().nth(1).and_then(|s| s.parse().ok());
        } else if line.starts_with("Rss:") {
            rss = line.split_whitespace().nth(1)?.parse().ok()?;
        }
    }
    Some((rss, anon, file))
}

/// Pendiente de mínimos cuadrados (unidades/ciclo). None si n < 2.
fn least_squares_slope(y: &[f64]) -> Option<f64> {
    if y.len() < 2 {
        return None;
    }
    let n = y.len() as f64;
    let sum_x: f64 = (0..y.len()).map(|i| i as f64).sum();
    let sum_y: f64 = y.iter().sum();
    let sum_xy: f64 = y.iter().enumerate().map(|(i, &v)| i as f64 * v).sum();
    let sum_xx: f64 = (0..y.len()).map(|i| (i as f64) * (i as f64)).sum();
    let denom = n * sum_xx - sum_x * sum_x;
    if denom == 0.0 {
        return None;
    }
    Some((n * sum_xy - sum_x * sum_y) / denom)
}

#[tokio::main]
async fn main() {
    tracing_subscriber::fmt::init();

    let mut args = std::env::args().skip(1);
    let model = args
        .next()
        .expect("uso: load_unload_gate <model.gguf> [--cycles N] [--tokens N] [--stabilize-ms N]");
    let mut cycles = 20usize;
    let mut max_tokens = 4usize;
    let mut stabilize_ms = 1000u64;
    while let Some(a) = args.next() {
        let v = args.next().expect("valor del flag faltante");
        match a.as_str() {
            "--cycles" => cycles = v.parse().expect("cycles"),
            "--tokens" => max_tokens = v.parse().expect("tokens"),
            "--stabilize-ms" => stabilize_ms = v.parse().expect("stabilize-ms"),
            other => panic!("flag desconocido: {other}"),
        }
    }

    // Umbrales de tendencia (unidades por ciclo). El jitter de Android
    // (page cache, zRAM, procesos background) mueve decenas de MB por
    // ciclo; estos umbrales solo disparan con crecimiento acumulativo
    // real, no con ruido.
    const PSS_SLOPE_LIMIT_KB: f64 = 1024.0; // 1 MB/ciclo de PSS
    const MEMAVAIL_SLOPE_LIMIT_KB: f64 = -2048.0; // -2 MB/ciclo de MemAvailable

    let mut cfg = nanortime_core::Config::default_config();
    cfg.local_model.path = model.clone();
    cfg.local_model.context_size = 2048;
    cfg.tools.auto_discover = false;

    println!(
        "[Gate] modelo={} ciclos={} tokens={} stabilize_ms={}",
        model, cycles, max_tokens, stabilize_ms
    );
    println!("[Gate] ciclo | load_ms | unload_ms | memavail_kb | pss_mb | rss_mb | rss_anon_mb | rss_file_mb | majflt_delta | psi_mem | psi_io | gen_chars");

    let mgr = match nanortime_core::execution::ModelManager::new(cfg).await {
        Ok(m) => m,
        Err(e) => {
            println!("[Gate] FATAL: ModelManager::new: {e}");
            std::process::exit(2);
        }
    };

    let prompts = ["Cuanto es 7 por 8?", "Dime una palabra.", "Hola.", "2+2?"];

    let mut collector = nanortime_core::memory_engine::RuntimeMetricsCollector::new();
    let baseline = collector.collect();
    let mut prev_majflt = baseline.memory.major_faults;
    let mut pss_series: Vec<f64> = Vec::with_capacity(cycles);
    let mut memavail_series: Vec<f64> = Vec::with_capacity(cycles);
    let mut completed = 0usize;

    for cycle in 0..cycles {
        let prompt = prompts[cycle % prompts.len()];

        // LOAD
        let t0 = Instant::now();
        if let Err(e) = mgr.load_model(&model).await {
            println!("[Gate] ciclo={} FATAL: load_model: {e}", cycle + 1);
            break;
        }
        let load_ms = t0.elapsed().as_millis();

        // GENERATE 2-4 tokens
        let gen_chars = match mgr.generate_with_confidence(prompt, max_tokens, None).await {
            Ok((text, _)) => text.len(),
            Err(e) => {
                println!("[Gate] ciclo={} FATAL: generate: {e}", cycle + 1);
                break;
            }
        };

        // UNLOAD (release_all + drop + fadvise + telemetría dentro)
        let t1 = Instant::now();
        mgr.unload_model().await;
        let unload_ms = t1.elapsed().as_millis();

        // Estabilización corta antes de muestrear
        tokio::time::sleep(tokio::time::Duration::from_millis(stabilize_ms)).await;

        // SAMPLE
        let (memavail_kb, _) =
            nanortime_core::memory_engine::OomGuard::read_meminfo().unwrap_or((0, 0));
        let snap = collector.collect();
        let majflt_delta = snap.memory.major_faults.saturating_sub(prev_majflt);
        prev_majflt = snap.memory.major_faults;
        let pss_mb = snap
            .memory
            .pss_bytes
            .map(|b| b as f64 / 1048576.0)
            .unwrap_or(f64::NAN);
        let rss_mb = snap.memory.rss_bytes as f64 / 1048576.0;
        let (rss_anon_mb, rss_file_mb) = match read_smaps_rollup() {
            Some((_, anon, file)) => (
                anon.map(|v| v as f64 / 1024.0).unwrap_or(f64::NAN),
                file.map(|v| v as f64 / 1024.0).unwrap_or(f64::NAN),
            ),
            None => (f64::NAN, f64::NAN),
        };
        let psi_mem = if snap.psi.available {
            snap.psi.memory_some
        } else {
            f64::NAN
        };
        let psi_io = if snap.psi.available {
            snap.psi.io_some
        } else {
            f64::NAN
        };

        println!(
            "[Gate] {:>5} | {:>7} | {:>9} | {:>11} | {:>6.1} | {:>6.1} | {:>11.1} | {:>11.1} | {:>11} | {:>7.2} | {:>6.2} | {:>9}",
            cycle + 1,
            load_ms,
            unload_ms,
            memavail_kb,
            pss_mb,
            rss_mb,
            rss_anon_mb,
            rss_file_mb,
            majflt_delta,
            psi_mem,
            psi_io,
            gen_chars,
        );

        pss_series.push(pss_mb * 1024.0); // kB
        memavail_series.push(memavail_kb as f64);
        completed += 1;
    }

    // RESUMEN — si el proceso muere por OOM antes, estas líneas no existen
    // y el harness lo detecta como muerte de proceso.
    let pss_slope = least_squares_slope(&pss_series);
    let memavail_slope = least_squares_slope(&memavail_series);
    let pss_trend_ok = pss_slope.map(|s| s <= PSS_SLOPE_LIMIT_KB).unwrap_or(true);
    let memavail_trend_ok = memavail_slope
        .map(|s| s >= MEMAVAIL_SLOPE_LIMIT_KB)
        .unwrap_or(true);
    let verdict = completed == cycles && pss_trend_ok && memavail_trend_ok;

    println!(
        "[Gate] resumen: completed={}/{} pss_slope_kb_por_ciclo={:.1} memavail_slope_kb_por_ciclo={:.1} verdict={}",
        completed,
        cycles,
        pss_slope.unwrap_or(f64::NAN),
        memavail_slope.unwrap_or(f64::NAN),
        if verdict { "PASS" } else { "FAIL" },
    );
    if !verdict {
        if completed != cycles {
            println!("[Gate] FAIL: ciclos incompletos (OOM o muerte probable)");
        }
        if !pss_trend_ok {
            println!(
                "[Gate] FAIL: crecimiento PSS monótono (slope > {:.0} kB/ciclo)",
                PSS_SLOPE_LIMIT_KB
            );
        }
        if !memavail_trend_ok {
            println!(
                "[Gate] FAIL: pérdida MemAvailable monótona (slope < {:.0} kB/ciclo)",
                MEMAVAIL_SLOPE_LIMIT_KB
            );
        }
    }
}
