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

  /// Sanitiza un comando para prevenir inyección de caracteres nulos y desbordamientos.
  /// En el entorno sandbox / rootfs, variables de entorno ($PATH, $HOME) y
  /// secuencias multilínea son sintaxis de shell válida y se ejecutan aisladas.
  static String sanitizeCommand(String cmd) {
    // Bloquear bytes nulos para prevenir ataques de truncamiento C-string
    if (cmd.contains('\x00')) {
      throw ArgumentError('Comando contiene byte nulo no permitido');
    }

    // Validar longitud máxima para prevenir desbordamientos
    if (cmd.length > 65536) {
      throw ArgumentError('Comando demasiado largo (máximo 65536 caracteres)');
    }

    return cmd;
  }
}
