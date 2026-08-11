//! Platform-specific utilities for Linux/Windows compatibility.

use std::path::PathBuf;

/// Get the default session directory based on the platform.
/// 
/// On Linux: ~/.nano-sessions
/// On Windows: .nano-sessions (current directory)
pub fn get_default_session_dir() -> PathBuf {
    #[cfg(target_os = "linux")]
    {
        if let Some(home) = dirs::home_dir() {
            return home.join(".nano-sessions");
        }
    }
    
    // Fallback for Windows or if home dir not found
    PathBuf::from(".nano-sessions")
}

/// Get the default history file path based on platform.
/// 
/// On Linux: ~/.nano-sessions/history.json
/// On Windows: data/history.json
#[allow(dead_code)]
pub fn get_history_path() -> PathBuf {
    #[cfg(target_os = "linux")]
    {
        if let Some(home) = dirs::home_dir() {
            return home.join(".nano-sessions").join("history.json");
        }
    }
    
    // Fallback for Windows or if home dir not found
    PathBuf::from("data/history.json")
}

/// Get the default cache directory.
/// 
/// On Linux: ~/.cache/nano-ai
/// On Windows: .nano-cache
#[allow(dead_code)]
pub fn get_cache_dir() -> PathBuf {
    #[cfg(target_os = "linux")]
    {
        if let Some(cache) = dirs::cache_dir() {
            return cache.join("nano-ai");
        }
    }
    
    // Fallback
    PathBuf::from(".nano-cache")
}

/// Get the default config directory.
/// 
/// On Linux: ~/.config/nano-ai
/// On Windows: .
#[allow(dead_code)]
pub fn get_config_dir() -> PathBuf {
    #[cfg(target_os = "linux")]
    {
        if let Some(config) = dirs::config_dir() {
            return config.join("nano-ai");
        }
    }
    
    // Fallback
    PathBuf::from(".")
}

/// Ensure a directory exists, creating it if necessary.
pub fn ensure_dir(path: &PathBuf) -> anyhow::Result<()> {
    if !path.exists() {
        std::fs::create_dir_all(path)?;
        #[cfg(target_os = "linux")]
        {
            // On Linux, set restrictive permissions (owner only)
            use std::os::unix::fs::PermissionsExt;
            let perms = std::fs::Permissions::from_mode(0o700);
            std::fs::set_permissions(path, perms)?;
        }
    }
    Ok(())
}

/// Detect if running in desktop environment on Linux.
#[allow(dead_code)]
pub fn is_desktop_environment() -> bool {
    #[cfg(target_os = "linux")]
    {
        std::env::var("DISPLAY").is_ok() || std::env::var("WAYLAND_DISPLAY").is_ok()
    }
    
    #[cfg(not(target_os = "linux"))]
    {
        true // Assume desktop on Windows
    }
}

/// Get default bind address for server.
/// 
/// On Linux in headless mode: 0.0.0.0 (accessible from network)
/// Otherwise: 127.0.0.1 (localhost only)
pub fn get_default_bind_address() -> &'static str {
    #[cfg(target_os = "linux")]
    {
        if !is_desktop_environment() {
            // Headless Linux (server)
            return "0.0.0.0";
        }
    }
    
    // Desktop or Windows
    "127.0.0.1"
}

/// Validate port number.
pub fn validate_port(port: u16) -> anyhow::Result<()> {
    if port < 1024 {
        tracing::warn!("Port {} is below 1024 - may require elevated privileges", port);
    }
    // port > 65535 is impossible for u16, so no need to check
    Ok(())
}

/// Validate temperature parameter.
pub fn validate_temperature(temp: f32) -> anyhow::Result<()> {
    if temp < 0.0 {
        return Err(anyhow::anyhow!("Temperature must be >= 0.0, got {}", temp));
    }
    if temp > 2.0 {
        return Err(anyhow::anyhow!("Temperature should be <= 2.0, got {}", temp));
    }
    Ok(())
}

/// Enable high-performance settings on Linux if running as root.
#[cfg(target_os = "linux")]
#[allow(dead_code)]
pub fn optimize_system_if_root() -> bool {
    unsafe { libc::geteuid() == 0 }
}

#[cfg(not(target_os = "linux"))]
#[allow(dead_code)]
pub fn optimize_system_if_root() -> bool {
    false
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_temperature() {
        assert!(validate_temperature(0.0).is_ok());
        assert!(validate_temperature(1.0).is_ok());
        assert!(validate_temperature(2.0).is_ok());
        assert!(validate_temperature(-0.1).is_err());
        assert!(validate_temperature(2.1).is_err());
    }

    #[test]
    fn test_validate_port() {
        assert!(validate_port(8080).is_ok());
        assert!(validate_port(65535).is_ok());
        // validate_port takes u16 — out-of-range values are caught at compile time
    }

    #[test]
    fn test_get_paths() {
        let session_dir = get_default_session_dir();
        assert!(!session_dir.as_os_str().is_empty());
    }
}
