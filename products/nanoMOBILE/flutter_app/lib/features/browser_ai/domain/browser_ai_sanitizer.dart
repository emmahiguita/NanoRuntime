/// QUÉ HACE:
/// Anonimiza y redacta información confidencial antes de enviarla a chats web de IA.
///
/// CÓMO FUNCIONA:
/// Aplica expresiones regulares deterministas para enmascarar correos, números
/// telefónicos, tarjetas de pago y tokens de credenciales sin modificar la intención de la consulta.
///
/// POR QUÉ:
/// Protege la privacidad del usuario ante proveedores externos como OpenAI, Google o Anthropic.
class BrowserAiSanitizer {
  const BrowserAiSanitizer();

  static final _emailRegex = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    caseSensitive: false,
  );

  static final _phoneRegex = RegExp(
    r'(\+?\d{1,3}[-.\s]?)?(\(?\d{2,4}\)?[-.\s]?)?\d{3,4}[-.\s]?\d{4}',
  );

  static final _cardRegex = RegExp(
    r'\b(?:\d{4}[ -]?){3}\d{4}\b',
  );

  static final _tokenRegex = RegExp(
    r'(sk-[a-zA-Z0-9]{20,}|bearer\s+[a-zA-Z0-9_\-\.]{20,}|ghp_[a-zA-Z0-9]{20,})',
    caseSensitive: false,
  );

  /// Redacta el texto eliminando datos privados identificables.
  String sanitize(String input) {
    if (input.trim().isEmpty) return input;

    var sanitized = input;
    sanitized = sanitized.replaceAllMapped(_tokenRegex, (_) => '[CREDENCIAL_REDACTADA]');
    sanitized = sanitized.replaceAllMapped(_cardRegex, (_) => '[NUMERO_PAGO_REDACTADO]');
    sanitized = sanitized.replaceAllMapped(_emailRegex, (_) => '[EMAIL_REDACTADO]');
    sanitized = sanitized.replaceAllMapped(_phoneRegex, (m) {
      final val = m.group(0) ?? '';
      // Evitar redactar números cortos que no sean teléfonos (ej: años 2026, cantidades)
      if (val.replaceAll(RegExp(r'\D'), '').length >= 7) {
        return '[TELEFONO_REDACTADO]';
      }
      return val;
    });

    return sanitized;
  }
}
