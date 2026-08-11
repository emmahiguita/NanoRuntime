//! Generación con gramática restrictiva.
//!
//! Permite forzar que la salida del modelo cumpla con una gramática
//! predefinida (ej. JSON válido). Útil para tool calls donde se
//! necesita que el modelo emita JSON parseable.
//!
//! Utiliza la funcionalidad `llama_grammar` de llama.cpp para
//! restringir el espacio de muestreo a tokens válidos según
//! una gramática GBNF (GGML BNF).

/// Una regla de gramática GBNF.
#[derive(Debug, Clone)]
pub struct GrammarRule {
    /// Nombre de la regla.
    pub name: String,
    /// Definición de la regla en formato GBNF.
    pub definition: String,
}

/// Gramática GBNF completa para generación restringida.
#[derive(Debug, Clone)]
pub struct Grammar {
    /// Reglas que componen la gramática.
    rules: Vec<GrammarRule>,
    /// La regla raíz desde la que se empieza a generar.
    root: String,
}

impl Grammar {
    /// Crea una gramática para forzar salida JSON válida.
    ///
    /// Útil para tool calls donde el modelo debe emitir:
    /// ```json
    /// {"tool": "name", "parameters": {...}}
    /// ```
    pub fn json_tool_call() -> Self {
        let rules = vec![
            GrammarRule {
                name: "root".to_string(),
                definition: "object".to_string(),
            },
            GrammarRule {
                name: "object".to_string(),
                definition: r#""{" ws string ws ":" ws string ws "," ws "\"parameters\"" ws ":" ws param-object ws "}""#.to_string(),
            },
            GrammarRule {
                name: "param-object".to_string(),
                definition: r#""{" ( ws string ws ":" ws value ws ("," ws string ws ":" ws value ws)* )? "}""#.to_string(),
            },
            GrammarRule {
                name: "value".to_string(),
                definition: "string | number | boolean | null".to_string(),
            },
            GrammarRule {
                name: "string".to_string(),
                definition: r#""\"" [^"\\\x00-\x1F]* "\"""#.to_string(),
            },
            GrammarRule {
                name: "number".to_string(),
                definition: r#"[0-9]+ ("." [0-9]+)?"#.to_string(),
            },
            GrammarRule {
                name: "boolean".to_string(),
                definition: r#""true" | "false""#.to_string(),
            },
            GrammarRule {
                name: "null".to_string(),
                definition: r#""null""#.to_string(),
            },
            GrammarRule {
                name: "ws".to_string(),
                definition: r#"[ \t\n]*"#.to_string(),
            },
        ];

        Self {
            rules,
            root: "root".to_string(),
        }
    }

    /// Crea una gramática para respuestas de tipo sí/no.
    pub fn yes_no() -> Self {
        let rules = vec![GrammarRule {
            name: "root".to_string(),
            definition: r#""Yes" | "No""#.to_string(),
        }];

        Self {
            rules,
            root: "root".to_string(),
        }
    }

    /// Crea una gramática para valores numéricos.
    pub fn number() -> Self {
        let rules = vec![GrammarRule {
            name: "root".to_string(),
            definition: r#"[0-9]+ ("." [0-9]+)?"#.to_string(),
        }];

        Self {
            rules,
            root: "root".to_string(),
        }
    }

    /// Crea una gramática personalizada a partir de reglas y root.
    pub fn custom(rules: Vec<GrammarRule>, root: &str) -> Self {
        Self {
            rules,
            root: root.to_string(),
        }
    }

    /// Serializa la gramática a formato GBNF string.
    ///
    /// Este string se pasa directamente a `llama_grammar_init` en llama.cpp.
    pub fn to_gbnf(&self) -> String {
        let mut output = String::new();
        for rule in &self.rules {
            output.push_str(&format!("{} ::= {}\n", rule.name, rule.definition));
        }
        output
    }

    /// Valida que un string cumpla con la gramática.
    ///
    /// Implementa un parser simple para verificar la salida del modelo.
    /// En producción, esto se usa como verificación adicional.
    pub fn validate(&self, text: &str) -> bool {
        match self.root.as_str() {
            "root" if self.rules.len() == 1 && self.rules[0].definition.contains("Yes") => {
                text.trim() == "Yes" || text.trim() == "No"
            }
            _ => {
                // For JSON grammar, try to parse as JSON
                if self.rules.iter().any(|r| r.name == "object") {
                    serde_json::from_str::<serde_json::Value>(text).is_ok()
                } else {
                    // Default: always pass (full validation requires GBNF parser)
                    true
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_json_tool_call_grammar() {
        let grammar = Grammar::json_tool_call();
        let gbnf = grammar.to_gbnf();
        assert!(gbnf.contains("root ::="));
        assert!(gbnf.contains("object ::="));
    }

    #[test]
    fn test_yes_no_grammar() {
        let grammar = Grammar::yes_no();
        assert!(grammar.validate("Yes"));
        assert!(grammar.validate("No"));
        assert!(!grammar.validate("Maybe"));
    }

    #[test]
    fn test_validate_json() {
        let grammar = Grammar::json_tool_call();
        assert!(grammar.validate(r#"{"tool": "send_email", "parameters": {"to": "a@b.com"}}"#));
        assert!(!grammar.validate("not json"));
    }

    #[test]
    fn test_number_grammar() {
        let grammar = Grammar::number();
        let gbnf = grammar.to_gbnf();
        assert!(gbnf.contains("root ::="));
    }
}
