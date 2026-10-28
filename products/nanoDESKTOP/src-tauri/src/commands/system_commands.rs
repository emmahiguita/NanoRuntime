use serde::Serialize;
use sysinfo::System;
use std::{io::Read, sync::Arc};
use tauri::State;
use crate::runtime::RuntimeService;

#[derive(Debug, Serialize)]
pub struct SystemTelemetry {
    pub os_name: String,
    pub arch: String,
    pub total_ram_mb: u64,
    pub used_ram_mb: u64,
    pub available_ram_mb: u64,
    pub runtime_version: String,
    pub status: String,
    pub model_loaded: bool,
    pub model_name: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct ModelEntry {
    pub name: String,
    pub path: String,
    pub size_mb: u64,
    pub is_loaded: bool,
}

/// Obtiene telemetría de hardware real sin valores falsos
#[tauri::command]
pub async fn nano_system_status(service: State<'_, Arc<RuntimeService>>) -> Result<SystemTelemetry, String> {
    let mut sys = System::new_all();
    sys.refresh_all();

    let total_ram_mb = sys.total_memory() / (1024 * 1024);
    let used_ram_mb = sys.used_memory() / (1024 * 1024);
    let available_ram_mb = sys.available_memory() / (1024 * 1024);
    // La RAM es del equipo; la disponibilidad del modelo se consulta al servicio real.
    let model = service.current_model().await;
    let ready = model != "none";

    Ok(SystemTelemetry {
        os_name: std::env::consts::OS.to_string(),
        arch: std::env::consts::ARCH.to_string(),
        total_ram_mb,
        used_ram_mb,
        available_ram_mb,
        runtime_version: env!("CARGO_PKG_VERSION").to_string(),
        status: if ready { "online" } else { "offline" }.into(),
        model_loaded: ready,
        model_name: ready.then_some(model),
    })
}

/// Enumera GGUF con cabecera válida; un archivo .bin o de prueba no es un modelo.
#[tauri::command]
pub fn nano_list_models() -> Result<Vec<ModelEntry>, String> {
    let mut list = Vec::new();
    let current_dir = std::env::current_dir().map_err(|e| e.to_string())?;
    // Soporta la ejecución desde el checkout y desde una instalación con carpeta models.
    let checkout = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).ancestors().nth(3);
    let mut roots = vec![current_dir.clone(), current_dir.join("models")];
    if let Some(root) = checkout { roots.extend([root.to_path_buf(), root.join("models")]); }
    for root in roots {
    if let Ok(entries) = std::fs::read_dir(&root) {
        for entry in entries.flatten() {
            let path = entry.path();
            if let Some(ext) = path.extension() {
                if ext == "gguf" {
                    let Ok(path) = path.canonicalize() else { continue };
                    let Ok(allowed) = root.canonicalize() else { continue };
                    if !path.starts_with(allowed) || list.iter().any(|m: &ModelEntry| m.path == path.to_string_lossy()) { continue; }
                    let mut header = [0u8; 24];
                    let valid = std::fs::File::open(&path).and_then(|mut f| f.read_exact(&mut header)).is_ok();
                    if !valid || &header[..4] != b"GGUF" || !matches!(u32::from_le_bytes(header[4..8].try_into().unwrap()), 2 | 3)
                        || u64::from_le_bytes(header[8..16].try_into().unwrap()) == 0
                        || u64::from_le_bytes(header[16..24].try_into().unwrap()) == 0 { continue; }
                    let file_name = path
                        .file_name()
                        .map(|n| n.to_string_lossy().to_string())
                        .unwrap_or_default();
                    let size_mb = entry
                        .metadata()
                        .map(|m| m.len() / (1024 * 1024))
                        .unwrap_or(0);
                    if size_mb < 1 { continue; }

                    list.push(ModelEntry {
                        name: file_name,
                        path: path.to_string_lossy().to_string(),
                        size_mb,
                        is_loaded: false,
                    });
                }
            }
        }
    }
    }

    list.sort_by_key(|m| (m.size_mb, m.name.clone()));
    Ok(list)
}
