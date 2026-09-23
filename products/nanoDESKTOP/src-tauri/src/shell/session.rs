//! PtySession: Encapsulación de proceso interactivo y canal PTY.
//!
//! QUÉ HACE: Administra el ciclo de vida del subproceso (PowerShell/CMD/Bash)
//! y los descriptores de lectura/escritura del pseudo-terminal.
//!
//! CÓMO FUNCIONA: Mantiene la referencia al MasterPty y al proceso hijo.
//! En su implementación de `Drop`, ejecuta `kill()` y `wait()` defensivos
//! para asegurar que el proceso secundario no se convierta en proceso zombie.
//!
//! POR QUÉ: Los procesos interactivos huérfanos consumen CPU/RAM y bloquean
//! puertos y recursos en el sistema operativo del usuario.

use std::io::Write;
use portable_pty::{Child, MasterPty, PtySize};

pub struct PtySession {
    pub session_id: String,
    master: Box<dyn MasterPty + Send>,
    writer: Box<dyn Write + Send>,
    child: Box<dyn Child + Send + Sync>,
}

impl PtySession {
    pub fn new(
        session_id: String,
        master: Box<dyn MasterPty + Send>,
        writer: Box<dyn Write + Send>,
        child: Box<dyn Child + Send + Sync>,
    ) -> Self {
        Self {
            session_id,
            master,
            writer,
            child,
        }
    }

    /// Envía datos (teclas/comandos) al stdin de la shell.
    pub fn write_bytes(&mut self, data: &[u8]) -> Result<(), String> {
        self.writer
            .write_all(data)
            .map_err(|e| format!("Error escribiendo en PTY stdin: {}", e))?;
        self.writer
            .flush()
            .map_err(|e| format!("Error vaciando buffer PTY: {}", e))?;
        Ok(())
    }

    /// Redimensiona la consola según filas y columnas de la UI.
    pub fn resize(&self, rows: u16, cols: u16) -> Result<(), String> {
        self.master
            .resize(PtySize {
                rows,
                cols,
                pixel_width: 0,
                pixel_height: 0,
            })
            .map_err(|e| format!("Error redimensionando PTY: {}", e))
    }

    /// Termina el proceso hijo de forma segura y espera su finalización.
    pub fn terminate(&mut self) {
        let _ = self.child.kill();
        let _ = self.child.wait();
    }
}

impl Drop for PtySession {
    /// Destructor defensivo contra procesos zombie:
    /// Si la sesión es descartada (por cierre de ventana o desconexión),
    /// el subproceso del sistema operativo es eliminado de inmediato.
    fn drop(&mut self) {
        self.terminate();
    }
}
