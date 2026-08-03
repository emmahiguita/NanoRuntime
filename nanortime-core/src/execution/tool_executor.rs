//! Ejecutor de herramientas declarativas.
//!
//! Carga definiciones de herramientas desde archivos JSON,
//! las registra, y las ejecuta cuando el modelo lo solicita.
//! Soporta ejecución HTTP y scripts de sistema.

use std::collections::HashMap;
use std::fs;
use std::path::Path;

use tokio::sync::RwLock;

use crate::config::manifest::Config;
use crate::config::tools::{ToolDefinition, ToolConfig};
use crate::error::{NanoError, Result};

/// Resultado de ejecutar una herramienta.
#[derive(Debug, Clone)]
pub struct ToolResult {
    /// Si la ejecución fue exitosa.
    pub success: bool,
    /// Datos del resultado.
    pub data: serde_json::Value,
    /// Mensaje de error si falló.
    pub error: Option<String>,
    /// Tiempo de ejecución en milisegundos.
    pub duration_ms: u64,
}

/// Ejecutor de herramientas.
///
/// Mantiene un registro de herramientas cargadas desde JSON
/// y las ejecuta bajo demanda. Soporta:
/// - Ejecución HTTP (REST APIs)
/// - Ejecución de scripts (shell commands)
pub struct ToolExecutor {
    /// Herramientas registradas, indexadas por nombre.
    tools: RwLock<HashMap<String, ToolDefinition>>,
    /// Cliente HTTP para herramientas de tipo "http".
    http_client: reqwest::Client,
    /// Configuración de herramientas.
    #[allow(dead_code)]
    config: ToolConfig,
}

impl ToolExecutor {
    /// Crea un nuevo ejecutor de herramientas.
    pub async fn new(config: &Config) -> Result<Self> {
        Ok(Self {
            tools: RwLock::new(HashMap::new()),
            http_client: reqwest::Client::new(),
            config: ToolConfig {
                directory: config.tools.directory.clone(),
                auto_discover: config.tools.auto_discover,
            },
        })
    }

    /// Registra una herramienta desde su definición JSON.
    ///
    /// El JSON debe seguir el formato:
    /// ```json
    /// {
    ///   "name": "tool_name",
    ///   "description": "...",
    ///   "parameters": { ... },
    ///   "execution": { "type": "http", ... }
    /// }
    /// ```
    pub async fn register_from_json(&self, json: &str) -> Result<()> {
        let tool: ToolDefinition = serde_json::from_str(json).map_err(|e| {
            NanoError::InvalidToolDefinition {
                reason: format!("Failed to parse tool JSON: {}", e),
            }
        })?;

        self.register_tool(tool).await
    }

    /// Registra una herramienta desde su definición estructurada.
    pub async fn register_tool(&self, tool: ToolDefinition) -> Result<()> {
        let name = tool.name.clone();
        let mut tools = self.tools.write().await;

        if tools.contains_key(&name) {
            tracing::warn!("Tool '{}' already registered, overwriting", name);
        }

        tracing::info!("Registered tool: {} ({})", name, tool.description);
        tools.insert(name, tool);
        Ok(())
    }

    /// Descubre y registra herramientas desde un directorio.
    ///
    /// Busca archivos `.json` en el directorio especificado y los carga
    /// como definiciones de herramientas.
    pub async fn discover_tools(&self, directory: &str) -> Result<usize> {
        let dir = Path::new(directory);
        if !dir.exists() {
            tracing::warn!("Tools directory does not exist: {}", directory);
            return Ok(0);
        }

        let mut count = 0;
        let entries = fs::read_dir(dir)?;

        for entry in entries {
            let entry = entry?;
            let path = entry.path();

            if path.extension().map_or(false, |ext| ext == "json") {
                match fs::read_to_string(&path) {
                    Ok(content) => match self.register_from_json(&content).await {
                        Ok(()) => count += 1,
                        Err(e) => {
                            tracing::warn!(
                                "Failed to register tool from {}: {}",
                                path.display(),
                                e
                            );
                        }
                    },
                    Err(e) => {
                        tracing::warn!("Failed to read tool file {}: {}", path.display(), e);
                    }
                }
            }
        }

        tracing::info!("Discovered {} tools from {}", count, directory);
        Ok(count)
    }

    /// Ejecuta una herramienta por nombre con los parámetros dados.
    pub async fn execute(
        &self,
        tool_name: &str,
        parameters: serde_json::Value,
    ) -> Result<ToolResult> {
        let start = std::time::Instant::now();

        let tools = self.tools.read().await;
        let tool = tools
            .get(tool_name)
            .ok_or_else(|| NanoError::ToolNotFound {
                name: tool_name.to_string(),
            })?;

        // Validate parameters
        tool.validate_parameters(&parameters).map_err(|e| {
            NanoError::InvalidToolDefinition { reason: e }
        })?;

        // Execute based on type
        let result = match tool.execution.exec_type.as_str() {
            "http" => self.execute_http(tool, &parameters).await,
            "script" => self.execute_script(tool, &parameters).await,
            "mcp" => self.execute_mcp(tool, &parameters).await,
            _ => Err(NanoError::InvalidToolDefinition {
                reason: format!(
                    "Unknown execution type '{}' for tool '{}'",
                    tool.execution.exec_type, tool_name
                ),
            }),
        };

        let duration_ms = start.elapsed().as_millis() as u64;

        match result {
            Ok(data) => Ok(ToolResult {
                success: true,
                data,
                error: None,
                duration_ms,
            }),
            Err(e) => Ok(ToolResult {
                success: false,
                data: serde_json::Value::Null,
                error: Some(e.to_string()),
                duration_ms,
            }),
        }
    }

    /// Ejecuta una herramienta de tipo HTTP.
    async fn execute_http(
        &self,
        tool: &ToolDefinition,
        params: &serde_json::Value,
    ) -> Result<serde_json::Value> {
        let exec = &tool.execution;

        let method = exec.method.to_uppercase();
        let url = self.interpolate_template(&exec.url, params);

        let mut request = match method.as_str() {
            "GET" => self.http_client.get(&url),
            "POST" => self.http_client.post(&url),
            "PUT" => self.http_client.put(&url),
            "DELETE" => self.http_client.delete(&url),
            "PATCH" => self.http_client.patch(&url),
            _ => {
                return Err(NanoError::InvalidToolDefinition {
                    reason: format!("Unsupported HTTP method: {}", method),
                });
            }
        };

        // Add headers
        if let Some(ref headers) = exec.headers {
            for (key, value) in headers {
                let resolved = self.interpolate_template(value, params);
                request = request.header(key, resolved);
            }
        }

        // Add body for POST/PUT/PATCH
        if let Some(ref body_template) = exec.body_template {
            if matches!(method.as_str(), "POST" | "PUT" | "PATCH") {
                let body = self.interpolate_json(body_template, params);
                request = request.json(&body);
            }
        }

        // Execute request
        let response = request.send().await.map_err(|e| NanoError::HttpError {
            reason: format!("HTTP request failed: {}", e),
            source: e,
        })?;

        let status = response.status();
        let body: serde_json::Value = response.json().await.unwrap_or(serde_json::Value::Null);

        Ok(serde_json::json!({
            "status": status.as_u16(),
            "body": body,
        }))
    }

    /// Ejecuta una herramienta de tipo script.
    async fn execute_script(
        &self,
        tool: &ToolDefinition,
        params: &serde_json::Value,
    ) -> Result<serde_json::Value> {
        let exec = &tool.execution;
        let command = exec
            .command
            .as_ref()
            .ok_or_else(|| NanoError::InvalidToolDefinition {
                reason: "Script tool missing 'command' field".to_string(),
            })?;

        let resolved_cmd = self.interpolate_template(command, params);

        // Execute shell command
        // NOTE: In production, this should use a sandbox or restricted environment
        let output = if cfg!(target_os = "windows") {
            std::process::Command::new("cmd")
                .args(["/C", &resolved_cmd])
                .output()
        } else {
            std::process::Command::new("sh")
                .args(["-c", &resolved_cmd])
                .output()
        };

        match output {
            Ok(out) => {
                let stdout = String::from_utf8_lossy(&out.stdout).to_string();
                let stderr = String::from_utf8_lossy(&out.stderr).to_string();
                Ok(serde_json::json!({
                    "exit_code": out.status.code().unwrap_or(-1),
                    "stdout": stdout,
                    "stderr": stderr,
                }))
            }
            Err(e) => Err(NanoError::ToolExecutionFailed {
                tool_name: tool.name.clone(),
                source: Box::new(e),
            }),
        }
    }

    /// Ejecuta una herramienta usando el protocolo MCP (Model Context Protocol).
    async fn execute_mcp(
        &self,
        tool: &ToolDefinition,
        params: &serde_json::Value,
    ) -> Result<serde_json::Value> {
        let exec = &tool.execution;
        let command = exec
            .command
            .as_ref()
            .ok_or_else(|| NanoError::InvalidToolDefinition {
                reason: "MCP tool missing 'command' field (e.g., 'npx -y @modelcontextprotocol/server-postgres')".to_string(),
            })?;

        let resolved_cmd = self.interpolate_template(command, params);

        use tokio::io::{AsyncWriteExt, AsyncBufReadExt, BufReader};
        use std::process::Stdio;

        // Si es windows podemos usar cmd /c
        let mut cmd_builder = if cfg!(target_os = "windows") {
            let mut c = tokio::process::Command::new("cmd");
            c.args(&["/c", &resolved_cmd]);
            c
        } else {
            let mut c = tokio::process::Command::new("sh");
            c.args(&["-c", &resolved_cmd]);
            c
        };

        let mut child = cmd_builder
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .map_err(|e| NanoError::ToolExecutionFailed {
                tool_name: tool.name.clone(),
                source: Box::new(e),
            })?;

        let mut stdin = child.stdin.take().unwrap();
        let stdout = child.stdout.take().unwrap();
        let mut reader = BufReader::new(stdout);

        // 1. Initialize
        let init_req = serde_json::json!({
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {
                    "name": "nanoai",
                    "version": "1.0.0"
                }
            }
        });
        if let Err(e) = stdin.write_all(format!("{}\n", init_req.to_string()).as_bytes()).await {
            let _ = child.kill().await;
            return Err(NanoError::ToolExecutionFailed { tool_name: tool.name.clone(), source: Box::new(e) });
        }

        // Wait for initialize response
        let mut line = String::new();
        if let Err(e) = reader.read_line(&mut line).await {
            let _ = child.kill().await;
            return Err(NanoError::ToolExecutionFailed { tool_name: tool.name.clone(), source: Box::new(e) });
        }

        // 2. Initialized notification
        let initialized_notif = serde_json::json!({
            "jsonrpc": "2.0",
            "method": "notifications/initialized",
            "params": {}
        });
        if let Err(e) = stdin.write_all(format!("{}\n", initialized_notif.to_string()).as_bytes()).await {
            let _ = child.kill().await;
            return Err(NanoError::ToolExecutionFailed { tool_name: tool.name.clone(), source: Box::new(e) });
        }

        // 3. Call tool
        let mcp_tool_name = if !exec.url.is_empty() { &exec.url } else { &tool.name };
        
        let call_req = serde_json::json!({
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": mcp_tool_name,
                "arguments": params
            }
        });
        if let Err(e) = stdin.write_all(format!("{}\n", call_req.to_string()).as_bytes()).await {
            let _ = child.kill().await;
            return Err(NanoError::ToolExecutionFailed { tool_name: tool.name.clone(), source: Box::new(e) });
        }

        // Wait for call response
        line.clear();
        if let Err(e) = reader.read_line(&mut line).await {
            let _ = child.kill().await;
            return Err(NanoError::ToolExecutionFailed { tool_name: tool.name.clone(), source: Box::new(e) });
        }

        let _ = child.kill().await;

        match serde_json::from_str::<serde_json::Value>(&line) {
            Ok(v) => Ok(v),
            Err(e) => Err(NanoError::ToolExecutionFailed {
                tool_name: tool.name.clone(),
                source: Box::new(e),
            }),
        }
    }

    /// Interpola placeholders `{{variable}}` en un string con valores de parámetros.
    pub fn interpolate_template(&self, template: &str, params: &serde_json::Value) -> String {
        let mut result = template.to_string();

        // Replace {{var_name}} with parameter values
        if let serde_json::Value::Object(map) = params {
            for (key, value) in map {
                let placeholder = format!("{{{{{}}}}}", key);
                let replacement = match value {
                    serde_json::Value::String(s) => s.clone(),
                    other => other.to_string(),
                };
                result = result.replace(&placeholder, &replacement);
            }
        }

        // Replace environment variable placeholders
        for cap in regex::Regex::new(r"\{\{env\.([A-Za-z_][A-Za-z0-9_]*)\}\}")
            .unwrap()
            .captures_iter(template)
        {
            let var_name = &cap[1];
            if let Ok(val) = std::env::var(var_name) {
                result = result.replace(&cap[0], &val);
            }
        }

        result
    }

    /// Interpola placeholders en un JSON template.
    fn interpolate_json(
        &self,
        template: &serde_json::Value,
        params: &serde_json::Value,
    ) -> serde_json::Value {
        match template {
            serde_json::Value::String(s) => {
                let resolved = self.interpolate_template(s, params);
                serde_json::Value::String(resolved)
            }
            serde_json::Value::Object(map) => {
                let mut new_map = serde_json::Map::new();
                for (key, value) in map {
                    new_map.insert(key.clone(), self.interpolate_json(value, params));
                }
                serde_json::Value::Object(new_map)
            }
            serde_json::Value::Array(arr) => {
                let new_arr: Vec<_> = arr
                    .iter()
                    .map(|v| self.interpolate_json(v, params))
                    .collect();
                serde_json::Value::Array(new_arr)
            }
            other => other.clone(),
        }
    }

    /// Construye el prompt del sistema con las definiciones de herramientas.
    pub async fn build_system_prompt(&self) -> String {
        let tools = self.tools.read().await;

        if tools.is_empty() {
            return String::new();
        }

        let mut prompt = String::from(
            "You have access to the following tools. \
             To use a tool, respond with a JSON object:\n\n",
        );

        for (name, tool) in tools.iter() {
            prompt.push_str(&format!("- {}: {}\n", name, tool.description));
            prompt.push_str("  Parameters:\n");
            for (param_name, param) in &tool.parameters {
                let required = if param.required { " (required)" } else { "" };
                prompt.push_str(&format!(
                    "    {}: {}{}\n",
                    param_name, param.param_type, required
                ));
            }
        }

        prompt.push_str("\nFormat: {\"tool\": \"tool_name\", \"parameters\": {...}}\n");
        prompt
    }

    /// Lista los nombres de todas las herramientas registradas.
    pub async fn list_tools(&self) -> Vec<String> {
        let tools = self.tools.read().await;
        tools.keys().cloned().collect()
    }

    /// Lista las definiciones completas de todas las herramientas registradas.
    pub async fn list_tool_definitions(&self) -> Vec<ToolDefinition> {
        let tools = self.tools.read().await;
        tools.values().cloned().collect()
    }

    /// Obtiene la definición de una herramienta específica.
    pub async fn get_tool(&self, name: &str) -> Option<ToolDefinition> {
        let tools = self.tools.read().await;
        tools.get(name).cloned()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_tool_json() -> String {
        r#"{
            "name": "get_weather",
            "description": "Get current weather for a city",
            "parameters": {
                "city": {
                    "type": "string",
                    "required": true
                },
                "unit": {
                    "type": "string",
                    "required": false,
                    "default": "celsius"
                }
            },
            "execution": {
                "type": "http",
                "method": "GET",
                "url": "https://api.weather.com/{{city}}?unit={{unit}}"
            }
        }"#
        .to_string()
    }

    #[tokio::test]
    async fn test_register_from_json() {
        let config = Config::test_config();
        let executor = ToolExecutor::new(&config).await.unwrap();
        let result = executor.register_from_json(&test_tool_json()).await;
        assert!(result.is_ok());
        assert_eq!(executor.list_tools().await.len(), 1);
    }

    #[tokio::test]
    async fn test_build_system_prompt() {
        let config = Config::test_config();
        let executor = ToolExecutor::new(&config).await.unwrap();
        executor.register_from_json(&test_tool_json()).await.unwrap();

        let prompt = executor.build_system_prompt().await;
        assert!(prompt.contains("get_weather"));
        assert!(prompt.contains("city"));
        assert!(prompt.contains("required"));
    }

    #[test]
    fn test_interpolate_template() {
        let config = Config::test_config();
        let rt = tokio::runtime::Runtime::new().unwrap();
        let executor = rt.block_on(async { ToolExecutor::new(&config).await.unwrap() });

        let template = "Weather for {{city}} in {{unit}}";
        let params = serde_json::json!({
            "city": "London",
            "unit": "celsius"
        });

        let result = executor.interpolate_template(template, &params);
        assert_eq!(result, "Weather for London in celsius");
    }

    #[tokio::test]
    async fn test_execute_nonexistent_tool() {
        let config = Config::test_config();
        let executor = ToolExecutor::new(&config).await.unwrap();
        let result = executor.execute("nonexistent", serde_json::json!({})).await;
        assert!(result.is_err());
    }
}
