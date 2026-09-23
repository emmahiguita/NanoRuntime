//! NativePtyShell: Implementación concreta de ShellAdapter sobre portable-pty.
//!
//! QUÉ HACE: Crea procesos de consola nativos usando ConPTY (Windows) o pseudo-terminales
//! POSIX (Linux/macOS), transmitiendo su salida por eventos reactivos de Tauri.
//!
//! CÓMO FUNCIONA: Inicializa NativePtySystem, genera el CommandBuilder adecuado para
//! el SO host, extrae el reader en un hilo dedicado que emite chunks ANSI y devuelve
//! la sesión encapsulada.
//!
//! POR QUÉ: Evita simulaciones JavaScript y proporciona una consola real compatible
//! con programas interactivos (git, dir, python, htop, vim) sin procesos zombie.

use std::io::Read;
use portable_pty::{CommandBuilder, NativePtySystem, PtySize, PtySystem};
use tauri::{AppHandle, Emitter};

use super::session::PtySession;

#[derive(Clone, serde::Serialize)]
pub struct PtyOutputPayload {
    pub session_id: String,
    pub data: String,
}

#[derive(Clone, serde::Serialize)]
pub struct PtyExitPayload {
    pub session_id: String,
}

pub struct NativePtyShell;

impl NativePtyShell {
    /// Detecta el ejecutable de shell preferente según el sistema operativo.
    pub fn default_shell_command() -> CommandBuilder {
        if cfg!(target_os = "windows") {
            let mut cmd = CommandBuilder::new("powershell.exe");
            cmd.arg("-NoLogo");
            cmd
        } else {
            let shell = std::env::var("SHELL").unwrap_or_else(|_| "/bin/sh".to_string());
            CommandBuilder::new(shell)
        }
    }

    /// Abre una nueva sesión nativa de terminal e inicia la retransmisión hacia Tauri.
    pub fn spawn(
        app: AppHandle,
        session_id: String,
        rows: u16,
        cols: u16,
    ) -> Result<PtySession, String> {
        let pty_system = NativePtySystem::default();
        let pair = pty_system
            .openpty(PtySize {
                rows,
                cols,
                pixel_width: 0,
                pixel_height: 0,
            })
            .map_err(|e| format!("Error abriendo ConPTY nativo: {}", e))?;

        let cmd = Self::default_shell_command();
        let child = pair
            .slave
            .spawn_command(cmd)
            .map_err(|e| format!("Error ejecutando subproceso de shell: {}", e))?;

        let mut reader = pair
            .master
            .try_clone_reader()
            .map_err(|e| format!("Error clonando lector PTY: {}", e))?;
        let writer = pair
            .master
            .take_writer()
            .map_err(|e| format!("Error obteniendo escritor PTY: {}", e))?;

        let sid = session_id.clone();
        let app_clone = app.clone();

        // Hilo lector dedicado para transmitir la salida ANSI al frontend
        std::thread::Builder::new()
            .name(format!("pty-reader-{}", session_id))
            .spawn(move || {
                let mut buf = [0u8; 2048];
                while let Ok(n) = reader.read(&mut buf) {
                    if n == 0 {
                        break; // EOF: El proceso hijo cerró el descriptor
                    }
                    let text = String::from_utf8_lossy(&buf[..n]).to_string();
                    let _ = app_clone.emit("pty-output", PtyOutputPayload {
                        session_id: sid.clone(),
                        data: text,
                    });
                }
                let _ = app_clone.emit("pty-exit", PtyExitPayload {
                    session_id: sid,
                });
            })
            .map_err(|e| format!("Error lanzando hilo de lectura PTY: {}", e))?;

        Ok(PtySession::new(session_id, pair.master, writer, child))
    }
}
