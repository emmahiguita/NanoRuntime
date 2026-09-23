//! Comandos IPC de Tauri para la Terminal PTY Nativa.
//!
//! QUÉ HACE: Expone al frontend JavaScript la capacidad de interactuar con la
//! consola real del sistema operativo (stdin, resize, close).
//!
//! CÓMO FUNCIONA: Enruta las invocaciones hacia `ShellManager` inyectado en el estado
//! de la aplicación. No ejecuta strings arbitrarios mediante `sh -c` o `cmd /c`,
//! sino a través de descriptores de terminal interactiva con sessionId protegido.
//!
//! POR QUÉ: Minimiza drásticamente la superficie de ataque y previene inyecciones
//! de comandos no autorizadas fuera de la sesión PTY activa.

use std::sync::Arc;
use tauri::{AppHandle, State};

use crate::shell::ShellManager;

/// Abre una sesión nativa de terminal (PowerShell en Windows, Bash/Zsh en Unix).
#[tauri::command]
pub async fn nano_pty_open(
    app: AppHandle,
    manager: State<'_, Arc<ShellManager>>,
    session_id: String,
    rows: u16,
    cols: u16,
) -> Result<(), String> {
    let r = if rows == 0 { 24 } else { rows };
    let c = if cols == 0 { 80 } else { cols };
    manager.open_session(app, &session_id, r, c).await
}

/// Envía datos del teclado o comandos al stdin del proceso PTY.
#[tauri::command]
pub async fn nano_pty_write(
    manager: State<'_, Arc<ShellManager>>,
    session_id: String,
    data: String,
) -> Result<(), String> {
    manager.write_data(&session_id, &data).await
}

/// Redimensiona las columnas y filas del PTY al cambiar el tamaño de la ventana.
#[tauri::command]
pub async fn nano_pty_resize(
    manager: State<'_, Arc<ShellManager>>,
    session_id: String,
    rows: u16,
    cols: u16,
) -> Result<(), String> {
    manager.resize_session(&session_id, rows, cols).await
}

/// Cierra explícitamente el PTY y elimina el subproceso secundario en el SO.
#[tauri::command]
pub async fn nano_pty_close(
    manager: State<'_, Arc<ShellManager>>,
    session_id: String,
) -> Result<(), String> {
    manager.close_session(&session_id).await
}
