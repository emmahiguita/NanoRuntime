//! Definiciones de herramientas declarativas (JSON → Rust).

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

/// Definición completa de una herramienta cargada desde JSON.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolDefinition {
    /// Nombre único de la herramienta.
    pub name: String,

    /// Descripción para el prompt del sistema.
    pub description: String,

    /// Parámetros que acepta la herramienta.
    #[serde(default)]
    pub parameters: HashMap<String, ToolParameter>,

    /// Configuración de ejecución (HTTP, script, etc.).
    pub execution: ExecutionConfig,
}

/// Parámetro de una herramienta.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolParameter {
    /// Tipo del parámetro: string, number, boolean, etc.
    #[serde(rename = "type")]
    pub param_type: String,

    /// Descripción del parámetro.
    #[serde(default)]
    pub description: String,

    /// Si el parámetro es obligatorio.
    #[serde(default)]
    pub required: bool,

    /// Valor por defecto (opcional).
    #[serde(default)]
    pub default: Option<serde_json::Value>,
}

/// Configuración de ejecución de una herramienta.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExecutionConfig {
    /// Tipo de ejecución: "http", "script", "function".
    #[serde(rename = "type")]
    pub exec_type: String,

    /// Método HTTP (si type = "http").
    #[serde(default)]
    pub method: String,

    /// URL del endpoint (si type = "http").
    #[serde(default)]
    pub url: String,

    /// Headers HTTP (si type = "http").
    #[serde(default)]
    pub headers: Option<HashMap<String, String>>,

    /// Template del body (si type = "http").
    #[serde(default)]
    pub body_template: Option<serde_json::Value>,

    /// Comando a ejecutar (si type = "script").
    #[serde(default)]
    pub command: Option<String>,
}

/// Configuración de herramientas (wrapper para serialización).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ToolConfig {
    /// Directorio donde buscar herramientas.
    pub directory: String,

    /// Si auto-descubrir al iniciar.
    #[serde(default)]
    pub auto_discover: bool,
}

impl ToolDefinition {
    /// Valida que los parámetros proporcionados cumplan con la definición.
    pub fn validate_parameters(
        &self,
        params: &serde_json::Value,
    ) -> Result<(), String> {
        if let serde_json::Value::Object(map) = params {
            // Check required parameters are present
            for (name, param) in &self.parameters {
                if param.required && !map.contains_key(name) {
                    return Err(format!(
                        "Missing required parameter '{}' for tool '{}'",
                        name, self.name
                    ));
                }
            }
            Ok(())
        } else {
            Err("Parameters must be a JSON object".to_string())
        }
    }
}
