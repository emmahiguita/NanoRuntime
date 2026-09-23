//! ShellAdapter: Trait de abstracción de terminal (Interface Segregation & DIP).
//!
//! QUÉ HACE: Define el contrato abstracto para la ejecución de consolas interactivas.
//! CÓMO FUNCIONA: Desacopla la interfaz de los detalles de implementación de PTY
//! (ConPTY en Windows, termios en Linux/macOS o implementaciones virtuales/mock).
//! POR QUÉ: Permite extensibilidad según SOLID y pruebas sin acoplarse al SO.

use async_trait::async_trait;

#[async_trait]
pub trait ShellAdapter: Send + Sync {
    /// Abre una nueva sesión de terminal con el tamaño inicial dado (filas y columnas).
    async fn open(
        &self,
        session_id: &str,
        rows: u16,
        cols: u16,
    ) -> Result<(), String>;

    /// Escribe bytes/caracteres en el stdin de la shell activa.
    async fn write(&self, session_id: &str, data: &[u8]) -> Result<(), String>;

    /// Ajusta las dimensiones de la ventana de la terminal (PTY resize).
    async fn resize(&self, session_id: &str, rows: u16, cols: u16) -> Result<(), String>;

    /// Cierra y termina la sesión liberando los recursos del proceso hijo.
    async fn close(&self, session_id: &str) -> Result<(), String>;
}
