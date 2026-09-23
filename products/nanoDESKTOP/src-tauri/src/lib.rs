//! NanoAI Desktop Core Library.
//!
//! Inicializa los subsistemas del cliente de escritorio, gestiona el estado
//! de aplicación (RuntimeService y ShellManager) y registra los comandos de Tauri.

pub mod commands;
pub mod runtime;
pub mod shell;

use std::sync::Arc;
use runtime::RuntimeService;
use shell::ShellManager;

pub fn run() {
    let runtime_service = Arc::new(RuntimeService::new());
    let shell_manager = Arc::new(ShellManager::new());

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .manage(runtime_service)
        .manage(shell_manager)
        .invoke_handler(tauri::generate_handler![
            commands::nano_chat_prompt,
            commands::nano_chat_prompt_stream,
            commands::nano_system_status,
            commands::nano_list_models,
            commands::nano_pty_open,
            commands::nano_pty_write,
            commands::nano_pty_resize,
            commands::nano_pty_close,
        ])
        .run(tauri::generate_context!())
        .expect("error while running NanoAI Desktop application");
}
