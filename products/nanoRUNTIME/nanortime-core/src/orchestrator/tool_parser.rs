//! Tool call parser: extrae JSON de tool calls incrustados en texto generado.
//!
//! Los LLMs pueden generar tool calls inline como:
//! - `{"tool": "get_weather", "parameters": {"city": "London"}}` (NanoAI)
//! - `{"name": "send_email", "arguments": {...}}` (OpenAI/Anthropic)
//!
//! Este módulo detecta, extrae y limpia estas construcciones del texto visible.

/// Elimina el JSON de tool call del texto visible.
///
/// El modelo puede generar algo como:
/// "Let me check the weather. {"tool": "get_weather", "parameters": {"city": "London"}}"
///
/// Esto devuelve solo: "Let me check the weather."
///
/// Soporta ambos formatos: NanoAI (tool/parameters) y OpenAI (name/arguments).
pub fn strip_tool_call_json(text: &str) -> String {
    let mut result = text.to_string();

    // Pattern 1: {"tool": "...", "parameters": {...}}
    if let Some(start) = result.find("\"tool\"") {
        if let Some(brace_start) = result[..start].rfind('{') {
            if let Some(end) = find_matching_brace(&result[brace_start..]) {
                let before = &result[..brace_start];
                let after = &result[brace_start + end..];
                result = format!("{}{}", before.trim_end(), after);
            }
        }
    }

    // Pattern 2: {"name": "...", "arguments": {...}} (OpenAI format)
    if let Some(start) = result.find("\"name\"") {
        if result.contains("\"arguments\"") {
            if let Some(brace_start) = result[..start].rfind('{') {
                if let Some(end) = find_matching_brace(&result[brace_start..]) {
                    let before = &result[..brace_start];
                    let after = &result[brace_start + end..];
                    result = format!("{}{}", before.trim_end(), after);
                }
            }
        }
    }

    result.trim().to_string()
}

/// Encuentra el brace de cierre correspondiente al brace de apertura.
pub fn find_matching_brace(s: &str) -> Option<usize> {
    let mut depth = 0;
    for (i, ch) in s.char_indices() {
        match ch {
            '{' => depth += 1,
            '}' => {
                depth -= 1;
                if depth == 0 {
                    return Some(i + 1);
                }
            }
            _ => {}
        }
    }
    None
}

/// Extrae un tool call JSON del texto generado.
///
/// Busca el primer patrón que coincida con:
///   `{"tool": "name", "parameters": {...}}` o
///   `{"name": "name", "arguments": {...}}`
/// y retorna (tool_name, parameters) si encuentra uno válido.
pub fn extract_tool_call_json(text: &str) -> Option<(String, serde_json::Value)> {
    // Pattern 1: {"tool": "...", "parameters": {...}}
    if let Some(result) = try_parse_tool_format(text) {
        return Some(result);
    }
    // Pattern 2: {"name": "...", "arguments": {...}} (OpenAI/Anthropic format)
    if let Some(result) = try_parse_function_format(text) {
        return Some(result);
    }
    None
}

/// Intenta parsear el formato {"tool": "...", "parameters": {...}}.
fn try_parse_tool_format(text: &str) -> Option<(String, serde_json::Value)> {
    let start = text.find("\"tool\"")?;

    // Find the enclosing braces
    let brace_start = text[..start].rfind('{')?;
    let after_tool = &text[start..];

    // Find matching closing brace
    let mut depth = 0;
    let mut end = 0;
    for (i, ch) in after_tool.char_indices() {
        if ch == '{' {
            depth += 1;
        } else if ch == '}' {
            depth -= 1;
        }
        if depth < 0 && ch == '}' {
            end = i + 1;
            break;
        }
    }
    if end == 0 {
        return None;
    }

    let json_str = &text[brace_start..start + end];
    let parsed: serde_json::Value = serde_json::from_str(json_str).ok()?;

    let tool_name = parsed.get("tool")?.as_str()?.to_string();
    let parameters = parsed.get("parameters")?.clone();
    Some((tool_name, parameters))
}

/// Intenta parsear el formato {"name": "...", "arguments": {...}}.
fn try_parse_function_format(text: &str) -> Option<(String, serde_json::Value)> {
    let start = text.find("\"name\"")?;

    // Must also contain "arguments"
    if !text.contains("\"arguments\"") {
        return None;
    }

    let brace_start = text[..start].rfind('{')?;
    let after_name = &text[start..];

    let mut depth = 0;
    let mut end = 0;
    for (i, ch) in after_name.char_indices() {
        if ch == '{' {
            depth += 1;
        } else if ch == '}' {
            depth -= 1;
        }
        if depth < 0 && ch == '}' {
            end = i + 1;
            break;
        }
    }
    if end == 0 {
        return None;
    }

    let json_str = &text[brace_start..start + end];
    let parsed: serde_json::Value = serde_json::from_str(json_str).ok()?;

    let tool_name = parsed.get("name")?.as_str()?.to_string();
    let parameters = parsed.get("arguments")?.clone();
    Some((tool_name, parameters))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_tool_call_nano_format() {
        let text = r#"Some text before {"tool": "get_weather", "parameters": {"city": "London"}} some after"#;
        let result = extract_tool_call_json(text);
        assert!(result.is_some());
        let (name, params) = result.unwrap();
        assert_eq!(name, "get_weather");
        assert_eq!(params["city"], "London");
    }

    #[test]
    fn test_extract_tool_call_openai_format() {
        let text = r#"{"name": "send_email", "arguments": {"to": "a@b.com", "subject": "Hello"}}"#;
        let result = extract_tool_call_json(text);
        assert!(result.is_some());
        let (name, params) = result.unwrap();
        assert_eq!(name, "send_email");
        assert_eq!(params["to"], "a@b.com");
    }

    #[test]
    fn test_strip_tool_call_json() {
        let text = r#"Let me check the weather. {"tool": "get_weather", "parameters": {"city": "London"}}"#;
        let cleaned = strip_tool_call_json(text);
        assert_eq!(cleaned, "Let me check the weather.");
    }

    #[test]
    fn test_find_matching_brace() {
        assert_eq!(find_matching_brace("{}"), Some(2));
        assert_eq!(find_matching_brace("{}{}"), Some(2));
        assert_eq!(find_matching_brace("{{}}"), Some(4));
        assert_eq!(find_matching_brace("{"), None);
    }
}
