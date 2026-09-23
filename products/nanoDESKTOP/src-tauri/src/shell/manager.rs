//! ShellManager: Registro central de sesiones PTY y prevención de procesos zombie.
//!
//! QUÉ HACE: Administra de forma concurrente todas las sesiones de terminal activas,
//! enrutando comandos stdin, eventos resize y garantizando terminación limpia.
//!
//! CÓMO FUNCIONA: Mantiene un mapa protegido con `tokio::sync::Mutex` de instancias
//! `PtySession`. Al invocar `close` o `shutdown_all`, las sesiones se eliminan del
//! mapa disparando sus destructores `Drop` y terminando los procesos en el SO.
//!
//! POR QUÉ: Evita fugas de procesos en memoria cuando el usuario recarga la pestaña,
//! cambia de vista o cierra la aplicación Nano Desktop.

use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::Mutex;
use tauri::AppHandle;

use super::native_pty::NativePtyShell;
use super::session::PtySession;

pub struct ShellManager {
    sessions: Arc<Mutex<HashMap<String, PtySession>>>,
}

impl Default for ShellManager {
    fn default() -> Self {
        Self::new()
    }
}

impl ShellManager {
    pub fn new() -> Self {
        Self {
            sessions: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    /// Abre una nueva sesión interactiva de shell y la registra en el mapa.
    pub async fn open_session(
        &self,
        app: AppHandle,
        session_id: &str,
        rows: u16,
        cols: u16,
    ) -> Result<(), String> {
        let mut map = self.sessions.lock().await;

        // Si la sesión ya existía, se descarta la anterior liberando el subproceso previo
        if let Some(mut old) = map.remove(session_id) {
            old.terminate();
        }

        let session = NativePtyShell::spawn(app, session_id.to_string(), rows, cols)?;
        map.insert(session_id.to_string(), session);
        Ok(())
    }

    /// Escribe caracteres en el stdin de la sesión especificada.
    pub async fn write_data(&self, session_id: &str, data: &str) -> Result<(), String> {
        let mut map = self.sessions.lock().await;
        let session = map
            .get_mut(session_id)
            .ok_or_else(|| format!("Sesión PTY no encontrada: {}", session_id))?;

        session.write_bytes(data.as_bytes())
    }

    /// Redimensiona la geometría de la sesión PTY.
    pub async fn resize_session(
        &self,
        session_id: &str,
        rows: u16,
        cols: u16,
    ) -> Result<(), String> {
        let map = self.sessions.lock().await;
        let session = map
            .get(session_id)
            .ok_or_else(|| format!("Sesión PTY no encontrada: {}", session_id))?;

        session.resize(rows, cols)
    }

    /// Cierra explícitamente una sesión y mata el subproceso asociado.
    pub async fn close_session(&self, session_id: &str) -> Result<(), String> {
        let mut map = self.sessions.lock().await;
        if let Some(mut session) = map.remove(session_id) {
            session.terminate();
        }
        Ok(())
    }

    /// Limpieza global de emergencia contra procesos zombie al cerrar Nano Desktop.
    pub async fn shutdown_all(&self) {
        let mut map = self.sessions.lock().await;
        for (_, mut session) in map.drain() {
            session.terminate();
        }
    }
}
