//! Perfil de modelo (MoE vs Denso)
//! Define las características arquitectónicas del modelo cargado,
//! permitiendo calcular presupuestos de RAM eficientemente.

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ArchitectureType {
    Dense,
    MixtureOfExperts,
}

#[derive(Debug, Clone)]
pub struct ModelProfile {
    pub architecture: ArchitectureType,
    pub total_size_mb: u64,
    /// Para MoE, esto es menor que total_size_mb.
    pub active_size_mb: u64,
    pub n_layers: usize,
}

impl Default for ModelProfile {
    fn default() -> Self {
        Self {
            architecture: ArchitectureType::Dense,
            total_size_mb: 4096,
            active_size_mb: 4096,
            n_layers: 32,
        }
    }
}

impl ModelProfile {
    pub fn new_moe(total_size_mb: u64, active_size_mb: u64, n_layers: usize) -> Self {
        Self {
            architecture: ArchitectureType::MixtureOfExperts,
            total_size_mb,
            active_size_mb,
            n_layers,
        }
    }

    pub fn new_dense(size_mb: u64, n_layers: usize) -> Self {
        Self {
            architecture: ArchitectureType::Dense,
            total_size_mb: size_mb,
            active_size_mb: size_mb,
            n_layers,
        }
    }

    /// Calcula los megabytes requeridos por capa activa.
    pub fn mb_per_active_layer(&self) -> f64 {
        if self.n_layers == 0 {
            return 0.0;
        }
        self.active_size_mb as f64 / self.n_layers as f64
    }
}
