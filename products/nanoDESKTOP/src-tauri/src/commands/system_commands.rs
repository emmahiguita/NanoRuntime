use serde::Serialize;
use sysinfo::System;

#[derive(Debug, Serialize)]
pub struct SystemTelemetry {
    pub os_name: String,
    pub arch: String,
    pub total_ram_mb: u64,
    pub used_ram_mb: u64,
    pub available_ram_mb: u64,
    pub runtime_version: String,
    pub status: String,
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
pub fn nano_system_status() -> Result<SystemTelemetry, String> {
    let mut sys = System::new_all();
    sys.refresh_all();

    let total_ram_mb = sys.total_memory() / (1024 * 1024);
    let used_ram_mb = sys.used_memory() / (1024 * 1024);
    let available_ram_mb = sys.available_memory() / (1024 * 1024);

    Ok(SystemTelemetry {
        os_name: std::env::consts::OS.to_string(),
        arch: std::env::consts::ARCH.to_string(),
        total_ram_mb,
        used_ram_mb,
        available_ram_mb,
        runtime_version: env!("CARGO_PKG_VERSION").to_string(),
        status: "online".into(),
    })
}

/// Enumera modelos locales disponibles en el directorio de trabajo
#[tauri::command]
pub fn nano_list_models() -> Result<Vec<ModelEntry>, String> {
    let mut list = Vec::new();
    let current_dir = std::env::current_dir().unwrap_or_else(|_| ".".into());

    if let Ok(entries) = std::fs::read_dir(current_dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if let Some(ext) = path.extension() {
                if ext == "gguf" || ext == "bin" {
                    let file_name = path
                        .file_name()
                        .map(|n| n.to_string_lossy().to_string())
                        .unwrap_or_default();
                    let size_mb = entry
                        .metadata()
                        .map(|m| m.len() / (1024 * 1024))
                        .unwrap_or(0);

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

    Ok(list)
}
