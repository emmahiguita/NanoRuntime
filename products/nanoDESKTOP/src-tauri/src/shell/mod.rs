//! Módulo de Shell nativa y emulación PTY multiplataforma.

pub mod adapter;
pub mod manager;
pub mod native_pty;
pub mod session;

pub use adapter::ShellAdapter;
pub use manager::ShellManager;
pub use native_pty::NativePtyShell;
pub use session::PtySession;
