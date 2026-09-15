pub mod commands;

pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            commands::nano_chat_prompt,
            commands::nano_system_status,
            commands::nano_list_models,
        ])
        .run(tauri::generate_context!())
        .expect("error while running NanoAI Desktop application");
}
