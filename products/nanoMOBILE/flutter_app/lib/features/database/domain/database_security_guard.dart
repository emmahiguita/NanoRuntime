/// Excepción lanzada cuando una operación de base de datos o archivo viola las políticas de seguridad
class DatabaseSecurityException implements Exception {
  final String message;
  const DatabaseSecurityException(this.message);

  @override
  String toString() => 'DatabaseSecurityException: $message';
}

/// Guardia de seguridad para el módulo de bases de datos, hojas de cálculo y Shell.
/// Protege contra Path Traversal, Inyección SQL en nombres de tablas/columnas y
/// ejecución indebida de comandos arbitrarios en el CLI de SQLite.
class DatabaseSecurityGuard {
  /// Directorios del sistema expresamente prohibidos
  static const List<String> _forbiddenPathPrefixes = [
    '/system',
    '/proc',
    '/sys',
    '/etc',
    '/root',
    '/dev',
    '/vendor',
    '/apex',
    '/product',
  ];

  /// Extensiones de archivo válidas para hojas de cálculo y bases de datos locales
  static const Set<String> _allowedExtensions = {
    'csv',
    'tsv',
    'txt',
    'sql',
    'sqlite',
    'sqlite3',
    'db',
  };

  /// Valida que una ruta de archivo sea segura:
  /// 1. No contiene secuencias de escape de directorio ('..')
  /// 2. No contiene caracteres nulos o secuencias de control
  /// 3. No accede a rutas sensibles del sistema operativo
  /// 4. Cumple con extensiones aprobadas
  static String validateAndSanitizePath(String rawPath, {bool allowAnyExtension = false}) {
    final clean = rawPath.trim();
    if (clean.isEmpty) {
      throw const DatabaseSecurityException('La ruta de archivo no puede estar vacía.');
    }

    // Prohibir secuencias de navegación de directorios (Path Traversal)
    if (clean.contains('..') || clean.contains('\x00') || clean.contains('\n') || clean.contains('\r')) {
      throw const DatabaseSecurityException(
        'Intento de Path Traversal bloqueado: la ruta no puede contener ".." ni caracteres de control.',
      );
    }

    // Normalizar separadores
    final normalized = clean.replaceAll('\\', '/');

    // Bloquear rutas de sistema protegidas
    final lower = normalized.toLowerCase();
    for (final forbidden in _forbiddenPathPrefixes) {
      if (lower == forbidden || lower.startsWith('$forbidden/')) {
        throw DatabaseSecurityException(
          'Acceso denegado: el directorio $forbidden está protegido por la política de seguridad.',
        );
      }
    }

    // Validar extensión si aplica
    if (!allowAnyExtension) {
      final ext = normalized.split('.').last.toLowerCase();
      if (!_allowedExtensions.contains(ext)) {
        throw DatabaseSecurityException(
          'Tipo de archivo no permitido (.$ext). Tipos válidos: ${_allowedExtensions.join(", ")}.',
        );
      }
    }

    return normalized;
  }

  /// Valida que el nombre de una tabla o columna sea un identificador SQL seguro:
  /// Solo letras, dígitos y guión bajo. Evita inyecciones de escape en cláusulas FROM / WHERE.
  static String validateIdentifier(String identifier) {
    final clean = identifier.trim();
    if (clean.isEmpty) {
      throw const DatabaseSecurityException('El identificador no puede estar vacío.');
    }

    final validPattern = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!validPattern.hasMatch(clean)) {
      throw DatabaseSecurityException(
        'Identificador no seguro "$clean": solo se permiten letras, números y guiones bajos.',
      );
    }

    // Limitar longitud para evitar abusos de memoria
    if (clean.length > 64) {
      throw const DatabaseSecurityException('El identificador supera el límite seguro de 64 caracteres.');
    }

    return clean;
  }

  /// Sanitiza una consulta SQL antes de enviarla a SQLite CLI para prevenir inyecciones de comandos shell
  static String sanitizeSqlForShellExecution(String query) {
    final clean = query.trim();
    if (clean.isEmpty) {
      throw const DatabaseSecurityException('La consulta SQL está vacía.');
    }

    // Prohibir secuencias de concatenación de comandos de Shell (;, &&, ||, |, `, $(), etc.)
    // que podrían escapar el argumento si se ejecutara en bash
    final dangerousShellPatterns = [
      RegExp(r'`'),
      RegExp(r'\$\('),
      RegExp(r';\s*(?:rm|cat|sh|bash|chmod|chown|kill|reboot|su)\b', caseSensitive: false),
    ];

    for (final pattern in dangerousShellPatterns) {
      if (pattern.hasMatch(clean)) {
        throw const DatabaseSecurityException(
          'Consulta bloqueada por contener secuencias potencialmente peligrosas para el shell.',
        );
      }
    }

    return clean;
  }
}
