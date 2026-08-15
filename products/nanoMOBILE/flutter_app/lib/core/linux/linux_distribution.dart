/// Abstracción común para distribuciones Linux ejecutadas vía PRoot.
///
/// Todas las distribuciones (Termux, Kali, Ubuntu, Debian, Arch, Alpine)
/// deben implementar esta interface para garantizar un contrato unificado
/// de instalación, ejecución y gestión de lifecycle.
///
/// NO modificar la implementación existente de RootfsManager/KaliManager
/// directamente — en su lugar, crear adapters que implementen esta interface.
abstract interface class LinuxDistribution {
  /// Identificador único de la distribución (ej: 'termux', 'kali', 'ubuntu').
  String get id;

  /// Nombre legible (ej: 'Termux', 'Kali Linux', 'Ubuntu 24.04').
  String get name;

  /// Arquitectura de la distribución (ej: 'aarch64', 'armv7a').
  String get architecture;

  /// Gestor de paquetes usado (ej: 'apt', 'pacman', 'apk', 'pkg').
  String get packageBackend;

  /// Shell por defecto (ej: '/bin/bash', '/bin/sh').
  String get defaultShell;

  /// Variables de entorno iniciales para la distribución.
  List<String> get initialEnvironment;

  /// URI del rootfs oficial (tarball/zip).
  Uri get rootfsUri;

  /// SHA256 esperado del rootfs (para verificación de integridad).
  String? get expectedSha256;

  /// Verifica si la distribución está instalada.
  ///
  /// Debe verificar que los archivos críticos existan (ej: /bin/bash,
  /// /etc/os-release) y sean ejecutables.
  Future<bool> isInstalled();

  /// Instala la distribución desde cero.
  ///
  /// Parámetros:
  /// - onProgress: Callback para reportar progreso (stage, porcentaje 0-100)
  ///
  /// Flujo esperado:
  /// 1. Download rootfs
  /// 2. Verify SHA256
  /// 3. Extract to temporary location
  /// 4. Validate critical files
  /// 5. Promote to final location
  ///
  /// Si la instalación falla a mitad, debe rollback y dejar el sistema
  /// en estado consistente (sin instalación parcial).
  Future<void> install({
    required void Function(String stage, int pct) onProgress,
  });

  /// Repara una instalación corrupta o incompleta.
  ///
  /// Debe detectar archivos faltantes y restaurarlos sin descargar
  /// todo el rootfs si es posible.
  Future<void> repair();

  /// Desinstala completamente la distribución.
  ///
  /// Debe eliminar todos los archivos y configuraciones asociadas.
  /// Precaución: esta operación es destructiva.
  Future<void> uninstall();

  /// Inicia una sesión de la distribución.
  ///
  /// Retorna un descriptor de sesión que incluye:
  /// - ID de sesión único
  /// - PID del proceso principal
  /// - Estado de la sesión
  /// - Path del rootfs
  ///
  /// Si ya existe una sesión activa, debe retornar la existente
  /// o reportar error (según implementación).
  Future<LinuxSession> start();

  /// Detiene todas las sesiones activas de esta distribución.
  ///
  /// Debe enviar señales SIGTERM/SIGKILL apropiadas y limpiar recursos.
  Future<void> stop();

  /// Obtiene información del sistema de la distribución.
  ///
  /// Retorna datos de /etc/os-release y otros metadatos.
  Future<LinuxDistributionInfo> getInfo();
}

/// Descriptor de una sesión Linux activa.
class LinuxSession {
  final String id;
  final String distributionId;
  final LinuxSessionState state;
  final DateTime? startedAt;
  final int? pid;
  final String rootfsPath;
  final String? command;

  const LinuxSession({
    required this.id,
    required this.distributionId,
    required this.state,
    this.startedAt,
    this.pid,
    required this.rootfsPath,
    this.command,
  });

  bool get isRunning => state == LinuxSessionState.running;
  bool get isStopped => state == LinuxSessionState.stopped;
  bool get isFailed => state == LinuxSessionState.failed;
}

/// Estados de una sesión Linux.
enum LinuxSessionState {
  stopped,
  starting,
  running,
  stopping,
  failed,
}

/// Información del sistema de una distribución.
class LinuxDistributionInfo {
  final String id;
  final String name;
  final String version;
  final String idLike;
  final String prettyName;
  final String homeUrl;
  final String supportUrl;
  final String? kernelVersion;
  final String? architecture;

  const LinuxDistributionInfo({
    required this.id,
    required this.name,
    required this.version,
    required this.idLike,
    required this.prettyName,
    required this.homeUrl,
    required this.supportUrl,
    this.kernelVersion,
    this.architecture,
  });

  /// Crea LinuxDistributionInfo desde /etc/os-release.
  factory LinuxDistributionInfo.fromOsRelease(Map<String, String> osRelease) {
    return LinuxDistributionInfo(
      id: osRelease['ID'] ?? 'unknown',
      name: osRelease['NAME'] ?? 'Unknown',
      version: osRelease['VERSION'] ?? '',
      idLike: osRelease['ID_LIKE'] ?? '',
      prettyName: osRelease['PRETTY_NAME'] ?? osRelease['NAME'] ?? 'Unknown',
      homeUrl: osRelease['HOME_URL'] ?? '',
      supportUrl: osRelease['SUPPORT_URL'] ?? '',
    );
  }
}
