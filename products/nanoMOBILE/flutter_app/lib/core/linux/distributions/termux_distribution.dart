import 'dart:io';

import '../linux_distribution.dart';
import '../../services/rootfs_manager.dart';

/// Adapter de Termux que implementa LinuxDistribution.
///
/// Este adapter envuelve el RootfsManager existente sin modificarlo,
/// permitiendo que Termux funcione dentro de la nueva arquitectura
/// multi-distro sin romper la funcionalidad existente.
///
/// NO modificar RootfsManager directamente — este adapter actúa como
/// puente entre la interfaz nueva y la implementación existente.
class TermuxDistribution implements LinuxDistribution {
  final RootfsManager _rootfsManager;

  // Caché de estado para evitar llamadas repetidas al filesystem
  bool? _cachedInstalled;

  TermuxDistribution({
    RootfsManager? rootfsManager,
  }) : _rootfsManager = rootfsManager ?? RootfsManager.instance;

  @override
  String get id => 'termux';

  @override
  String get name => 'Termux';

  @override
  String get architecture => 'aarch64';

  @override
  String get packageBackend => 'pkg';

  @override
  String get defaultShell => '/bin/bash';

  @override
  List<String> get initialEnvironment => [
    'HOME=/data/data/com.termux/files/home',
    'TERM=xterm-256color',
    'COLORTERM=truecolor',
  ];

  @override
  Uri get rootfsUri => Uri.parse(RootfsManager.bootstrapUrl);

  @override
  String? get expectedSha256 => null; // SHA256 se verifica desde SHA256SUMS

  @override
  Future<bool> isInstalled() async {
    // Usar caché si está disponible
    if (_cachedInstalled != null) return _cachedInstalled!;

    // Delegar a RootfsManager existente
    _cachedInstalled = await _rootfsManager.checkInstalled();
    return _cachedInstalled!;
  }

  @override
  Future<void> install({
    required void Function(String stage, int pct) onProgress,
  }) async {
    // Crear un RootfsManager temporal con callback de progreso
    final manager = RootfsManager(onProgress: onProgress);
    await manager.install();
    _cachedInstalled = true; // Actualizar caché
  }

  @override
  Future<void> repair() async {
    // Termux no tiene repair específico — reinstalar si está corrupto
    final manager = RootfsManager(onProgress: (stage, pct) {});
    await manager.install();
    _cachedInstalled = true;
  }

  @override
  Future<void> uninstall() async {
    // Eliminar el directorio usr del rootfs
    final usrDir = _rootfsManager.usrDir;
    if (usrDir != null && Directory(usrDir).existsSync()) {
      Directory(usrDir).deleteSync(recursive: true);
    }
    _cachedInstalled = false;
  }

  @override
  Future<LinuxSession> start() async {
    // Para MVP, retornar una sesión placeholder
    // La ejecución real de comandos se hace vía ShellExecutor/IBinExecutor
    // cuando se necesita
    return LinuxSession(
      id: 'termux-${DateTime.now().millisecondsSinceEpoch}',
      distributionId: id,
      state: LinuxSessionState.running,
      startedAt: DateTime.now(),
      pid: null,
      rootfsPath: _rootfsManager.usrDir ?? '',
      command: '/bin/bash',
    );
  }

  @override
  Future<void> stop() async {
    // Para MVP, no-op — cuando se implemente LinuxSessionManager
    // se encargará de terminar procesos
    // TODO: Implementar terminación real de sesión
  }

  @override
  Future<LinuxDistributionInfo> getInfo() async {
    // Leer /etc/os-release si existe
    final etcOsRelease = File('${_rootfsManager.usrDir}/etc/os-release');
    if (await etcOsRelease.exists()) {
      final content = await etcOsRelease.readAsString();
      final osRelease = _parseOsRelease(content);
      return LinuxDistributionInfo.fromOsRelease(osRelease);
    }

    // Fallback para Termux que no tiene /etc/os-release estándar
    return const LinuxDistributionInfo(
      id: 'termux',
      name: 'Termux',
      version: '',
      idLike: 'android',
      prettyName: 'Termux (Android Linux Environment)',
      homeUrl: 'https://termux.com',
      supportUrl: 'https://github.com/termux/termux-packages',
    );
  }

  Map<String, String> _parseOsRelease(String content) {
    final map = <String, String>{};
    for (final line in content.split('\n')) {
      if (line.trim().isEmpty || line.startsWith('#')) continue;
      final parts = line.split('=');
      if (parts.length == 2) {
        final key = parts[0].trim();
        var value = parts[1].trim();
        // Remover comillas si están presentes
        if (value.startsWith('"') && value.endsWith('"')) {
          value = value.substring(1, value.length - 1);
        }
        map[key] = value;
      }
    }
    return map;
  }
}
