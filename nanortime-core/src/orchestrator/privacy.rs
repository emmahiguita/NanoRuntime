//! Filtro de privacidad — detección y anonimización de PII.
//!
//! Detecta datos sensibles (emails, teléfonos, tarjetas de crédito,
//! números de seguridad social) usando expresiones regulares.
//! Si se detecta PII, el routing fuerza Tier 1 (local).

use regex::Regex;
use std::sync::OnceLock;

/// Patrones regex para tipos comunes de PII.
fn pii_patterns() -> &'static [(&'static str, &'static str)] {
    static PATTERNS: OnceLock<Vec<(&'static str, &'static str)>> = OnceLock::new();
    PATTERNS.get_or_init(|| {
        vec![
            // Email addresses
            (
                r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b",
                "[EMAIL]",
            ),
            // Credit card numbers (handles spaces, dashes, or no separators)
            (
                r"\b(?:\d{4}[ -]?){3}\d{4}\b",
                "[CARD]",
            ),
            // US phone numbers: (XXX) XXX-XXXX, XXX-XXX-XXXX, XXX.XXX.XXXX
            (
                r"\b\(?\d{3}\)?[-.]?\s?\d{3}[-.]?\d{4}\b",
                "[PHONE]",
            ),
            // US Social Security Numbers: XXX-XX-XXXX
            (
                r"\b\d{3}-\d{2}-\d{4}\b",
                "[SSN]",
            ),
            // IP addresses (may be considered PII in some contexts)
            (
                r"\b(?:\d{1,3}\.){3}\d{1,3}\b",
                "[IP]",
            ),
        ]
    })
}

/// Palabras clave que indican contenido sensible.
fn sensitive_keywords() -> &'static [&'static str] {
    static KEYWORDS: OnceLock<Vec<&'static str>> = OnceLock::new();
    KEYWORDS.get_or_init(|| {
        vec![
            // Financial
            "credit card", "credit_card", "card number", "cvv", "cvc",
            "bank account", "routing number", "iban", "swift",
            // Medical
            "patient", "diagnosis", "medical record", "health insurance",
            "prescription", "phi", "hipaa",
            // Personal
            "social security", "passport number", "driver license",
            "date of birth", "mother's maiden name",
        ]
    })
}

/// Detecta si un texto contiene información personal identificable (PII).
///
/// Usa una combinación de patrones regex y heurísticas de palabras clave.
/// No es exhaustivo pero cubre los casos más comunes.
///
/// # Ejemplos
///
/// ```
/// use nanortime_core::orchestrator::privacy::contains_pii;
///
/// assert!(contains_pii("Mi email es juan@ejemplo.com"));
/// assert!(!contains_pii("Hola, ¿cómo estás?"));
/// ```
pub fn contains_pii(text: &str) -> bool {
    let text_lower = text.to_lowercase();

    // Check regex patterns
    for (pattern, _replacement) in pii_patterns() {
        if let Ok(re) = Regex::new(pattern) {
            if re.is_match(text) {
                return true;
            }
        }
    }

    // Check sensitive keywords
    for keyword in sensitive_keywords() {
        if text_lower.contains(keyword) {
            return true;
        }
    }

    false
}

/// Anonimiza un texto reemplazando PII con placeholders.
///
/// Reemplaza emails, tarjetas de crédito, teléfonos y otros
/// datos sensibles con etiquetas como `[EMAIL]`, `[PHONE]`, etc.
///
/// Esto permite enviar el texto a servicios cloud (Tier 3)
/// sin exponer datos sensibles.
///
/// # Ejemplos
///
/// ```
/// use nanortime_core::orchestrator::privacy::anonymize;
///
/// let result = anonymize("Contacta a juan@mail.com o al 555-123-4567");
/// assert!(result.contains("[EMAIL]"));
/// assert!(result.contains("[PHONE]"));
/// assert!(!result.contains("juan@mail.com"));
/// ```
pub fn anonymize(text: &str) -> String {
    let mut result = text.to_string();

    for (pattern, replacement) in pii_patterns() {
        if let Ok(re) = Regex::new(pattern) {
            result = re.replace_all(&result, *replacement).to_string();
        }
    }

    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_detect_email() {
        assert!(contains_pii("Contacta a juan@ejemplo.com"));
        assert!(contains_pii("Email: maria.garcia@empresa.co.uk"));
        assert!(!contains_pii("Hola mundo"));
        assert!(!contains_pii("El archivo está en /home/user@host/"));
    }

    #[test]
    fn test_detect_phone() {
        assert!(contains_pii("Llama al 555-123-4567"));
        assert!(contains_pii("Mi número es 555.123.4567"));
        assert!(contains_pii("Tel: (555) 123-4567"));
        assert!(!contains_pii("Tengo 25 años"));
        assert!(!contains_pii("La versión 3.1415.9265"));
    }

    #[test]
    fn test_detect_credit_card() {
        assert!(contains_pii("Mi tarjeta es 4111-1111-1111-1111"));
        assert!(contains_pii("Tarjeta: 4111111111111111"));
        assert!(contains_pii("Paga con 5500 0000 0000 0004"));
        assert!(!contains_pii("Tengo 4 hermanos"));
    }

    #[test]
    fn test_detect_ssn() {
        assert!(contains_pii("SSN: 123-45-6789"));
        // Non-SSN, non-phone pattern (2-2-4 digits)
        assert!(!contains_pii("El código es 01-23-4567"));
    }

    #[test]
    fn test_detect_sensitive_keywords() {
        assert!(contains_pii("Necesito mi credit card number"));
        assert!(contains_pii("El patient tiene diagnosis de diabetes"));
        assert!(!contains_pii("Me gusta programar en Rust"));
    }

    #[test]
    fn test_anonymize_email() {
        let text = "Contacta a juan@ejemplo.com para más info";
        let result = anonymize(text);
        assert!(!result.contains("juan@ejemplo.com"));
        assert!(result.contains("[EMAIL]"));
    }

    #[test]
    fn test_anonymize_phone() {
        let text = "Llama al 555-123-4567 o al (555) 987-6543";
        let result = anonymize(text);
        assert!(!result.contains("555-123-4567"));
        assert!(result.matches("[PHONE]").count() >= 2);
    }

    #[test]
    fn test_anonymize_multiple() {
        let text = "Email: juan@mail.com, Tel: 555-123-4567, Card: 4111-1111-1111-1111";
        let result = anonymize(text);
        assert!(result.contains("[EMAIL]"));
        assert!(result.contains("[PHONE]"));
        assert!(result.contains("[CARD]"));
        assert!(!result.contains("juan@mail.com"));
        assert!(!result.contains("4111-1111-1111-1111"));
    }

    #[test]
    fn test_no_pii_in_clean_text() {
        let text = "Hola, ¿cómo estás? Espero que tengas un buen día.";
        assert!(!contains_pii(text));
        let result = anonymize(text);
        assert_eq!(result, text);
    }
}
