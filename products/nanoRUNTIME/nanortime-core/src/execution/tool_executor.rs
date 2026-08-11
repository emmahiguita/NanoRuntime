//! Ejecutor de herramientas declarativas.
//!
//! Carga definiciones de herramientas desde archivos JSON,
//! las registra, y las ejecuta cuando el modelo lo solicita.
//! Soporta ejecución HTTP y scripts de sistema.

use std::collections::HashMap;
use std::fs;
use std::path::Path;
use std::sync::LazyLock;

use regex::Regex;
use tokio::sync::RwLock;

use crate::config::manifest::Config;
use crate::config::tools::{ToolConfig, ToolDefinition};
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
            http_client: reqwest::Client::builder()
                .timeout(std::time::Duration::from_secs(30))
                .build()
                .expect("Failed to build HTTP client"),
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
        let tool: ToolDefinition =
            serde_json::from_str(json).map_err(|e| NanoError::InvalidToolDefinition {
                reason: format!("Failed to parse tool JSON: {}", e),
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

            if path.extension().is_some_and(|ext| ext == "json") {
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
        tool.validate_parameters(&parameters)
            .map_err(|e| NanoError::InvalidToolDefinition { reason: e })?;

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
    ///
    /// Security: validates the resolved URL does not point to private or
    /// loopback addresses (RFC 1918, localhost, link-local, and IPv6
    /// equivalents). This prevents SSRF attacks where a tool definition
    /// could be crafted to scan internal networks or hit local services.
    async fn execute_http(
        &self,
        tool: &ToolDefinition,
        params: &serde_json::Value,
    ) -> Result<serde_json::Value> {
        let exec = &tool.execution;

        let method = exec.method.to_uppercase();
        let url = self.interpolate_template(&exec.url, params);

        // SSRF guard: reject URLs targeting private/internal networks
        if let Err(reason) = Self::validate_url_safe(&url) {
            return Err(NanoError::ToolExecutionFailed {
                tool_name: tool.name.clone(),
                source: Box::new(std::io::Error::new(
                    std::io::ErrorKind::PermissionDenied,
                    format!("URL rejected by SSRF guard: {} — {}", url, reason),
                )),
            });
        }

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

        if !status.is_success() {
            return Err(NanoError::ToolExecutionFailed {
                tool_name: tool.name.clone(),
                source: Box::new(std::io::Error::other(format!(
                    "HTTP {}: {}",
                    status.as_u16(),
                    body
                ))),
            });
        }

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

        // Validate tool command against allowlist before execution.
        // Shell execution of parameter-interpolated strings from user-defined
        // tool JSON is inherently dangerous. Only registered, explicitly
        // trusted tool commands are permitted.
        if !Self::is_command_allowed(&resolved_cmd) {
            return Err(NanoError::ToolExecutionFailed {
                tool_name: tool.name.clone(),
                source: Box::new(std::io::Error::new(
                    std::io::ErrorKind::PermissionDenied,
                    format!(
                        "Command '{}' is not in the allowed tool list. \
                         Add it to ALLOWED_TOOL_COMMANDS or use a sandboxed executor.",
                        &resolved_cmd[..resolved_cmd.len().min(80)]
                    ),
                )),
            });
        }

        // Execute command directly via the OS process API — NOT through
        // a shell interpreter (sh -c / cmd /C). Direct execution prevents
        // shell metacharacter injection (;, |, $(), backticks, etc.) that
        // could bypass the allowlist validation above. The command is
        // split into program + args using shell-aware tokenization that
        // respects single and double quotes.
        let output = tokio::time::timeout(
            std::time::Duration::from_secs(30),
            tokio::task::spawn_blocking(move || {
                let (program, args) = shell_split_args(&resolved_cmd);
                std::process::Command::new(&program).args(&args).output()
            }),
        )
        .await
        .map_err(|_| NanoError::ToolExecutionFailed {
            tool_name: tool.name.clone(),
            source: Box::new(std::io::Error::new(
                std::io::ErrorKind::TimedOut,
                "Script execution timed out after 30s",
            )),
        })?
        .map_err(|e| NanoError::ToolExecutionFailed {
            tool_name: tool.name.clone(),
            source: Box::new(std::io::Error::other(format!(
                "Script thread panicked: {:?}",
                e
            ))),
        })?
        .map_err(|e| NanoError::ToolExecutionFailed {
            tool_name: tool.name.clone(),
            source: Box::new(e),
        })?;

        let stdout = String::from_utf8_lossy(&output.stdout).to_string();
        let stderr = String::from_utf8_lossy(&output.stderr).to_string();
        Ok(serde_json::json!({
            "exit_code": output.status.code().unwrap_or(-1),
            "stdout": stdout,
            "stderr": stderr,
        }))
    }

    /// Ejecuta una herramienta usando el protocolo MCP (Model Context Protocol).
    ///
    /// Security: applies the same `is_command_allowed` validation as
    /// `execute_script` before spawning any subprocess. This prevents
    /// MCP tool definitions from bypassing the allowlist.
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

        // Validate against allowlist — MCP tools run via shell just like scripts,
        // and must pass the same three-layer validation (binary match, no inline
        // flags, no shell metacharacters).
        if !Self::is_command_allowed(&resolved_cmd) {
            return Err(NanoError::ToolExecutionFailed {
                tool_name: tool.name.clone(),
                source: Box::new(std::io::Error::new(
                    std::io::ErrorKind::PermissionDenied,
                    format!(
                        "MCP command '{}' rejected: not in allowlist or contains shell metacharacters. \
                         Add to ALLOWED_TOOL_COMMANDS in tool_executor.rs.",
                        &resolved_cmd[..resolved_cmd.len().min(80)]
                    ),
                )),
            });
        }

        use std::process::Stdio;
        use tokio::io::BufReader;
        let mcp_timeout = std::time::Duration::from_secs(30);

        // Execute via direct process spawn (not shell) on all platforms.
        // Uses shell_split_args for safe tokenization — same as execute_script.
        let (program, args) = shell_split_args(&resolved_cmd);
        let mut cmd_builder = tokio::process::Command::new(&program);
        cmd_builder.args(&args);

        let mut child = cmd_builder
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .map_err(|e| NanoError::ToolExecutionFailed {
                tool_name: tool.name.clone(),
                source: Box::new(e),
            })?;

        let mut stdin = match child.stdin.take() {
            Some(stdin) => stdin,
            None => {
                let _ = child.kill().await;
                return Err(tool_execution_failed(
                    &tool.name,
                    std::io::Error::new(std::io::ErrorKind::BrokenPipe, "Failed to capture stdin"),
                ));
            }
        };
        let stdout = match child.stdout.take() {
            Some(stdout) => stdout,
            None => {
                let _ = child.kill().await;
                return Err(tool_execution_failed(
                    &tool.name,
                    std::io::Error::new(std::io::ErrorKind::BrokenPipe, "Failed to capture stdout"),
                ));
            }
        };
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
        if let Err(e) = write_mcp_json_line(&mut stdin, &init_req, mcp_timeout).await {
            let _ = child.kill().await;
            return Err(tool_execution_failed(&tool.name, e));
        }

        // Wait for initialize response
        if let Err(e) = read_mcp_json_line(&mut reader, mcp_timeout).await {
            let _ = child.kill().await;
            return Err(tool_execution_failed(&tool.name, e));
        };

        // 2. Initialized notification
        let initialized_notif = serde_json::json!({
            "jsonrpc": "2.0",
            "method": "notifications/initialized",
            "params": {}
        });
        if let Err(e) = write_mcp_json_line(&mut stdin, &initialized_notif, mcp_timeout).await {
            let _ = child.kill().await;
            return Err(tool_execution_failed(&tool.name, e));
        }

        // 3. Call tool
        let mcp_tool_name = if !exec.url.is_empty() {
            &exec.url
        } else {
            &tool.name
        };

        let call_req = serde_json::json!({
            "jsonrpc": "2.0",
            "id": 2,
            "method": "tools/call",
            "params": {
                "name": mcp_tool_name,
                "arguments": params
            }
        });
        if let Err(e) = write_mcp_json_line(&mut stdin, &call_req, mcp_timeout).await {
            let _ = child.kill().await;
            return Err(tool_execution_failed(&tool.name, e));
        }

        // Wait for call response
        let line = match read_mcp_json_line(&mut reader, mcp_timeout).await {
            Ok(line) => line,
            Err(e) => {
                let _ = child.kill().await;
                return Err(tool_execution_failed(&tool.name, e));
            }
        };

        let _ = child.kill().await;

        match serde_json::from_str::<serde_json::Value>(&line) {
            Ok(v) => Ok(v),
            Err(e) => Err(tool_execution_failed(&tool.name, e)),
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

        // Replace environment variable placeholders (compiled once, used many times)
        static ENV_RE: LazyLock<Regex> =
            LazyLock::new(|| Regex::new(r"\{\{env\.([A-Za-z_][A-Za-z0-9_]*)\}\}").unwrap());
        for cap in ENV_RE.captures_iter(template) {
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

    /// Validates that a URL does not target private, loopback, or link-local
    /// addresses. Returns Ok(()) if the URL is safe, Err(reason) otherwise.
    ///
    /// Blocks: 127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16,
    /// 169.254.0.0/16, 0.0.0.0/8, and IPv6 equivalents (::1, fe80::/10).
    /// Also blocks hostnames like "localhost".
    ///
    /// This is a best-effort SSRF guard. For production, use a dedicated
    /// HTTP proxy with egress filtering.
    fn validate_url_safe(url_str: &str) -> std::result::Result<(), String> {
        // Extract host from URL without external crate dependency.
        // Handles: http://host/path, https://host:port/path, host:port
        let remaining = url_str
            .trim_start_matches("http://")
            .trim_start_matches("https://");
        let host_port = match remaining.split('/').next() {
            Some(h) => h,
            None => return Err("URL has no host component".to_string()),
        };
        let host = match host_port.split(':').next() {
            Some(h) => h.to_lowercase(),
            None => return Err("URL has no host component".to_string()),
        };

        // Block common loopback hostnames
        if host == "localhost" || host == "127.0.0.1" || host == "::1" {
            return Err("loopback address blocked".to_string());
        }

        // Block IPv4 private ranges
        if let Ok(ip) = host.parse::<std::net::Ipv4Addr>() {
            let octets = ip.octets();
            if octets[0] == 10 {
                return Err("private range 10.0.0.0/8 blocked".to_string());
            }
            if octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31 {
                return Err("private range 172.16.0.0/12 blocked".to_string());
            }
            if octets[0] == 192 && octets[1] == 168 {
                return Err("private range 192.168.0.0/16 blocked".to_string());
            }
            if octets[0] == 169 && octets[1] == 254 {
                return Err("link-local 169.254.0.0/16 blocked".to_string());
            }
            if octets[0] == 0 || octets[0] == 127 {
                return Err("reserved IP range blocked".to_string());
            }
        }

        // Block IPv6 loopback and link-local
        if let Ok(ip) = host.parse::<std::net::Ipv6Addr>() {
            if ip.is_loopback() {
                return Err("IPv6 loopback blocked".to_string());
            }
            let segments = ip.segments();
            if segments[0] & 0xffc0 == 0xfe80 {
                return Err("IPv6 link-local blocked".to_string());
            }
        }

        Ok(())
    }

    /// Commands allowlisted for script-type tool execution.
    /// Only exact binary-name matching against the first token of the command.
    /// `curl` and `wget` are deliberately excluded — they enable SSRF and
    /// data exfiltration via `sh -c`. Use HTTP/MCP tool types instead.
    const ALLOWED_TOOL_COMMANDS: &[&str] = &["python", "python3", "node"];

    /// Flags that allow inline code execution and are rejected even for
    /// allowlisted runtimes.
    const FORBIDDEN_INLINE_FLAGS: &[&str] = &["-c", "-e", "--eval", "-p", "--print"];

    /// Shell metacharacters that enable command chaining, piping, or redirection.
    /// Blocked in ALL script-type tools regardless of binary.
    const FORBIDDEN_SHELL_CHARS: &[char] = &['|', ';', '&', '`', '$', '>', '<'];

    /// Checks whether a resolved command is safe to execute via `sh -c`.
    ///
    /// Performs three layers of validation:
    /// 1. Exact binary-name match (not prefix — prevents `python3malicious`).
    /// 2. No inline-code flags for scripting runtimes (prevents
    ///    `python -c "import os; os.system(...)"`).
    /// 3. No shell metacharacters (`|`, `;`, `&`, `` ` ``, `$`, `>`, `<`)
    ///    to prevent command chaining like `curl http://x | sh`.
    fn is_command_allowed(resolved_cmd: &str) -> bool {
        let trimmed = resolved_cmd.trim();
        if trimmed.is_empty() {
            return false;
        }

        // Layer 1: Exact binary-name match
        let cmd_name = match trimmed.split_whitespace().next() {
            Some(name) => name,
            None => return false,
        };

        if !Self::ALLOWED_TOOL_COMMANDS.contains(&cmd_name) {
            return false;
        }

        // Layer 2: Block inline-code flags for scripting runtimes
        let remaining = trimmed[cmd_name.len()..].trim();
        let args: Vec<&str> = remaining.split_whitespace().collect();
        if args
            .iter()
            .any(|arg| Self::FORBIDDEN_INLINE_FLAGS.contains(arg))
        {
            return false;
        }

        // Layer 3: Block shell metacharacters that enable command chaining
        if trimmed.contains(Self::FORBIDDEN_SHELL_CHARS) {
            tracing::warn!(
                "Tool command rejected: contains shell metacharacters — '{}'",
                trimmed
            );
            return false;
        }

        true
    }
}

fn tool_execution_failed(
    tool_name: &str,
    source: impl std::error::Error + Send + Sync + 'static,
) -> NanoError {
    NanoError::ToolExecutionFailed {
        tool_name: tool_name.to_string(),
        source: Box::new(source),
    }
}

async fn write_mcp_json_line<W>(
    writer: &mut W,
    value: &serde_json::Value,
    op_timeout: std::time::Duration,
) -> std::io::Result<()>
where
    W: tokio::io::AsyncWrite + Unpin,
{
    use tokio::io::AsyncWriteExt;

    let line = format!("{}\n", value);
    tokio::time::timeout(op_timeout, writer.write_all(line.as_bytes()))
        .await
        .map_err(|_| std::io::Error::new(std::io::ErrorKind::TimedOut, "MCP write timed out"))??;
    Ok(())
}

async fn read_mcp_json_line<R>(
    reader: &mut R,
    op_timeout: std::time::Duration,
) -> std::io::Result<String>
where
    R: tokio::io::AsyncBufRead + Unpin,
{
    use tokio::io::AsyncBufReadExt;

    let mut line = String::new();
    let bytes_read = tokio::time::timeout(op_timeout, reader.read_line(&mut line))
        .await
        .map_err(|_| {
            std::io::Error::new(
                std::io::ErrorKind::TimedOut,
                "MCP read timed out waiting for JSON-RPC line",
            )
        })??;

    if bytes_read == 0 {
        return Err(std::io::Error::new(
            std::io::ErrorKind::UnexpectedEof,
            "MCP subprocess closed stdout before responding",
        ));
    }

    Ok(line)
}

/// Split a command string into (program, args) using shell-aware tokenization.
///
/// Handles single-quoted and double-quoted arguments so that commands like
/// `python "my script.py" --flag value` are parsed correctly. This enables
/// direct process execution without a shell interpreter, eliminating shell
/// metacharacter injection risks (;, |, $(), backticks, etc.).
///
/// On parse failure (unterminated quote), falls back to whitespace split
/// so execution can still proceed with a best-effort argument list.
fn shell_split_args(cmd: &str) -> (String, Vec<String>) {
    let mut args: Vec<String> = Vec::new();
    let mut current = String::new();
    let mut in_single = false;
    let mut in_double = false;
    let chars: Vec<char> = cmd.chars().collect();
    let mut i = 0;

    while i < chars.len() {
        let ch = chars[i];
        match ch {
            '\'' if !in_double => {
                in_single = !in_single;
            }
            '"' if !in_single => {
                in_double = !in_double;
            }
            c if c.is_whitespace() && !in_single && !in_double => {
                if !current.is_empty() {
                    args.push(std::mem::take(&mut current));
                }
            }
            _ => {
                current.push(ch);
            }
        }
        i += 1;
    }
    if !current.is_empty() {
        args.push(current);
    }

    if args.is_empty() {
        return (String::new(), vec![]);
    }

    let program = args.remove(0);
    (program, args)
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
        executor
            .register_from_json(&test_tool_json())
            .await
            .unwrap();

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
