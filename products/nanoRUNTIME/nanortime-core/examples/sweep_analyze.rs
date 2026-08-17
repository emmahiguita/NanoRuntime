//! Análisis del barrido G6 — agrega el CSV del sweep por W y calcula
//! la utilidad con el módulo `memory_engine::utility`.
//!
//! Entrada: CSV de `w_sweep_clean.ps1` (columnas run,order,w,rep,success,
//! tok_s,fault_rate,pss_mb,ttft_ms,tok_avg_ms,tok_p90_ms,thrash). La columna
//! `w` puede ser un número o "auto" (Run D).
//!
//! Por W:
//! - `tok_s` = media de las corridas OK (las muertas no generan tokens).
//! - `LivenessRate` = corridas OK / corridas pedidas.
//! - `UsefulThroughput` = LivenessRate × tok_s.
//! - `Utility` = UsefulThroughput / penalty (PSI/térmica en 0 si no están
//!   en el CSV — honesto: ColorOS no expone /proc/pressure).
//! - `W*` = argmax Utility.
//!
//! La fila AUTO es la crítica del plan: Utility(AUTO) debe acercarse a
//! Utility(W*) — si el planner sin env ya elige ≈ W*, V1 queda validado.
//!
//! Uso:
//!   cargo run --example sweep_analyze -- w_sweep_clean.csv

use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::path::Path;

use nanortime_core::memory_engine::utility::{best_window, utility, SweepPoint, UtilityWeights};

/// Una medición cruda del CSV.
struct RawRow {
    /// "2", "16"… o "auto".
    w: String,
    success: bool,
    tok_s: Option<f64>,
    fault_rate: Option<f64>,
}

fn parse_csv(path: &Path) -> Vec<RawRow> {
    let text = fs::read_to_string(path)
        .unwrap_or_else(|e| panic!("no se pudo leer {}: {}", path.display(), e));
    let mut rows = Vec::new();
    for line in text.lines().skip(1) {
        let cols: Vec<&str> = line.split(',').collect();
        if cols.len() < 12 {
            continue;
        }
        let parse = |s: &str| -> Option<f64> {
            if s.is_empty() || s == "-" {
                None
            } else {
                s.parse().ok()
            }
        };
        rows.push(RawRow {
            w: cols[2].trim().to_string(),
            success: cols[4].trim() == "OK",
            tok_s: parse(cols[5].trim()),
            fault_rate: parse(cols[6].trim()),
        });
    }
    rows
}

fn main() {
    let path = env::args()
        .nth(1)
        .expect("uso: sweep_analyze <w_sweep_clean.csv>");
    let rows = parse_csv(Path::new(&path));
    if rows.is_empty() {
        eprintln!("CSV sin filas de datos: {}", path);
        std::process::exit(2);
    }

    // Agregación por W (orden numérico; "auto" al final).
    let mut by_w: BTreeMap<String, Vec<&RawRow>> = BTreeMap::new();
    for r in &rows {
        by_w.entry(r.w.clone()).or_default().push(r);
    }

    let weights = UtilityWeights::default();
    let mut points: Vec<SweepPoint> = Vec::new();
    let mut auto_point: Option<SweepPoint> = None;

    println!(
        "{:>5} {:>8} {:>9} {:>9} {:>11} {:>11} {:>10}",
        "W", "liveness", "tok_s", "fault/s", "useful_tps", "utility", "nota"
    );
    println!("{}", "-".repeat(74));

    for (w, group) in &by_w {
        let requested = group.len();
        let completed = group.iter().filter(|r| r.success).count();
        let tok_values: Vec<f64> = group.iter().filter_map(|r| r.tok_s).collect();
        let fault_values: Vec<f64> = group.iter().filter_map(|r| r.fault_rate).collect();

        let tok_s = if tok_values.is_empty() {
            0.0
        } else {
            tok_values.iter().sum::<f64>() / tok_values.len() as f64
        };
        let fault_rate = if fault_values.is_empty() {
            0.0
        } else {
            fault_values.iter().sum::<f64>() / fault_values.len() as f64
        };

        let point = SweepPoint {
            // "auto" no es un W numérico; se excluye del argmax entre W fijos.
            w: w.parse().unwrap_or(usize::MAX),
            tok_s,
            fault_rate,
            // PSI y térmica: no están en el CSV (ColorOS sin /proc/pressure).
            // Piso 1.0 de utility ⇒ utilidad = throughput útil. Honesto.
            psi_mem: 0.0,
            psi_io: 0.0,
            thermal_c: 30.0,
            runs_completed: completed,
            runs_requested: requested,
        };

        let note = if w == "auto" {
            auto_point = Some(point.clone());
            "AUTO (sin env)"
        } else if completed == 0 {
            "muerto"
        } else {
            ""
        };

        println!(
            "{:>5} {:>3}/{:<4} {:>9.3} {:>9.1} {:>11.3} {:>11.3} {:>10}",
            w,
            completed,
            requested,
            tok_s,
            fault_rate,
            nanortime_core::memory_engine::utility::useful_throughput(&point),
            utility(&point, &weights),
            note,
        );
        if w != "auto" {
            points.push(point);
        }
    }

    println!("\nW* = argmax Utility entre W fijos:");
    match best_window(&points, &weights) {
        Some(w_star) => {
            let star = points.iter().find(|p| p.w == w_star).unwrap();
            println!(
                "  W* = {}  (utility {:.3}, tok_s {:.3}, liveness {}/{} — μ: {:.3} tok/s útil)",
                w_star,
                utility(star, &weights),
                star.tok_s,
                star.runs_completed,
                star.runs_requested,
                nanortime_core::memory_engine::utility::useful_throughput(star),
            );
        }
        None => println!("  ninguno (todas las W murieron — barrido inválido)"),
    }

    // Validación AUTO vs W* — fila crítica del plan G6.
    match (&auto_point, best_window(&points, &weights)) {
        (Some(auto), Some(w_star)) => {
            let star = points.iter().find(|p| p.w == w_star).unwrap();
            let u_auto = utility(auto, &weights);
            let u_star = utility(star, &weights);
            let ratio = if u_star > 0.0 { u_auto / u_star } else { 0.0 };
            println!("\nAUTO vs W*:");
            println!(
                "  Utility(AUTO) = {:.3}  ·  Utility(W*={}) = {:.3}",
                u_auto, w_star, u_star
            );
            println!("  ratio = {:.2}", ratio);
            if ratio >= 0.8 {
                println!("  VERDICTO: PASS — AUTO se acerca al mejor W manual (ratio ≥ 0.8).");
            } else if u_auto > 0.0 {
                println!(
                    "  VERDICTO: FAIL — AUTO deja {:.0}% de throughput útil sobre la mesa; \
                     el planner debe derivar W* del presupuesto/mediciones.",
                    (1.0 - ratio) * 100.0
                );
            } else {
                println!("  VERDICTO: FAIL — AUTO murió (liveness 0); el barrido manual es la única vía.");
            }
        }
        _ => println!("\nAUTO vs W*: falta la fila AUTO (Run D) o las W fijas."),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    #[test]
    fn test_parse_csv_ok_and_auto() {
        let dir = std::env::temp_dir();
        let path = dir.join("sweep_analyze_test.csv");
        let mut f = fs::File::create(&path).unwrap();
        writeln!(
            f,
            "run,order,w,rep,success,tok_s,fault_rate,pss_mb,ttft_ms,tok_avg_ms,tok_p90_ms,thrash"
        )
        .unwrap();
        writeln!(f, "A,2>4,2,1,OK,0.39,80.2,12.1,18756,41.0,95.0,heavy").unwrap();
        writeln!(f, "A,2>4,2,2,OK,0.35,85.0,12.4,19012,44.0,99.0,heavy").unwrap();
        writeln!(f, "D,auto,auto,1,FAIL/OOM,-,-,-,-,-,-,-").unwrap();
        let rows = parse_csv(&path);
        fs::remove_file(&path).ok();
        assert_eq!(rows.len(), 3);
        assert_eq!(rows[0].w, "2");
        assert!(rows[0].success);
        assert!((rows[0].tok_s.unwrap() - 0.39).abs() < 1e-9);
        assert_eq!(rows[2].w, "auto");
        assert!(!rows[2].success);
        assert!(rows[2].tok_s.is_none());
    }

    #[test]
    fn test_parse_csv_skips_junk() {
        let dir = std::env::temp_dir();
        let path = dir.join("sweep_analyze_junk_test.csv");
        let mut f = fs::File::create(&path).unwrap();
        writeln!(
            f,
            "run,order,w,rep,success,tok_s,fault_rate,pss_mb,ttft_ms,tok_avg_ms,tok_p90_ms,thrash"
        )
        .unwrap();
        writeln!(f, "").unwrap();
        writeln!(f, "columna rota").unwrap();
        writeln!(f, "A,2>4,2,1,OK,0.39,80.2,12.1,18756,41.0,95.0,heavy").unwrap();
        let rows = parse_csv(&path);
        fs::remove_file(&path).ok();
        assert_eq!(rows.len(), 1);
    }
}
