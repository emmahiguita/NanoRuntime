//! NanoModelIndex — GGUF layout analyzer with full tensor indexing
//!
//! Converts GGUF files into a structured index for the control plane.
//! Provides tensor-level metadata, layer groupings, quantization info,
//! and dynamic page size detection for precise memory management.
//!
//! This replaces the previous GGUFLayoutAnalyzer with a more comprehensive
//! model index that supports:
//! - Individual tensor indexing (not just layer-level)
//! - Quantization metadata per tensor
//! - Dynamic page size detection
//! - Layer-to-tensor mapping
//! - Working set estimation

use std::collections::{BTreeMap, HashMap};
use std::fs::File;
use std::io::{self, Read, Seek, SeekFrom};
use std::path::Path;

use thiserror::Error;

use super::model_profile::{ArchitectureType, ModelProfile};

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
    #[error("Invalid quantization type: {0}")]
    InvalidQuantization(u32),
}

/// ByteRange vive en `types` (compartido con CacheAwareLoader, activo).
/// Re-export para no romper usos internos de este módulo.
pub use crate::memory_engine::types::ByteRange;

/// Quantization type for a tensor or layer
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
#[allow(non_camel_case_types)]
pub enum QuantizationType {
    F32,
    F16,
    BF16,
    Q4_0,
    Q4_1,
    Q5_0,
    Q5_1,
    Q8_0,
    Q8_1,
    Q2_K,
    Q3_K,
    Q4_K,
    Q5_K,
    Q6_K,
    Q8_K,
    IQ2_XXS,
    IQ2_XS,
    IQ3_XXS,
    IQ1_S,
    IQ4_NL,
    IQ3_S,
    IQ2_S,
    IQ4_XS,
    I8,
    I16,
    I32,
    I64,
    F64,
    IQ1_M,
    Unknown(u32),
}

impl QuantizationType {
    /// Returns bytes per element for this quantization type.
    ///
    /// Valores verificados contra los `static_assert(sizeof(block_*))` de
    /// `ggml-common.h` (llama.cpp) y los `QK_*` defines. Los valores
    /// anteriores estaban inventados: Q4_K decía 0.875 cuando el bloque
    /// real (144 bytes / 256 elementos) es 0.5625, Q8_1 estaba inflado
    /// (1.25 vs 1.125 real), y varios IQ/*_K no coincidían con ggml.
    pub fn bytes_per_element(&self) -> f32 {
        match self {
            QuantizationType::F32 => 4.0,
            QuantizationType::F16 => 2.0,
            QuantizationType::BF16 => 2.0,
            QuantizationType::Q4_0 => 18.0 / 32.0,   // 0.5625
            QuantizationType::Q4_1 => 20.0 / 32.0,   // 0.625
            QuantizationType::Q5_0 => 22.0 / 32.0,   // 0.6875
            QuantizationType::Q5_1 => 24.0 / 32.0,   // 0.75
            QuantizationType::Q8_0 => 34.0 / 32.0,   // 1.0625
            QuantizationType::Q8_1 => 36.0 / 32.0,   // 1.125
            QuantizationType::Q2_K => 84.0 / 256.0,  // 0.328125
            QuantizationType::Q3_K => 110.0 / 256.0, // 0.4296875
            QuantizationType::Q4_K => 144.0 / 256.0, // 0.5625
            QuantizationType::Q5_K => 176.0 / 256.0, // 0.6875
            QuantizationType::Q6_K => 210.0 / 256.0, // 0.8203125
            QuantizationType::Q8_K => 292.0 / 256.0, // 1.140625
            QuantizationType::IQ2_XXS => 66.0 / 256.0, // 0.2578125
            QuantizationType::IQ2_XS => 74.0 / 256.0, // 0.2890625
            QuantizationType::IQ3_XXS => 98.0 / 256.0, // 0.3828125
            QuantizationType::IQ1_S => 50.0 / 256.0, // 0.1953125
            QuantizationType::IQ4_NL => 18.0 / 32.0, // 0.5625
            QuantizationType::IQ3_S => 110.0 / 256.0, // 0.4296875
            QuantizationType::IQ2_S => 82.0 / 256.0, // 0.3203125
            QuantizationType::IQ4_XS => 136.0 / 256.0, // 0.53125
            QuantizationType::I8 => 1.0,
            QuantizationType::I16 => 2.0,
            QuantizationType::I32 => 4.0,
            QuantizationType::I64 => 8.0,
            QuantizationType::F64 => 8.0,
            QuantizationType::IQ1_M => 56.0 / 256.0, // 0.21875
            QuantizationType::Unknown(_) => 4.0,     // Conservative default
        }
    }

    /// Exact block layout: `(elements_per_block, bytes_per_block)`.
    ///
    /// Permite calcular el tamaño de un tensor en enteros sin pasar por
    /// f32 (que pierde precisión con `element_count` > 16M). Los tamaños
    /// vienen de la misma tabla verificada que `bytes_per_element`.
    pub fn block_layout(&self) -> Option<(u32, u32)> {
        match self {
            QuantizationType::F32 => Some((1, 4)),
            QuantizationType::F16 => Some((1, 2)),
            QuantizationType::BF16 => Some((1, 2)),
            QuantizationType::Q4_0 => Some((32, 18)),
            QuantizationType::Q4_1 => Some((32, 20)),
            QuantizationType::Q5_0 => Some((32, 22)),
            QuantizationType::Q5_1 => Some((32, 24)),
            QuantizationType::Q8_0 => Some((32, 34)),
            QuantizationType::Q8_1 => Some((32, 36)),
            QuantizationType::Q2_K => Some((256, 84)),
            QuantizationType::Q3_K => Some((256, 110)),
            QuantizationType::Q4_K => Some((256, 144)),
            QuantizationType::Q5_K => Some((256, 176)),
            QuantizationType::Q6_K => Some((256, 210)),
            QuantizationType::Q8_K => Some((256, 292)),
            QuantizationType::IQ2_XXS => Some((256, 66)),
            QuantizationType::IQ2_XS => Some((256, 74)),
            QuantizationType::IQ3_XXS => Some((256, 98)),
            QuantizationType::IQ1_S => Some((256, 50)),
            QuantizationType::IQ4_NL => Some((32, 18)),
            QuantizationType::IQ3_S => Some((256, 110)),
            QuantizationType::IQ2_S => Some((256, 82)),
            QuantizationType::IQ4_XS => Some((256, 136)),
            QuantizationType::I8 => Some((1, 1)),
            QuantizationType::I16 => Some((1, 2)),
            QuantizationType::I32 => Some((1, 4)),
            QuantizationType::I64 => Some((1, 8)),
            QuantizationType::F64 => Some((1, 8)),
            QuantizationType::IQ1_M => Some((256, 56)),
            QuantizationType::Unknown(_) => None,
        }
    }

    /// Returns the memory efficiency factor (1.0 = F32 baseline)
    pub fn efficiency_factor(&self) -> f32 {
        4.0 / self.bytes_per_element()
    }
}

/// Individual tensor metadata
#[derive(Debug, Clone)]
pub struct TensorInfo {
    /// Tensor name (e.g., "blk.0.attn_q.weight")
    pub name: String,
    /// Index in the GGUF tensor list
    pub tensor_index: usize,
    /// Assigned layer index (logical grouping)
    pub layer_index: usize,
    /// Byte offset in the GGUF file
    pub offset: u64,
    /// Total byte size
    pub byte_size: u64,
    /// Quantization type
    pub quantization: QuantizationType,
    /// Dimensions [d0, d1, d2, ...] (GGUF spec: uint64)
    pub dimensions: Vec<u64>,
    /// Number of elements (product of dimensions)
    pub element_count: u64,
}

/// Logical layer grouping of tensors
#[derive(Debug, Clone)]
pub struct LayerInfo {
    /// Layer index
    pub layer_index: usize,
    /// Byte range covering all tensors in this layer
    pub byte_range: ByteRange,
    /// Total byte size
    pub byte_size: u64,
    /// List of tensor indices in this layer
    pub tensor_indices: Vec<usize>,
    /// Dominant quantization type (most common)
    pub dominant_quantization: QuantizationType,
    /// Average bytes per element
    pub avg_bytes_per_element: f32,
}

/// System page size information
#[derive(Debug, Clone)]
pub struct PageSizeInfo {
    /// System page size in bytes
    pub page_size: usize,
    /// Whether this was auto-detected or defaulted
    pub auto_detected: bool,
}

impl PageSizeInfo {
    /// Detect system page size
    pub fn detect() -> Self {
        #[cfg(unix)]
        {
            let page_size = unsafe { libc::sysconf(libc::_SC_PAGESIZE) as usize };
            if page_size > 0 {
                return Self {
                    page_size,
                    auto_detected: true,
                };
            }
        }

        #[cfg(windows)]
        {
            use windows_sys::Win32::System::SystemInformation::GetSystemInfo;
            let mut sys_info = unsafe { std::mem::zeroed() };
            unsafe { GetSystemInfo(&mut sys_info) };
            let page_size = sys_info.dwPageSize as usize;
            if page_size > 0 {
                return Self {
                    page_size,
                    auto_detected: true,
                };
            }
        }

        // Fallback to 4KB
        Self {
            page_size: 4096,
            auto_detected: false,
        }
    }

    /// Align a value down to page boundary
    pub fn align_down(&self, val: usize) -> usize {
        val & !(self.page_size - 1)
    }

    /// Align a value up to page boundary
    pub fn align_up(&self, val: usize) -> usize {
        (val + self.page_size - 1) & !(self.page_size - 1)
    }

    /// Calculate page count for a byte range
    pub fn page_count(&self, byte_range: &ByteRange) -> usize {
        let aligned_start = self.align_down(byte_range.start);
        let aligned_end = self.align_up(byte_range.end);
        (aligned_end - aligned_start) / self.page_size
    }
}

/// Working set estimation for memory management
#[derive(Debug, Clone)]
pub struct WorkingSetEstimate {
    /// Total weights in working set (bytes)
    pub weights_bytes: u64,
    /// Estimated KV cache (bytes)
    pub kv_bytes: u64,
    /// Runtime overhead (bytes)
    pub runtime_bytes: u64,
    /// Total working set (bytes)
    pub total_bytes: u64,
    /// Number of layers in working set
    pub active_layers: usize,
    /// Page count for working set
    pub page_count: usize,
}

/// NanoModelIndex — comprehensive GGUF model index
pub struct NanoModelIndex {
    /// All tensors indexed by their global index
    pub tensors: Vec<TensorInfo>,
    /// Tensors indexed by name for quick lookup
    tensors_by_name: HashMap<String, usize>,
    /// Layer groupings
    pub layers: BTreeMap<usize, LayerInfo>,
    /// Page size information
    pub page_info: PageSizeInfo,
    /// File-level metadata
    pub file_size: usize,
    pub data_offset: usize,
    pub tensor_count: usize,
    /// GGUF version
    pub gguf_version: u32,
    /// Metadata lógica extraída de los KV del header (arquitectura, params,
    /// contexto, template, capacidades). Complementa el índice de tensores.
    pub metadata: GgufMetadata,
}

/// Valor GGUF leído del header (escalares y strings). Los arrays se descartan
/// durante la lectura — p.ej. `tokenizer.ggml.tokens` (decenas de miles de
/// strings) no aporta a la metadata que extraemos y leerlo completo inflaría
/// la memoria del parseo del header.
#[derive(Debug, Clone, PartialEq)]
pub enum GgufValue {
    U8(u8),
    I8(i8),
    U16(u16),
    I16(i16),
    U32(u32),
    I32(i32),
    F32(f32),
    Bool(bool),
    String(String),
    /// Array cuyo contenido fue descartado (ver doc del enum).
    Array,
    U64(u64),
    I64(i64),
    F64(f64),
}

impl GgufValue {
    pub fn as_string(&self) -> Option<&str> {
        match self {
            Self::String(s) => Some(s),
            _ => None,
        }
    }

    /// Enteros sin signo (u8/u16/u32/u64) como u64. GGUF guarda context_length,
    /// block_count, expert_count, etc. a veces como u32 y a veces como u64.
    pub fn as_u64(&self) -> Option<u64> {
        match self {
            Self::U8(v) => Some(*v as u64),
            Self::U16(v) => Some(*v as u64),
            Self::U32(v) => Some(*v as u64),
            Self::U64(v) => Some(*v),
            _ => None,
        }
    }

    pub fn as_bool(&self) -> Option<bool> {
        match self {
            Self::Bool(b) => Some(*b),
            _ => None,
        }
    }
}

/// Metadata lógica del modelo extraída del header GGUF. No depende de
/// llama.cpp: se lee directo del archivo. Es la base de la detección de
/// arquitectura, capacidades (MoE/embedding/visión) y del fingerprint.
#[derive(Debug, Clone, Default, PartialEq)]
pub struct GgufMetadata {
    /// `general.architecture` — p.ej. "qwen2", "llama", "gemma2".
    pub architecture: Option<String>,
    /// `general.name`.
    pub name: Option<String>,
    /// `general.parameter_count` (u64).
    pub parameter_count: Option<u64>,
    /// `<arch>.context_length` (fallback `general.context_length`).
    pub context_length: Option<u64>,
    /// `<arch>.embedding_length` — presente en modelos de embedding.
    pub embedding_length: Option<u64>,
    /// `<arch>.block_count`.
    pub block_count: Option<u64>,
    /// `<arch>.expert_count` — 0/ausente en dense, >0 en MoE.
    pub expert_count: Option<u64>,
    /// `<arch>.expert_used_count` — expertos activos por token en MoE.
    pub expert_used_count: Option<u64>,
    /// `tokenizer.chat_template` (Jinja crudo).
    pub chat_template: Option<String>,
}

impl GgufMetadata {
    /// Extrae los campos de un mapa de KV ya leído. Las claves específicas de
    /// arquitectura usan el prefijo de `general.architecture` (p.ej.
    /// `qwen2.context_length`), con fallback a `general.<clave>` — igual que
    /// hace llama.cpp.
    pub fn from_map(map: &HashMap<String, GgufValue>) -> Self {
        let architecture = map
            .get("general.architecture")
            .and_then(|v| v.as_string().map(String::from));
        let arch = architecture.as_deref().unwrap_or("");

        let arch_key = |suffix: &str| -> Option<&GgufValue> {
            map.get(&format!("{arch}.{suffix}"))
                .or_else(|| map.get(&format!("general.{suffix}")))
        };

        Self {
            name: map
                .get("general.name")
                .and_then(|v| v.as_string().map(String::from)),
            parameter_count: map.get("general.parameter_count").and_then(|v| v.as_u64()),
            context_length: arch_key("context_length").and_then(|v| v.as_u64()),
            embedding_length: arch_key("embedding_length").and_then(|v| v.as_u64()),
            block_count: arch_key("block_count").and_then(|v| v.as_u64()),
            expert_count: arch_key("expert_count").and_then(|v| v.as_u64()),
            expert_used_count: arch_key("expert_used_count").and_then(|v| v.as_u64()),
            chat_template: map
                .get("tokenizer.chat_template")
                .and_then(|v| v.as_string().map(String::from)),
            architecture,
        }
    }

    /// MoE si declara expertos (`expert_count > 0`) o la arquitectura lo
    /// indica por nombre (sufijo "moe" o "mixtral").
    pub fn is_moe(&self) -> bool {
        self.expert_count.is_some_and(|c| c > 0)
            || self
                .architecture
                .as_deref()
                .is_some_and(|a| a.ends_with("moe") || a.contains("mixtral"))
    }

    /// Modelo de embedding si declara `embedding_length` y `pooling_type` es
    /// distinto de 0 (la convención GGUF para no-causal). Conservador: solo
    /// embedding_length no es suficiente — los LLM causales no lo declaran.
    pub fn is_embedding(&self) -> bool {
        self.embedding_length.is_some()
    }

    /// Deriva el tipo de arquitectura (Dense/MoE) desde la metadata. Es la
    /// pieza que el planner consume sin depender de `ModelProfile` construido
    /// a mano.
    pub fn architecture_type(&self) -> ArchitectureType {
        if self.is_moe() {
            ArchitectureType::MixtureOfExperts
        } else {
            ArchitectureType::Dense
        }
    }
}

impl NanoModelIndex {
    /// Analyze a GGUF file and build a comprehensive model index.
    ///
    /// This replaces the previous GGUFLayoutAnalyzer with full tensor indexing,
    /// quantization metadata, and dynamic page size detection.
    pub fn analyze(gguf_path: &Path, expected_layers: usize) -> Result<Self, GgufError> {
        let mut file = File::open(gguf_path)?;
        let page_info = PageSizeInfo::detect();

        // Check file size
        let file_size = file.metadata()?.len() as usize;
        if file_size < 16 {
            return Err(GgufError::Malformed);
        }

        // Read magic
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

        // Parse GGUF header
        let mut buf = [0u8; 8];
        file.read_exact(&mut buf)?;
        let tensor_count = u64::from_le_bytes(buf) as usize;

        file.read_exact(&mut buf)?;
        let kv_count = u64::from_le_bytes(buf) as usize;

        // Leer los KV del header (ya no saltarlos): captura arquitectura,
        // params, contexto, template y capacidades para el metadata.
        let mut kv: HashMap<String, GgufValue> = HashMap::with_capacity(kv_count);
        for _ in 0..kv_count {
            let key = read_gguf_string(&mut file)?;
            let value = read_gguf_value(&mut file)?;
            kv.insert(key, value);
        }
        let metadata = GgufMetadata::from_map(&kv);

        // Parse tensor info records with full metadata
        let mut tensors: Vec<TensorInfo> = Vec::with_capacity(tensor_count);
        let mut tensors_by_name: HashMap<String, usize> = HashMap::new();
        let mut min_offset: Option<u64> = None;

        for i in 0..tensor_count {
            let tensor_name = read_gguf_string(&mut file)?;

            let mut dim_buf = [0u8; 4];
            file.read_exact(&mut dim_buf)?;
            let n_dims = u32::from_le_bytes(dim_buf) as usize;

            // GGUF spec: dims es uint64[n_dims]. Antes se leían como u32:
            // los 4 bytes altos de cada dim quedaban en el stream y el
            // parser se desalineaba en el segundo tensor ("Malformed" con
            // modelos reales). 0 dims o > 8 (GGML_MAX_DIMS = 4) es corrupción.
            if n_dims == 0 || n_dims > 8 {
                return Err(GgufError::Malformed);
            }

            let mut dimensions = Vec::with_capacity(n_dims);
            let mut element_count: u64 = 1;
            for _ in 0..n_dims {
                let mut dim64_buf = [0u8; 8];
                file.read_exact(&mut dim64_buf)?;
                let dim = u64::from_le_bytes(dim64_buf);
                dimensions.push(dim);
                element_count = element_count.saturating_mul(dim);
            }

            file.read_exact(&mut dim_buf)?;
            let ggml_type = u32::from_le_bytes(dim_buf);
            let quantization = parse_quantization_type(ggml_type)?;

            // Tamaño exacto en enteros: blocks de tamaño fijo por tipo
            // (tabla verificada contra static_asserts de ggml-common.h).
            // f32 pierde precisión con element_count > 16M.
            let tensor_bytes = match quantization.block_layout() {
                Some((blck, block_bytes)) => {
                    element_count.div_ceil(blck as u64) * block_bytes as u64
                }
                None => {
                    // Tipo desconocido: aproximación conservadora en f64
                    (element_count as f64 * quantization.bytes_per_element() as f64) as u64
                }
            };

            file.read_exact(&mut buf)?;
            let offset = u64::from_le_bytes(buf);

            if min_offset.is_none_or(|m| offset < m) {
                min_offset = Some(offset);
            }

            let tensor_info = TensorInfo {
                name: tensor_name.clone(),
                tensor_index: i,
                layer_index: 0, // Will be assigned during layer grouping
                offset,
                byte_size: tensor_bytes,
                quantization,
                dimensions,
                element_count,
            };

            tensors_by_name.insert(tensor_name, i);
            tensors.push(tensor_info);
        }

        // Fin del header: los datos empiezan aquí, alineados a 32 bytes
        // (GGUF_DEFAULT_ALIGNMENT).
        let header_end = file.stream_position()? as usize;
        let aligned_header_end = (header_end + 31) & !31;

        // Offsets: v2 son relativos al inicio de los datos del tensor
        // (spec). v3 son absolutos (spec) — PERO hay archivos v3 reales
        // (re-cuantizados con llama.cpp 2024) que siguen guardando
        // offsets relativos. Detección empírica: si el primer tensor
        // "empieza" antes del fin del header, es imposible en absoluto —
        // son relativos de facto y se corrigen sumando el header.
        let raw_min = min_offset.unwrap_or(0);
        let offsets_relative = version == 2 || raw_min < aligned_header_end as u64;
        if version >= 3 && offsets_relative {
            tracing::warn!(
                "GGUF v3 con offsets relativos de facto (primer tensor en {} < header alineado {}): writer no conforme a spec, corrigiendo",
                raw_min,
                aligned_header_end
            );
        }
        if offsets_relative {
            for t in &mut tensors {
                t.offset = t.offset.saturating_add(aligned_header_end as u64);
            }
        }

        let data_offset = if offsets_relative {
            (raw_min + aligned_header_end as u64) as usize
        } else {
            raw_min as usize
        };

        // Group tensors into logical layers
        let layers =
            Self::group_tensors_into_layers(&mut tensors, expected_layers, file_size, data_offset);

        tracing::info!(
            "NanoModelIndex: {} tensors, {} layers, data_offset={}, page_size={}, file_size={}",
            tensor_count,
            layers.len(),
            data_offset,
            page_info.page_size,
            file_size
        );

        Ok(Self {
            tensors,
            tensors_by_name,
            layers,
            page_info,
            file_size,
            data_offset,
            tensor_count,
            gguf_version: version,
            metadata,
        })
    }

    /// Deriva un `ModelProfile` (para planificación física) desde el índice.
    /// La arquitectura sale de `metadata.architecture_type()`; el tamaño del
    /// archivo es el proxy del footprint de pesos; el número de capas sale de
    /// los tensores. Para MoE, el tamaño activo se estima por la fracción
    /// `expert_used_count / expert_count`.
    pub fn to_model_profile(&self) -> ModelProfile {
        let total_mb = (self.file_size / (1024 * 1024)) as u64;
        let n_layers = self.layers.len();
        match self.metadata.architecture_type() {
            ArchitectureType::MixtureOfExperts => {
                let active_frac = match (
                    self.metadata.expert_count,
                    self.metadata.expert_used_count,
                ) {
                    (Some(total), Some(used)) if total > 0 => used as f64 / total as f64,
                    _ => 0.25,
                };
                let active_mb = ((total_mb as f64) * active_frac.max(0.01)) as u64;
                ModelProfile::new_moe(total_mb, active_mb.max(1), n_layers)
            }
            ArchitectureType::Dense => ModelProfile::new_dense(total_mb, n_layers),
        }
    }

    /// Group tensors into logical layers.
    ///
    /// La capa REAL la declara el nombre del tensor (`blk.N.*`). Los
    /// tensores sin capa en el nombre (output, token_embd) caen en el
    /// bucket contiguo por orden de archivo.
    fn group_tensors_into_layers(
        tensors: &mut [TensorInfo],
        expected_layers: usize,
        file_size: usize,
        data_offset: usize,
    ) -> BTreeMap<usize, LayerInfo> {
        let mut layers = BTreeMap::new();

        if tensors.is_empty() {
            return layers;
        }

        // Sort tensors by offset
        tensors.sort_by_key(|t| t.offset);

        let tensor_count = tensors.len();

        if tensor_count <= expected_layers {
            // One tensor per layer (or close to it)
            // First collect all the offsets
            let offsets: Vec<u64> = tensors.iter().map(|t| t.offset).collect();

            for (layer_idx, tensor) in tensors.iter_mut().enumerate() {
                tensor.layer_index = layer_idx;

                let start = tensor.offset as usize;
                let end = if layer_idx + 1 < tensor_count {
                    offsets[layer_idx + 1] as usize
                } else {
                    (tensor.offset as usize + tensor.byte_size as usize).min(file_size)
                };

                layers.insert(
                    layer_idx,
                    LayerInfo {
                        layer_index: layer_idx,
                        byte_range: ByteRange { start, end },
                        byte_size: tensor.byte_size,
                        tensor_indices: vec![tensor.tensor_index],
                        dominant_quantization: tensor.quantization,
                        avg_bytes_per_element: tensor.quantization.bytes_per_element(),
                    },
                );
            }
        } else {
            // Múltiples tensores por capa — agrupar por la capa REAL que
            // declara el nombre (blk.N.*). Tensores sin capa en el nombre
            // (output, token_embd) caen en bucket contiguo por orden de
            // archivo.
            let tensors_per_layer = tensor_count.div_ceil(expected_layers);
            for tensor in tensors.iter_mut() {
                let mut assigned = false;
                if let Some(rest) = tensor.name.strip_prefix("blk.") {
                    let digits: String = rest.chars().take_while(|c| c.is_ascii_digit()).collect();
                    if let Ok(n) = digits.parse::<usize>() {
                        if n < expected_layers {
                            tensor.layer_index = n;
                            assigned = true;
                        }
                    }
                }
                if !assigned {
                    let bucket = (tensor.tensor_index / tensors_per_layer).min(expected_layers - 1);
                    tensor.layer_index = bucket;
                }
            }

            for layer_idx in 0..expected_layers {
                // Posiciones en `tensors` (ordenado por offset) de esta capa
                let layer_tensor_indices: Vec<usize> = tensors
                    .iter()
                    .enumerate()
                    .filter(|(_, t)| t.layer_index == layer_idx)
                    .map(|(i, _)| i)
                    .collect();
                if layer_tensor_indices.is_empty() {
                    continue;
                }

                let layer_tensors_data: Vec<(u64, u64, QuantizationType, u64)> =
                    layer_tensor_indices
                        .iter()
                        .map(|&idx| {
                            let t = &tensors[idx];
                            (t.offset, t.byte_size, t.quantization, t.element_count)
                        })
                        .collect();

                let start = layer_tensors_data
                    .iter()
                    .map(|(o, _, _, _)| *o as usize)
                    .min()
                    .unwrap_or(data_offset);
                let end = layer_tensors_data
                    .iter()
                    .map(|(o, bs, _, _)| (*o + *bs) as usize)
                    .max()
                    .unwrap_or(data_offset)
                    .min(file_size);

                let total_bytes: u64 = layer_tensors_data.iter().map(|(_, bs, _, _)| *bs).sum();
                let tensor_indices: Vec<usize> = layer_tensor_indices
                    .iter()
                    .map(|&i| tensors[i].tensor_index)
                    .collect();

                // Find dominant quantization
                let mut quant_counts: std::collections::HashMap<QuantizationType, usize> =
                    std::collections::HashMap::new();
                for (_, _, quant, _) in &layer_tensors_data {
                    *quant_counts.entry(*quant).or_insert(0) += 1;
                }
                let dominant_quantization = quant_counts
                    .into_iter()
                    .max_by_key(|(_, count)| *count)
                    .map(|(q, _)| q)
                    .unwrap_or(QuantizationType::F32);

                // Calculate average bytes per element
                let total_elements: u64 = layer_tensors_data.iter().map(|(_, _, _, ec)| *ec).sum();
                let avg_bytes_per_element = if total_elements > 0 {
                    (total_bytes as f32) / (total_elements as f32)
                } else {
                    4.0
                };

                layers.insert(
                    layer_idx,
                    LayerInfo {
                        layer_index: layer_idx,
                        byte_range: ByteRange { start, end },
                        byte_size: total_bytes,
                        tensor_indices,
                        dominant_quantization,
                        avg_bytes_per_element,
                    },
                );
            }
        }

        layers
    }

    /// Get layer info by index
    pub fn get_layer(&self, layer_idx: usize) -> Option<&LayerInfo> {
        self.layers.get(&layer_idx)
    }

    /// Get byte range for a specific layer
    pub fn get_layer_range(&self, layer_idx: usize) -> Option<&ByteRange> {
        self.layers.get(&layer_idx).map(|l| &l.byte_range)
    }

    /// Get tensor info by index
    pub fn get_tensor(&self, tensor_idx: usize) -> Option<&TensorInfo> {
        self.tensors.get(tensor_idx)
    }

    /// Get tensor info by name
    pub fn get_tensor_by_name(&self, name: &str) -> Option<&TensorInfo> {
        self.tensors_by_name
            .get(name)
            .and_then(|&idx| self.tensors.get(idx))
    }

    /// Group layer indices into contiguous byte ranges for efficient syscall batching
    pub fn group_contiguous_layers(&self, layer_indices: &[usize]) -> Vec<ByteRange> {
        if layer_indices.is_empty() {
            return Vec::new();
        }

        let mut sorted_indices = layer_indices.to_vec();
        sorted_indices.sort_unstable();

        let mut ranges = Vec::new();
        let mut current_range: Option<ByteRange> = None;
        let mut prev_idx: Option<usize> = None;

        for &idx in &sorted_indices {
            if let Some(layer_info) = self.get_layer(idx) {
                let layer_range = &layer_info.byte_range;
                if let Some(ref mut current) = current_range {
                    // Contigüidad física: solo capas ADYACENTES en índice
                    // forman un rango. Saltarse capas intermedias (activas
                    // 2 y 5 con 3-4 inactivas entre medio) NO es contiguo:
                    // los bytes intermedios pertenecen a otras capas.
                    let adjacent = prev_idx.is_some_and(|p| idx == p + 1);
                    // Tolerancia de página: micro-gaps de alineación entre
                    // tensores de capas adyacentes no rompen el rango.
                    let gap = layer_range.start.saturating_sub(current.end);
                    let tolerance = self.page_info.page_size;
                    if adjacent && gap <= tolerance {
                        current.end = current.end.max(layer_range.end);
                    } else {
                        ranges.push(current.clone());
                        current_range = Some(layer_range.clone());
                    }
                } else {
                    current_range = Some(layer_range.clone());
                }
                prev_idx = Some(idx);
            }
        }

        if let Some(current) = current_range {
            ranges.push(current);
        }

        ranges
    }

    /// Estimate working set for a given set of active layers
    pub fn estimate_working_set(
        &self,
        active_layers: &[usize],
        kv_cache_tokens: usize,
        runtime_overhead_mb: f64,
    ) -> WorkingSetEstimate {
        let mut weights_bytes: u64 = 0;
        let mut active_layer_count = 0;

        for &layer_idx in active_layers {
            if let Some(layer_info) = self.get_layer(layer_idx) {
                weights_bytes += layer_info.byte_size;
                active_layer_count += 1;
            }
        }

        // Estimate KV cache (simplified: assumes average token size)
        let kv_bytes = (kv_cache_tokens as f64 * 0.03 * active_layer_count as f64 * 1024.0) as u64;
        let runtime_bytes = (runtime_overhead_mb * 1024.0 * 1024.0) as u64;
        let total_bytes = weights_bytes + kv_bytes + runtime_bytes;

        let page_count = self.page_info.page_count(&ByteRange {
            start: 0,
            end: total_bytes as usize,
        });

        WorkingSetEstimate {
            weights_bytes,
            kv_bytes,
            runtime_bytes,
            total_bytes,
            active_layers: active_layer_count,
            page_count,
        }
    }

    /// Get total model size in bytes
    pub fn total_model_bytes(&self) -> u64 {
        self.layers.values().map(|l| l.byte_size).sum()
    }

    /// Get model size in MB
    pub fn total_model_mb(&self) -> f64 {
        self.total_model_bytes() as f64 / (1024.0 * 1024.0)
    }

    /// Get the system page size
    pub fn page_size(&self) -> usize {
        self.page_info.page_size
    }

    /// Check if page size was auto-detected
    pub fn is_page_size_auto_detected(&self) -> bool {
        self.page_info.auto_detected
    }

    /// Get quantization summary for the model
    pub fn quantization_summary(&self) -> std::collections::HashMap<QuantizationType, usize> {
        let mut summary = std::collections::HashMap::new();
        for tensor in &self.tensors {
            *summary.entry(tensor.quantization).or_insert(0) += 1;
        }
        summary
    }

    /// Get layer indices that contain a specific tensor name pattern
    pub fn find_layers_with_pattern(&self, pattern: &str) -> Vec<usize> {
        let mut layers = std::collections::HashSet::new();
        for tensor in &self.tensors {
            if tensor.name.contains(pattern) {
                layers.insert(tensor.layer_index);
            }
        }
        let mut result: Vec<_> = layers.into_iter().collect();
        result.sort();
        result
    }

    /// Generate a mock index for testing
    #[cfg(test)]
    pub fn mock_index(expected_layers: usize, file_size: usize) -> Self {
        let page_info = PageSizeInfo {
            page_size: 4096,
            auto_detected: false,
        };

        let mut tensors = Vec::new();
        let mut tensors_by_name = HashMap::new();
        let mut layers = BTreeMap::new();

        let data_offset = 128;
        let data_size = file_size.saturating_sub(data_offset);
        let layer_size = data_size / expected_layers.max(1);

        for i in 0..expected_layers {
            let start = data_offset + (i * layer_size);
            let end = start + layer_size;

            // Create a mock tensor for each layer
            let tensor_name = format!("blk.{}.attn_q.weight", i);
            let tensor_info = TensorInfo {
                name: tensor_name.clone(),
                tensor_index: i,
                layer_index: i,
                offset: start as u64,
                byte_size: layer_size as u64,
                quantization: QuantizationType::Q4_K,
                dimensions: vec![4096, 4096],
                element_count: 4096 * 4096,
            };

            tensors_by_name.insert(tensor_name, i);
            tensors.push(tensor_info);

            layers.insert(
                i,
                LayerInfo {
                    layer_index: i,
                    byte_range: ByteRange { start, end },
                    byte_size: layer_size as u64,
                    tensor_indices: vec![i],
                    dominant_quantization: QuantizationType::Q4_K,
                    avg_bytes_per_element: QuantizationType::Q4_K.bytes_per_element(),
                },
            );
        }

        Self {
            tensors,
            tensors_by_name,
            layers,
            page_info,
            file_size,
            data_offset,
            tensor_count: expected_layers,
            gguf_version: 3,
            metadata: GgufMetadata::default(),
        }
    }
}

// ── GGUF header parsing helpers ───────────────────────────────────────

/// Parse quantization type from GGML type ID
fn parse_quantization_type(ggml_type: u32) -> Result<QuantizationType, GgufError> {
    match ggml_type {
        0 => Ok(QuantizationType::F32),
        1 => Ok(QuantizationType::F16),
        2 => Ok(QuantizationType::Q4_0),
        3 => Ok(QuantizationType::Q4_1),
        6 => Ok(QuantizationType::Q5_0),
        7 => Ok(QuantizationType::Q5_1),
        8 => Ok(QuantizationType::Q8_0),
        9 => Ok(QuantizationType::Q8_1),
        10 => Ok(QuantizationType::Q2_K),
        11 => Ok(QuantizationType::Q3_K),
        12 => Ok(QuantizationType::Q4_K),
        13 => Ok(QuantizationType::Q5_K),
        14 => Ok(QuantizationType::Q6_K),
        15 => Ok(QuantizationType::Q8_K),
        16 => Ok(QuantizationType::IQ2_XXS),
        17 => Ok(QuantizationType::IQ2_XS),
        18 => Ok(QuantizationType::IQ3_XXS),
        19 => Ok(QuantizationType::IQ1_S),
        20 => Ok(QuantizationType::IQ4_NL),
        21 => Ok(QuantizationType::IQ3_S),
        22 => Ok(QuantizationType::IQ2_S),
        23 => Ok(QuantizationType::IQ4_XS),
        24 => Ok(QuantizationType::I8),
        25 => Ok(QuantizationType::I16),
        26 => Ok(QuantizationType::I32),
        27 => Ok(QuantizationType::I64),
        28 => Ok(QuantizationType::F64),
        29 => Ok(QuantizationType::IQ1_M),
        30 => Ok(QuantizationType::BF16),
        _ => Err(GgufError::InvalidQuantization(ggml_type)),
    }
}

/// Read a GGUF string and return its contents
fn read_gguf_string(file: &mut File) -> Result<String, GgufError> {
    let mut len_buf = [0u8; 8];
    file.read_exact(&mut len_buf)?;
    let len = u64::from_le_bytes(len_buf) as usize;

    // Cap at 16MB to prevent OOM on malformed files
    if len > 16 * 1024 * 1024 {
        return Err(GgufError::Malformed);
    }

    let mut buffer = vec![0u8; len];
    file.read_exact(&mut buffer)?;
    String::from_utf8(buffer).map_err(|_| GgufError::Malformed)
}

/// Skip a GGUF string (discard contents)
fn skip_gguf_string(file: &mut File) -> Result<(), GgufError> {
    let mut len_buf = [0u8; 8];
    file.read_exact(&mut len_buf)?;
    let len = u64::from_le_bytes(len_buf) as usize;

    if len > 16 * 1024 * 1024 {
        return Err(GgufError::Malformed);
    }

    file.seek(SeekFrom::Current(len as i64))?;
    Ok(())
}

/// Lee el contenido de un array GGUF y lo descarta. Se usa para los KV que no
/// extraemos (p.ej. `tokenizer.ggml.tokens`): mantiene la alineación del
/// stream sin asignar decenas de miles de strings.
fn skip_gguf_array_contents(file: &mut File) -> Result<(), GgufError> {
    let mut elem_type_buf = [0u8; 4];
    file.read_exact(&mut elem_type_buf)?;
    let elem_type = u32::from_le_bytes(elem_type_buf);

    let mut count_buf = [0u8; 8];
    file.read_exact(&mut count_buf)?;
    let count = u64::from_le_bytes(count_buf);

    if count > 1_000_000 {
        return Err(GgufError::Malformed);
    }

    if elem_type == 8 {
        for _ in 0..count {
            skip_gguf_string(file)?;
        }
    } else if elem_type <= 12 {
        // GGUF spec: arrays solo de tipos primitivos 0..=12 (los arrays
        // anidados no existen en el formato). bool (7) = 1 byte.
        let elem_size: i64 = match elem_type {
            0 | 1 => 1,
            2 | 3 => 2,
            4..=6 => 4,
            7 => 1,
            10..=12 => 8,
            _ => unreachable!(),
        };
        file.seek(SeekFrom::Current(elem_size * count as i64))?;
    } else {
        return Err(GgufError::Malformed);
    }
    Ok(())
}

/// Lee un valor GGUF (escalar o string). Los arrays se descartan (ver
/// `skip_gguf_array_contents`). El tipo (u32) determina cuántos bytes leer.
fn read_gguf_value(file: &mut File) -> Result<GgufValue, GgufError> {
    let mut type_buf = [0u8; 4];
    file.read_exact(&mut type_buf)?;
    let value_type = u32::from_le_bytes(type_buf);

    match value_type {
        0 => {
            let mut b = [0u8; 1];
            file.read_exact(&mut b)?;
            Ok(GgufValue::U8(b[0]))
        }
        1 => {
            let mut b = [0u8; 1];
            file.read_exact(&mut b)?;
            Ok(GgufValue::I8(b[0] as i8))
        }
        2 => {
            let mut b = [0u8; 2];
            file.read_exact(&mut b)?;
            Ok(GgufValue::U16(u16::from_le_bytes(b)))
        }
        3 => {
            let mut b = [0u8; 2];
            file.read_exact(&mut b)?;
            Ok(GgufValue::I16(i16::from_le_bytes(b)))
        }
        4 => {
            let mut b = [0u8; 4];
            file.read_exact(&mut b)?;
            Ok(GgufValue::U32(u32::from_le_bytes(b)))
        }
        5 => {
            let mut b = [0u8; 4];
            file.read_exact(&mut b)?;
            Ok(GgufValue::I32(i32::from_le_bytes(b)))
        }
        6 => {
            let mut b = [0u8; 4];
            file.read_exact(&mut b)?;
            Ok(GgufValue::F32(f32::from_le_bytes(b)))
        }
        7 => {
            let mut b = [0u8; 1];
            file.read_exact(&mut b)?;
            Ok(GgufValue::Bool(b[0] != 0))
        }
        8 => Ok(GgufValue::String(read_gguf_string(file)?)),
        9 => {
            skip_gguf_array_contents(file)?;
            Ok(GgufValue::Array)
        }
        10 => {
            let mut b = [0u8; 8];
            file.read_exact(&mut b)?;
            Ok(GgufValue::U64(u64::from_le_bytes(b)))
        }
        11 => {
            let mut b = [0u8; 8];
            file.read_exact(&mut b)?;
            Ok(GgufValue::I64(i64::from_le_bytes(b)))
        }
        12 => {
            let mut b = [0u8; 8];
            file.read_exact(&mut b)?;
            Ok(GgufValue::F64(f64::from_le_bytes(b)))
        }
        _ => Err(GgufError::Malformed),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_mock_index_basic() {
        let index = NanoModelIndex::mock_index(4, 256);

        assert_eq!(index.layers.len(), 4);
        assert_eq!(index.data_offset, 128);
        assert_eq!(index.tensor_count, 4);
        assert_eq!(index.page_size(), 4096);

        // 256 - 128 = 128 bytes of data / 4 layers = 32 bytes per layer
        let r0 = index.get_layer_range(0).unwrap();
        assert_eq!(r0.start, 128);
        assert_eq!(r0.end, 160);

        let r3 = index.get_layer_range(3).unwrap();
        assert_eq!(r3.start, 224);
        assert_eq!(r3.end, 256);
    }

    #[test]
    fn test_group_contiguous_layers() {
        let index = NanoModelIndex::mock_index(8, 10000);

        let ranges = index.group_contiguous_layers(&[0, 1, 2, 5, 6]);
        assert_eq!(ranges.len(), 2);

        // Verify contiguity grouping works with dynamic page size
        assert!(ranges[0].start < ranges[0].end);
        assert!(ranges[1].start < ranges[1].end);
        assert!(ranges[0].end < ranges[1].start); // Should be separate ranges
    }

    #[test]
    fn test_quantization_type_efficiency() {
        let f32_eff = QuantizationType::F32.efficiency_factor();
        let q4k_eff = QuantizationType::Q4_K.efficiency_factor();

        assert!((f32_eff - 1.0).abs() < 0.01); // F32 baseline
        assert!(q4k_eff > f32_eff); // Q4_K should be more efficient
                                    // 4.0 / 0.5625 = 7.11x (bloque real Q4_K: 144 bytes / 256 elementos)
        assert!((q4k_eff - 7.111).abs() < 0.01);
    }

    #[test]
    fn test_working_set_estimation() {
        let index = NanoModelIndex::mock_index(4, 256);

        let ws = index.estimate_working_set(&[0, 1, 2], 512, 200.0);

        assert!(ws.weights_bytes > 0);
        assert!(ws.active_layers == 3);
        assert!(ws.total_bytes > ws.weights_bytes);
        assert!(ws.page_count > 0);
    }

    #[test]
    fn test_tensor_lookup() {
        let index = NanoModelIndex::mock_index(4, 256);

        // Should find tensor by name
        let tensor = index.get_tensor_by_name("blk.0.attn_q.weight");
        assert!(tensor.is_some());

        // Should not find non-existent tensor
        let missing = index.get_tensor_by_name("nonexistent");
        assert!(missing.is_none());
    }

    #[test]
    fn test_find_layers_with_pattern() {
        let index = NanoModelIndex::mock_index(8, 10000);

        let attn_layers = index.find_layers_with_pattern("attn");
        assert!(!attn_layers.is_empty());

        // All layers should have attention tensors in our mock
        assert!(attn_layers.len() <= 8);
    }

    #[test]
    fn test_page_size_detection() {
        let page_info = PageSizeInfo::detect();

        // Page size should be power of 2 and reasonable
        assert!(page_info.page_size >= 4096);
        assert!(page_info.page_size <= 65536);
        assert!(page_info.page_size & (page_info.page_size - 1) == 0); // Power of 2
    }

    #[test]
    fn test_page_alignment() {
        let page_info = PageSizeInfo {
            page_size: 4096,
            auto_detected: false,
        };

        assert_eq!(page_info.align_down(4095), 0);
        assert_eq!(page_info.align_down(4096), 4096);
        assert_eq!(page_info.align_down(4097), 4096);

        assert_eq!(page_info.align_up(4095), 4096);
        assert_eq!(page_info.align_up(4096), 4096);
        assert_eq!(page_info.align_up(4097), 8192);
    }

    #[test]
    fn test_model_size_calculation() {
        let index = NanoModelIndex::mock_index(4, 256);

        let total_bytes = index.total_model_bytes();
        let total_mb = index.total_model_mb();

        assert!(total_bytes > 0);
        assert!((total_mb - (total_bytes as f64 / (1024.0 * 1024.0))).abs() < 0.01);
    }

    #[test]
    fn test_gguf_metadata_from_map_dense() {
        let mut map = HashMap::new();
        map.insert(
            "general.architecture".to_string(),
            GgufValue::String("qwen2".to_string()),
        );
        map.insert(
            "general.parameter_count".to_string(),
            GgufValue::U64(1_500_000_000),
        );
        map.insert("qwen2.context_length".to_string(), GgufValue::U32(32768));
        map.insert("qwen2.block_count".to_string(), GgufValue::U32(28));
        map.insert(
            "tokenizer.chat_template".to_string(),
            GgufValue::String("<|im_start|>".to_string()),
        );

        let meta = GgufMetadata::from_map(&map);
        assert_eq!(meta.architecture.as_deref(), Some("qwen2"));
        assert_eq!(meta.parameter_count, Some(1_500_000_000));
        assert_eq!(meta.context_length, Some(32768));
        assert_eq!(meta.block_count, Some(28));
        assert_eq!(meta.chat_template.as_deref(), Some("<|im_start|>"));
        assert!(!meta.is_moe());
        assert!(!meta.is_embedding());
    }

    #[test]
    fn test_gguf_metadata_from_map_moe() {
        let mut map = HashMap::new();
        map.insert(
            "general.architecture".to_string(),
            GgufValue::String("qwen3moe".to_string()),
        );
        map.insert("qwen3moe.expert_count".to_string(), GgufValue::U32(128));
        map.insert(
            "qwen3moe.expert_used_count".to_string(),
            GgufValue::U32(8),
        );

        let meta = GgufMetadata::from_map(&map);
        assert!(meta.is_moe());
        assert_eq!(meta.expert_count, Some(128));
        assert_eq!(meta.expert_used_count, Some(8));
    }

    #[test]
    fn test_gguf_metadata_fallback_general_prefix() {
        // Algunos GGUF usan `general.context_length` en vez de
        // `<arch>.context_length`: el fallback debe resolver igual.
        let mut map = HashMap::new();
        map.insert(
            "general.architecture".to_string(),
            GgufValue::String("llama".to_string()),
        );
        map.insert("general.context_length".to_string(), GgufValue::U32(4096));

        let meta = GgufMetadata::from_map(&map);
        assert_eq!(meta.context_length, Some(4096));
    }

    #[test]
    fn test_gguf_value_as_u64() {
        assert_eq!(GgufValue::U32(4096).as_u64(), Some(4096));
        assert_eq!(GgufValue::U64(8192).as_u64(), Some(8192));
        assert_eq!(GgufValue::U8(7).as_u64(), Some(7));
        assert_eq!(GgufValue::String("x".into()).as_u64(), None);
    }

    #[test]
    fn test_gguf_metadata_architecture_type() {
        let dense = GgufMetadata {
            architecture: Some("qwen2".to_string()),
            ..Default::default()
        };
        assert_eq!(dense.architecture_type(), ArchitectureType::Dense);

        let moe = GgufMetadata {
            architecture: Some("qwen3moe".to_string()),
            expert_count: Some(128),
            ..Default::default()
        };
        assert_eq!(moe.architecture_type(), ArchitectureType::MixtureOfExperts);
    }

    #[test]
    fn test_to_model_profile_dense() {
        let index = NanoModelIndex::mock_index(4, 256);
        let profile = index.to_model_profile();
        assert_eq!(profile.architecture, ArchitectureType::Dense);
        assert_eq!(profile.n_layers, 4);
    }
}
