/// Utilidades compartidas de seguridad y sanitización.
///
/// Centraliza lógica de sanitización de input para evitar duplicación
/// entre shell_executor y terminal_audit_logger.
class SecurityUtils {
  /// Sanitiza una cadena de texto para prevenir inyección y loggear información sensible.
  ///
  /// - Redacta paths de sistema (app-data, user-paths)
  /// - Redacta tokens/passwords/secrets
  /// - Trunca strings largos (>500 caracteres)
  static String sanitizeInput(String value) {
    var s = value;

    // Redactar paths de sistema
    s = s.replaceAll(RegExp(r'/data/(user|data)/0/[^\s]+'), '<app-data>');
    s = s.replaceAll(
      RegExp(r'C:\\Users\\[^\s]+', caseSensitive: false),
      '<user-path>',
    );

    // Redactar secrets
    s = s.replaceAll(
      RegExp(
        r'(token|password|passwd|secret|key)=([^\s&]+)',
        caseSensitive: false,
      ),
      r'$1=<redacted>',
    );

    // Truncar strings largos
    if (s.length > 500) s = '${s.substring(0, 500)}...';

    return s;
  }

  /// Sanitiza un comando para prevenir inyección de comandos.
  /// Bloquea caracteres peligrosos y patrones de inyección.
  static String sanitizeCommand(String cmd) {
    // Lista de caracteres/patrones peligrosos bloqueados
    final dangerousPatterns = [
      RegExp(r';\s*\$'), // Command chaining con variables
      RegExp(r'\|\s*\$'), // Pipe con variables
      RegExp(r'&\s*\$'), // Background con variables
      RegExp(r'\$\(?'), // Subshell
      RegExp(r'`'), // Backticks (command substitution)
      RegExp(r'\$\{'), // Variable expansion
      RegExp(r'>\s*\$'), // Redirection con variables
      RegExp(r'<\s*\$'), // Input redirection con variables
      RegExp(r'\n'), // Newlines (command chaining)
      RegExp(r'\r'), // Carriage return
    ];

    for (final pattern in dangerousPatterns) {
      if (pattern.hasMatch(cmd)) {
        throw ArgumentError(
          'Comando contiene patrón peligroso: ${pattern.pattern}',
        );
      }
    }

    // Validar longitud máxima para prevenir ataques de buffer overflow
    if (cmd.length > 4096) {
      throw ArgumentError('Comando demasiado largo (máximo 4096 caracteres)');
    }

    return cmd;
  }
}
