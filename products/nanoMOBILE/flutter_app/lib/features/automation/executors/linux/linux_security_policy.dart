/// Política de gobernanza y confinamiento seguro para operaciones Linux del agente.
///
/// Protege el dispositivo y el rootfs de Nano contra modificaciones destructivas
/// accidentales generadas por modelos de lenguaje o planes autónomos.
class LinuxSecurityPolicy {
  final List<String> allowedWriteRoots;
  final List<String> forbiddenWritePaths;

  const LinuxSecurityPolicy({
    this.allowedWriteRoots = const [
      '/sdcard/Nanoai',
      '/sdcard/Download',
      '/data/data/com.nano.ai/files',
      '/tmp',
      '/home',
      '/root',
    ],
    this.forbiddenWritePaths = const [
      '/system',
      '/vendor',
      '/bin',
      '/sbin',
      '/usr/bin',
      '/usr/sbin',
      '/etc',
      '/dev',
      '/proc',
      '/sys',
    ],
  });

  /// Normaliza una ruta eliminando dobles barras y resolviendo redundancias simples.
  String normalizePath(String path) {
    var p = path.trim().replaceAll(r'\', '/');
    while (p.contains('//')) {
      p = p.replaceAll('//', '/');
    }
    if (p.isEmpty) return '/';
    return p;
  }

  /// Verifica si una ruta es segura para la operación solicitada.
  bool isPathAllowed(String path, {required bool isWrite}) {
    final normalized = normalizePath(path);

    // Si es solo lectura, permitimos explorar el sistema salvo que contenga traversal malicioso
    if (!isWrite) {
      return !_containsMaliciousTraversal(normalized);
    }

    // Prevención de path traversal para escrituras
    if (_containsMaliciousTraversal(normalized)) {
      return false;
    }

    // Verificar si cae dentro de rutas críticas prohibidas
    for (final forbidden in forbiddenWritePaths) {
      if (normalized == forbidden || normalized.startsWith('$forbidden/')) {
        return false;
      }
    }

    // Comprobar si coincide con al menos una de las raíces de escritura permitidas
    for (final root in allowedWriteRoots) {
      if (normalized == root || normalized.startsWith('$root/')) {
        return true;
      }
    }

    // Rutas relativas se interpretan en el workspace del usuario
    if (!normalized.startsWith('/')) {
      return true;
    }

    return false;
  }

  /// Verifica si el binario o comando es apto para invocación directa estructurada.
  bool isExecutableSafe(String executable) {
    final exe = executable.trim().toLowerCase();
    const banned = {
      'mkfs',
      'fdisk',
      'dd',
      'reboot',
      'shutdown',
      'poweroff',
      'init',
    };
    return !banned.contains(exe);
  }

  bool _containsMaliciousTraversal(String path) {
    final segments = path.split('/');
    return segments.contains('..');
  }
}
