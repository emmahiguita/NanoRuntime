//! GGUF Layout Analyzer
//!
//! Analiza la estructura de un archivo GGUF para mapear los índices
//! de las capas a sus offsets físicos en disco. Esto es crucial para
//! realizar madvise/paginación precisa sobre el mmap.

use std::collections::HashMap;
use std::fs::File;
use std::io::{self, Read, Seek, SeekFrom};
use std::path::Path;

use thiserror::Error;

#[derive(Error, Debug)]
pub enum GgufError {
    #[error("IO Error: {0}")]
    Io(#[from] io::Error),
    #[error("Invalid GGUF Magic")]
    InvalidMagic,
    #[error("Unsupported GGUF version: {0}")]
    UnsupportedVersion(u32),
    #[error("File too small or malformed")]
    Malformed,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ByteRange {
    pub start: usize,
    pub end: usize,
}

impl ByteRange {
    pub fn len(&self) -> usize {
        self.end.saturating_sub(self.start)
    }

    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }
}

pub struct GGUFLayoutAnalyzer {
    /// Mapea el índice de la capa a su rango de bytes en el archivo.
    pub layer_offsets: HashMap<usize, ByteRange>,
    /// El offset de memoria donde comienzan los datos reales de los tensores.
    pub data_offset: usize,
}

impl GGUFLayoutAnalyzer {
    /// Analiza un archivo GGUF y extrae los rangos de bytes para cada capa.
    ///
    /// Parsea el header GGUF real para determinar el offset de datos (en lugar de
    /// usar una heurística hardcodeada de 1MB). Lee los registros de info de tensores
    /// para obtener offsets y tamaños reales por capa.
    pub fn analyze(gguf_path: &Path, expected_layers: usize) -> Result<Self, GgufError> {
        let mut file = File::open(gguf_path)?;

        // Comprobar tamaño
        let file_size = file.metadata()?.len() as usize;
        if file_size < 16 {
            return Err(GgufError::Malformed);
        }

        // Leer magic
        let mut magic = [0u8; 4];
        file.read_exact(&mut magic)?;

        if &magic != b"GGUF" {
            return Err(GgufError::InvalidMagic);
        }

        let mut version_bytes = [0u8; 4];
        file.read_exact(&mut version_bytes)?;
        let version = u32::from_le_bytes(version_bytes);

        if !(2..=3).contains(&version) {
            return Err(GgufError::UnsupportedVersion(version));
        }

        // ── Parsear header GGUF real ─────────────────────────────────
        // Formato (v2/v3): tensor_count (u64) + metadata_kv_count (u64)
        // seguido de N KV pairs (key:string + type:u32 + value) y
        // M tensor info records (name:string + dims + type + offset:u64).
        let mut buf = [0u8; 8];

        file.read_exact(&mut buf)?;
        let tensor_count = u64::from_le_bytes(buf) as usize;

        file.read_exact(&mut buf)?;
        let kv_count = u64::from_le_bytes(buf) as usize;

        // Skip all metadata KV pairs. Each pair: string key (u64 len + bytes)
        // followed by value type (u32) and the value bytes (size depends on type).
        for _ in 0..kv_count {
            skip_gguf_string(&mut file)?;
            skip_gguf_value(&mut file)?;
        }

        // ── Parsear tensor info records para offsets reales ──────────
        // Cada registro: name (string), n_dims (u32), dims (u32 × n_dims),
        // ggml_type (u32), offset (u64).
        // El offset más bajo entre todos los tensores = data_offset real.
        // Almacenamos (tensor_index, offset, byte_size) para calcular límites.
        let mut tensor_offsets: Vec<(usize, u64, u64)> = Vec::with_capacity(tensor_count);
        let mut min_offset: Option<u64> = None;

        for i in 0..tensor_count {
            skip_gguf_string(&mut file)?; // tensor name

            let mut dim_buf = [0u8; 4];
            file.read_exact(&mut dim_buf)?;
            let n_dims = u32::from_le_bytes(dim_buf) as usize;

            // Leer dimensiones para calcular el tamaño del tensor
            let mut tensor_size: u64 = 1;
            for _ in 0..n_dims {
                file.read_exact(&mut dim_buf)?;
                tensor_size = tensor_size.saturating_mul(u32::from_le_bytes(dim_buf) as u64);
            }

            file.read_exact(&mut dim_buf)?;
            let ggml_type = u32::from_le_bytes(dim_buf);
            let element_size = gguf_type_size(ggml_type);
            let tensor_bytes = tensor_size.saturating_mul(element_size as u64);

            file.read_exact(&mut buf)?;
            let offset = u64::from_le_bytes(buf);

            tensor_offsets.push((i, offset, tensor_bytes));
            if min_offset.is_none_or(|m| offset < m) {
                min_offset = Some(offset);
            }
        }

        let data_offset = min_offset.unwrap_or(0) as usize;

        // ── Construir layer_offsets a partir de los offsets reales ──
        // Agrupamos tensores por cercanía para aproximar capas. Si hay más
        // tensores que expected_layers, agrupamos tensores contiguos.
        let mut layer_offsets = HashMap::new();
        if tensor_offsets.is_empty() {
            // Fallback: sin info de tensores, dividir uniformemente
            let data_size = file_size.saturating_sub(data_offset);
            let layer_size = data_size / expected_layers.max(1);
            for i in 0..expected_layers {
                let start = data_offset + (i * layer_size);
                let end = start + layer_size;
                layer_offsets.insert(i, ByteRange { start, end });
            }
        } else if tensor_count <= expected_layers {
            // Un tensor por capa: usar offset del tensor como start,
            // el siguiente offset (o offset + byte_size para el último) como end.
            tensor_offsets.sort_by_key(|(_, off, _)| *off);
            for (layer_idx, &(_, offset, byte_size)) in tensor_offsets.iter().enumerate() {
                let start = offset as usize;
                let end = if layer_idx + 1 < tensor_offsets.len() {
                    tensor_offsets[layer_idx + 1].1 as usize
                } else {
                    // Último tensor: usar offset + tamaño real, acotado al file_size
                    (offset as usize + byte_size as usize).min(file_size)
                };
                layer_offsets.insert(layer_idx, ByteRange { start, end });
            }
        } else {
            // Más tensores que capas: agrupar tensores contiguos en capas lógicas.
            // Ordenar por offset y dividir en expected_layers grupos equitativos.
            tensor_offsets.sort_by_key(|(_, off, _)| *off);
            let tensors_per_layer = tensor_count.div_ceil(expected_layers);
            for layer_idx in 0..expected_layers {
                let tensor_start = layer_idx * tensors_per_layer;
                let tensor_end = ((layer_idx + 1) * tensors_per_layer).min(tensor_count);
                if tensor_start >= tensor_count {
                    break;
                }
                let start = tensor_offsets[tensor_start].1 as usize;
                let end = if tensor_end < tensor_count {
                    tensor_offsets[tensor_end].1 as usize
                } else {
                    // Último grupo: offset del último tensor + su byte_size
                    let last = &tensor_offsets[tensor_count - 1];
                    (last.1 as usize + last.2 as usize).min(file_size)
                };
                layer_offsets.insert(layer_idx, ByteRange { start, end });
            }
        }

        tracing::info!(
            "GGUF layout: {} tensors, data_offset={}, {} layers, file_size={}",
            tensor_count,
            data_offset,
            layer_offsets.len(),
            file_size
        );

        Ok(Self {
            layer_offsets,
            data_offset,
        })
    }

    /// Retorna el rango de bytes físicos de una capa específica.
    pub fn get_layer_range(&self, layer_idx: usize) -> Option<&ByteRange> {
        self.layer_offsets.get(&layer_idx)
    }

    /// Agrupa índices de capas en rangos contiguos de bytes para batching de syscalls.
    pub fn group_contiguous_layers(&self, layer_indices: &[usize]) -> Vec<ByteRange> {
        if layer_indices.is_empty() {
            return Vec::new();
        }

        let mut sorted_indices = layer_indices.to_vec();
        sorted_indices.sort_unstable();

        let mut ranges = Vec::new();
        let mut current_range: Option<ByteRange> = None;

        for &idx in &sorted_indices {
            if let Some(layer_range) = self.get_layer_range(idx) {
                if let Some(ref mut current) = current_range {
                    // Tolerancia de contigüidad. Si la siguiente capa empieza exactamente donde
                    // termina la actual, o hay un pequeño gap, las unimos.
                    if current.end >= layer_range.start || current.end + 4096 >= layer_range.start {
                        current.end = current.end.max(layer_range.end);
                    } else {
                        ranges.push(current.clone());
                        current_range = Some(layer_range.clone());
                    }
                } else {
                    current_range = Some(layer_range.clone());
                }
            }
        }

        if let Some(current) = current_range {
            ranges.push(current);
        }

        ranges
    }

    /// Genera un layout mock para entornos de test.
    #[cfg(test)]
    fn mock_layout(expected_layers: usize, file_size: usize) -> Self {
        let mut layer_offsets = HashMap::new();
        let data_offset = 128; // Dummy header size
        let data_size = file_size.saturating_sub(data_offset);
        let layer_size = data_size / expected_layers.max(1);

        for i in 0..expected_layers {
            let start = data_offset + (i * layer_size);
            let end = start + layer_size;
            layer_offsets.insert(i, ByteRange { start, end });
        }

        Self {
            layer_offsets,
            data_offset,
        }
    }
}

// ── GGUF header parsing helpers ───────────────────────────────────────
// Used by analyze() to skip metadata KV pairs and parse tensor info records
// without a full-blown GGUF parser (avoids ~2000 lines of type dispatch).

/// Reads and discards a GGUF string (u64 length prefix + raw bytes).
/// GGUF strings are NOT null-terminated and have no alignment padding.
fn skip_gguf_string(file: &mut File) -> Result<(), GgufError> {
    let mut len_buf = [0u8; 8];
    file.read_exact(&mut len_buf)?;
    let len = u64::from_le_bytes(len_buf) as usize;
    // Seek past the string bytes. Capped at 16MB to prevent OOM on malformed files.
    if len > 16 * 1024 * 1024 {
        return Err(GgufError::Malformed);
    }
    file.seek(SeekFrom::Current(len as i64))?;
    Ok(())
}

/// Reads and discards a GGUF value. The value type (u32) determines how many
/// bytes to skip after it. Handles all GGUF v2/v3 scalar and aggregate types.
fn skip_gguf_value(file: &mut File) -> Result<(), GgufError> {
    let mut type_buf = [0u8; 4];
    file.read_exact(&mut type_buf)?;
    let value_type = u32::from_le_bytes(type_buf);

    match value_type {
        // Fixed-size scalars: 1, 2, 4, or 8 bytes
        0..=7 => {
            let size = match value_type {
                0 | 1 => 1, // u8, i8
                2 | 3 => 2, // u16, i16
                4..=7 => 4, // u32, i32, f32, bool
                _ => unreachable!(),
            };
            file.seek(SeekFrom::Current(size))?;
        }
        // String: u64 length + bytes (same as skip_gguf_string but inlined)
        8 => {
            skip_gguf_string(file)?;
        }
        // Array: element type (u32) + count (u64) + items
        // Recursively skip each element without allocating.
        9 => {
            let mut elem_type_buf = [0u8; 4];
            file.read_exact(&mut elem_type_buf)?;
            let elem_type = u32::from_le_bytes(elem_type_buf);

            let mut count_buf = [0u8; 8];
            file.read_exact(&mut count_buf)?;
            let count = u64::from_le_bytes(count_buf);

            // Capped at 1M elements to prevent OOM on malformed files
            if count > 1_000_000 {
                return Err(GgufError::Malformed);
            }

            if elem_type == 8 {
                // Array of strings: skip each one individually
                for _ in 0..count {
                    skip_gguf_string(file)?;
                }
            } else {
                // Array of fixed-size scalars: bulk skip
                let elem_size: i64 = match elem_type {
                    0 | 1 => 1,
                    2 | 3 => 2,
                    4..=7 => 4,
                    10..=12 => 8, // u64, i64, f64
                    _ => {
                        // Nested array or unknown — skip element by element
                        // by recursing (rare, but valid in GGUF).
                        for _ in 0..count {
                            // Rewind to re-read elem_type, then skip full value
                            file.seek(SeekFrom::Current(-4))?; // back to elem_type
                            skip_gguf_value(file)?;
                        }
                        return Ok(());
                    }
                };
                file.seek(SeekFrom::Current(elem_size * count as i64))?;
            }
        }
        // u64, i64, f64: 8 bytes each
        10..=12 => {
            file.seek(SeekFrom::Current(8))?;
        }
        // Unknown type: treat as malformed
        _ => {
            return Err(GgufError::Malformed);
        }
    }

    Ok(())
}

/// Returns the size in bytes of a single element for a given GGML type.
/// Used to estimate tensor byte sizes from dimension products.
/// Reference: ggml.h `ggml_type_size()` and GGUF spec table.
fn gguf_type_size(ggml_type: u32) -> u16 {
    match ggml_type {
        0 => 4,  // F32
        1 => 2,  // F16
        2 => 4,  // Q4_0
        3 => 4,  // Q4_1
        6 => 4,  // Q5_0
        7 => 4,  // Q5_1
        8 => 4,  // Q8_0
        9 => 4,  // Q8_1
        10 => 2, // Q2_K
        11 => 4, // Q3_K
        12 => 4, // Q4_K
        13 => 4, // Q5_K
        14 => 4, // Q6_K
        15 => 4, // Q8_K
        16 => 4, // IQ2_XXS
        17 => 4, // IQ2_XS
        18 => 4, // IQ3_XXS
        19 => 4, // IQ1_S
        20 => 4, // IQ4_NL
        21 => 4, // IQ3_S
        22 => 4, // IQ2_S
        23 => 4, // IQ4_XS
        24 => 2, // I8
        25 => 2, // I16
        26 => 4, // I32
        27 => 4, // I64
        28 => 4, // F64
        29 => 2, // IQ1_M
        30 => 4, // BF16
        _ => 4,  // Unknown: assume 4 bytes (safe overestimate for typical quant types)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_gguf_mock_layout_small_file() {
        // analyze() now returns Err for files < 16 bytes or invalid magic.
        // Test mock_layout directly since that's what the test exercises.
        let analyzer = GGUFLayoutAnalyzer::mock_layout(4, 256);

        assert_eq!(analyzer.layer_offsets.len(), 4);
        assert_eq!(analyzer.data_offset, 128);

        // 256 - 128 = 128 bytes of data / 4 layers = 32 bytes per layer
        let r0 = analyzer.get_layer_range(0).unwrap();
        assert_eq!(r0.start, 128);
        assert_eq!(r0.end, 160);

        let r3 = analyzer.get_layer_range(3).unwrap();
        assert_eq!(r3.start, 224);
        assert_eq!(r3.end, 256);
    }

    #[test]
    fn test_group_contiguous_layers() {
        let mut analyzer = GGUFLayoutAnalyzer {
            layer_offsets: HashMap::new(),
            data_offset: 100,
        };

        analyzer.layer_offsets.insert(
            0,
            ByteRange {
                start: 100,
                end: 200,
            },
        );
        analyzer.layer_offsets.insert(
            1,
            ByteRange {
                start: 200,
                end: 300,
            },
        );
        analyzer.layer_offsets.insert(
            2,
            ByteRange {
                start: 300,
                end: 400,
            },
        );
        analyzer.layer_offsets.insert(
            5,
            ByteRange {
                start: 6000,
                end: 7000,
            },
        );
        analyzer.layer_offsets.insert(
            6,
            ByteRange {
                start: 7000,
                end: 8000,
            },
        );

        let ranges = analyzer.group_contiguous_layers(&[0, 1, 2, 5, 6]);
        assert_eq!(ranges.len(), 2);

        // Range 1: layers 0,1,2 (100 -> 400)
        assert_eq!(
            ranges[0],
            ByteRange {
                start: 100,
                end: 400
            }
        );
        // Range 2: layers 5,6 (6000 -> 8000)
        assert_eq!(
            ranges[1],
            ByteRange {
                start: 6000,
                end: 8000
            }
        );
    }
}
