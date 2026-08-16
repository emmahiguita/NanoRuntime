//! Probe REAL del parser GGUF — sin simulación, sin tests.
//!
//! Analiza un GGUF real con `NanoModelIndex::analyze` y verifica contra
//! invariantes del formato:
//!   - conteo de tensores == header
//!   - offsets absolutos (v3) alineados a 32 y crecientes
//!   - suma de byte_size <= tamaño de datos del archivo (padding incluido)
//!   - tabla de cuantización (bytes/elemento) contra bloques reales
//!
//! Uso:
//!   cargo run -p nanortime-core --example gguf_probe --features unstable -- <ruta.gguf>

use nanortime_core::memory_engine::gguf_layout::{NanoModelIndex, QuantizationType};
use std::io::{Read, Seek, SeekFrom};
use std::path::PathBuf;

/// Diagnóstico manual del header según la spec GGUF oficial:
/// dims uint64, BOOL = 1 byte, arrays de primitivos 0..=12.
fn diagnose_header(path: &PathBuf) {
    use std::fs::File;
    let mut f = File::open(path).expect("open");
    let mut u32b = [0u8; 4];
    let mut u64b = [0u8; 8];

    let rd_u32 = |f: &mut File, b: &mut [u8; 4]| -> u32 {
        f.read_exact(b).unwrap();
        u32::from_le_bytes(*b)
    };
    let rd_u64 = |f: &mut File, b: &mut [u8; 8]| -> u64 {
        f.read_exact(b).unwrap();
        u64::from_le_bytes(*b)
    };

    let magic = rd_u32(&mut f, &mut u32b);
    let version = rd_u32(&mut f, &mut u32b);
    let nt = rd_u64(&mut f, &mut u64b);
    let nkv = rd_u64(&mut f, &mut u64b);
    println!("\n[Diagnóstico] magic=0x{:X} version={} tensors={} kv={}", magic, version, nt, nkv);

    for i in 0..nkv {
        let klen = rd_u64(&mut f, &mut u64b);
        let mut key = vec![0u8; klen as usize];
        f.read_exact(&mut key).unwrap();
        let vtype = rd_u32(&mut f, &mut u32b);
        let pos = f.stream_position().unwrap();
        let detail: String;
        match vtype {
            0..=6 => {
                let size = match vtype {
                    0 | 1 => 1,
                    2 | 3 => 2,
                    _ => 4,
                };
                f.seek(SeekFrom::Current(size)).unwrap();
                detail = format!("scalar {} bytes", size);
            }
            7 => {
                f.seek(SeekFrom::Current(1)).unwrap(); // BOOL = 1 byte en spec
                detail = "bool 1 byte".into();
            }
            8 => {
                let l = rd_u64(&mut f, &mut u64b);
                f.seek(SeekFrom::Current(l as i64)).unwrap();
                detail = format!("string {} bytes", l);
            }
            9 => {
                let et = rd_u32(&mut f, &mut u32b);
                let c = rd_u64(&mut f, &mut u64b);
                detail = format!("array[{}] x{}", et, c);
                if et == 8 {
                    for _ in 0..c {
                        let l = rd_u64(&mut f, &mut u64b);
                        f.seek(SeekFrom::Current(l as i64)).unwrap();
                    }
                } else {
                    let es: i64 = match et {
                        0 | 1 => 1,
                        2 | 3 => 2,
                        4..=6 => 4,
                        7 => 1,
                        10..=12 => 8,
                        _ => panic!("elem_type {} inesperado en kv[{}]", et, i),
                    };
                    f.seek(SeekFrom::Current(es * c as i64)).unwrap();
                }
            }
            10..=12 => {
                f.seek(SeekFrom::Current(8)).unwrap();
                detail = "int64/f64 8 bytes".into();
            }
            _ => panic!("vtype {} inesperado en kv[{}]", vtype, i),
        }
        if i < 8 || i >= nkv - 3 {
            println!(
                "  kv[{:02}] {:<40} type={:<2} {} @{}",
                i,
                String::from_utf8_lossy(&key),
                vtype,
                detail,
                pos
            );
        }
    }
    let after_kv = f.stream_position().unwrap();
    println!("  fin metadata @{}", after_kv);

    for i in 0..3.min(nt) {
        let nlen = rd_u64(&mut f, &mut u64b);
        let mut name = vec![0u8; nlen as usize];
        f.read_exact(&mut name).unwrap();
        let nd = rd_u32(&mut f, &mut u32b);
        let mut dims = Vec::new();
        for _ in 0..nd {
            dims.push(rd_u64(&mut f, &mut u64b));
        }
        let ttype = rd_u32(&mut f, &mut u32b);
        let off = rd_u64(&mut f, &mut u64b);
        println!(
            "  tensor[{}] {} dims={:?} type={} offset={}",
            i,
            String::from_utf8_lossy(&name),
            dims,
            ttype,
            off
        );
    }
}

fn main() {
    let default_model = concat!(
        env!("CARGO_MANIFEST_DIR"),
        "/../../../models/qwen2.5-1.5b-instruct-q4_k_m.gguf"
    );
    let path = std::env::args()
        .nth(1)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(default_model));

    println!("=== GGUF Probe — archivo real: {} ===", path.display());
    if !path.exists() {
        eprintln!("ERROR: no existe {}", path.display());
        std::process::exit(1);
    }

    let mut failures = 0;
    let mut check = |name: &str, cond: bool, detail: String| {
        if cond {
            println!("  ✓ {}", name);
        } else {
            failures += 1;
            println!("  ✗ {}: {}", name, detail);
        }
    };

    // ── Analizar ──
    let index = match NanoModelIndex::analyze(&path, 28) {
        Ok(i) => i,
        Err(e) => {
            println!("ERROR parseando {}: {}", path.display(), e);
            // Diagnóstico manual del header para localizar la desalineación
            diagnose_header(&path);
            std::process::exit(1);
        }
    };

    println!(
        "\n[Index] v{} | {} tensores | {} capas | data_offset={} | header_ok",
        index.gguf_version,
        index.tensor_count,
        index.layers.len(),
        index.data_offset
    );

    check(
        "version == 3",
        index.gguf_version == 3,
        format!("v{}", index.gguf_version),
    );
    check(
        "tensor_count == 339 (qwen2.5-1.5b)",
        index.tensor_count == 339,
        format!("{}", index.tensor_count),
    );

    // ── Offsets: alineados y crecientes ──
    let mut prev_offset = 0u64;
    let mut offsets_ok = true;
    let mut first_bad = String::new();
    for t in &index.tensors {
        if t.offset % 32 != 0 {
            offsets_ok = false;
            first_bad = format!("{}: offset {} no alineado a 32", t.name, t.offset);
            break;
        }
        if t.offset < prev_offset {
            offsets_ok = false;
            first_bad = format!("{}: offset {} < anterior {}", t.name, t.offset, prev_offset);
            break;
        }
        prev_offset = t.offset;
    }
    check("offsets alineados a 32 y crecientes", offsets_ok, first_bad);

    // ── Suma de byte_size vs datos del archivo ──
    let data_region = (index.file_size - index.data_offset) as u64;
    let sum_bytes: u64 = index.tensors.iter().map(|t| t.byte_size).sum();
    check(
        "suma byte_size <= datos del archivo",
        sum_bytes <= data_region,
        format!("suma {} > datos {}", sum_bytes, data_region),
    );
    let padding = data_region - sum_bytes;
    let padding_pct = padding as f64 / data_region as f64 * 100.0;
    println!(
        "      datos={} MB, pesos={} MB, padding entre tensores={} MB ({:.2}%)",
        data_region / 1024 / 1024,
        sum_bytes / 1024 / 1024,
        padding / 1024 / 1024,
        padding_pct
    );
    // Alineación de 32 por tensor: padding esperado < 1% del total
    check(
        "padding entre tensores < 1% (solo alineación)",
        padding_pct < 1.0,
        format!("{:.2}%", padding_pct),
    );

    // ── Tensores clave de qwen2.5 ──
    let embd = index.get_tensor_by_name("token_embd.weight");
    check("token_embd.weight existe", embd.is_some(), "no encontrado".into());
    if let Some(t) = embd {
        check(
            "token_embd.weight dims [1536, 151936]",
            t.dimensions == vec![1536, 151936],
            format!("{:?}", t.dimensions),
        );
        check(
            "token_embd.weight es Q4_K (tabla correcta)",
            t.quantization == QuantizationType::Q4_K,
            format!("{:?}", t.quantization),
        );
        let expected = 151936u64 * 1536 / 256 * 144;
        check(
            "token_embd.weight byte_size exacto (entero)",
            t.byte_size == expected,
            format!("{} vs esperado {}", t.byte_size, expected),
        );
    }

    let output = index.get_tensor_by_name("output.weight");
    check("output.weight existe", output.is_some(), "no encontrado".into());
    if let Some(t) = output {
        // En los K-quants de llama.cpp el output se cuantiza a Q6_K
        // (mayor precisión para logits), no F32.
        check(
            "output.weight es Q6_K (K-quants de llama.cpp)",
            t.quantization == QuantizationType::Q6_K,
            format!("{:?}", t.quantization),
        );
        let expected = 151936u64 * (1536 / 256) * 210;
        check(
            "output.weight byte_size exacto (entero)",
            t.byte_size == expected,
            format!("{} vs esperado {}", t.byte_size, expected),
        );
    }

    // ── Tabla de cuantización real ──
    check(
        "Q4_K = 0.5625 bytes/elem (144/256)",
        (QuantizationType::Q4_K.bytes_per_element() - 0.5625).abs() < 1e-6,
        format!("{}", QuantizationType::Q4_K.bytes_per_element()),
    );
    check(
        "Q8_0 = 1.0625 bytes/elem (34/32)",
        (QuantizationType::Q8_0.bytes_per_element() - 1.0625).abs() < 1e-6,
        format!("{}", QuantizationType::Q8_0.bytes_per_element()),
    );

    // ── Resumen de cuantización ──
    let summary = index.quantization_summary();
    let mut counts: Vec<_> = summary.iter().collect();
    counts.sort_by_key(|(_, c)| std::cmp::Reverse(**c));
    println!("\n[Quantization]");
    for (q, c) in counts {
        println!("  {:?}: {} tensores", q, c);
    }

    // ── Primeros tensores ──
    println!("\n[Primeros 5 tensores]");
    for t in index.tensors.iter().take(5) {
        println!(
            "  {} | dims={:?} | {:?} | {} bytes | @{}",
            t.name, t.dimensions, t.quantization, t.byte_size, t.offset
        );
    }

    println!("\n[Últimos 3 tensores]");
    for t in index.tensors.iter().rev().take(3).rev() {
        println!(
            "  {} | dims={:?} | {:?} | {} bytes | @{}",
            t.name, t.dimensions, t.quantization, t.byte_size, t.offset
        );
    }

    if failures == 0 {
        println!("\nRESULTADO: parser GGUF real OK — {} checks verdes", index.tensor_count);
    } else {
        println!("\nRESULTADO: {} checks fallaron", failures);
        std::process::exit(1);
    }
}
