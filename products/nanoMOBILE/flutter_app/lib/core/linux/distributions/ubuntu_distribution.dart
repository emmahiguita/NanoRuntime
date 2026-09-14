import 'dart:io';

import '../linux_distribution.dart';
import '../../services/ubuntu_manager.dart';

/// Adapter de Ubuntu Linux que implementa LinuxDistribution.
///
/// Este adapter envuelve el UbuntuManager existente sin modificarlo,
/// permitiendo que Ubuntu funcione dentro de la nueva arquitectura
/// multi-distro sin romper la funcionalidad existente.
///
/// NO modificar UbuntuManager directamente — este adapter actúa como
/// puente entre la interfaz nueva y la implementación existente.
class UbuntuDistribution implements LinuxDistribution {
  final UbuntuManager? _ubuntuManager;

  // Caché de estado para evitar llamadas repetidas al filesystem
  bool? _cachedInstalled;

  UbuntuDistribution({UbuntuManager? ubuntuManager}) : _ubuntuManager = ubuntuManager;

  @override
  String get id => 'Ubuntu';

  @override
  String get name => 'Ubuntu Linux';

  @override
  String get architecture => 'aarch64';

  @override
  String get packageBackend => 'apt';

  @override
  String get defaultShell => '/bin/bash';

  @override
  List<String> get initialEnvironment => [
    'HOME=/root',
    'TERM=xterm-256color',
    'LANG=C.UTF-8',
  ];

  @override
  Uri get rootfsUri => Uri.parse(UbuntuManager.rootfsUrl);

  @override
  String? get expectedSha256 => UbuntuManager.expectedSha256;

  @override
  Future<bool> isInstalled() async {
    if (_ubuntuManager == null) return false;
    // Usar caché si está disponible
    if (_cachedInstalled != null) return _cachedInstalled!;

    // Delegar a UbuntuManager existente
    _cachedInstalled = await _ubuntuManager.checkInstalled();
    return _cachedInstalled!;
  }

  @override
  Future<void> install({
    required void Function(String stage, int pct) onProgress,
  }) async {
    if (_ubuntuManager == null) {
      throw StateError(
        'UbuntuManager no inicializado. Inyectar UbuntuManager antes de usar.',
      );
    }
    // Delegar a UbuntuManager existente con callback de progreso
    final success = await _ubuntuManager.install(onProgress);
    if (success) {
      _cachedInstalled = true;
    } else {
      _cachedInstalled = false;
    }
  }

  @override
  Future<void> repair() async {
    if (_ubuntuManager == null) {
      throw StateError(
        'UbuntuManager no inicializado. Inyectar UbuntuManager antes de usar.',
      );
    }
    // Ubuntu no tiene repair específico — reinstalar si está corrupto
    final success = await _ubuntuManager.install((stage, pct) {});
    if (success) {
      _cachedInstalled = true;
    }
  }

  @override
  Future<void> uninstall() async {
    if (_ubuntuManager == null) return;
    // Eliminar el directorio del rootfs Ubuntu
    final ubuntuRoot = _ubuntuManager.ubuntuRoot;
    if (ubuntuRoot != null) {
      final dir = Directory(ubuntuRoot);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    }
    _cachedInstalled = false;
  }

  @override
  Future<LinuxSession> start() async {
    if (_ubuntuManager == null) {
      throw StateError(
        'UbuntuManager no inicializado. Inyectar UbuntuManager antes de usar.',
      );
    }
    final installed = await isInstalled();
    if (!installed) {
      return LinuxSession(
        id: 'Ubuntu-${DateTime.now().millisecondsSinceEpoch}',
        distributionId: id,
        state: LinuxSessionState.failed,
        startedAt: DateTime.now(),
        pid: null,
        rootfsPath: _ubuntuManager.ubuntuRoot ?? '',
        command: '/bin/bash',
      );
    }
    return LinuxSession(
      id: 'Ubuntu-${DateTime.now().millisecondsSinceEpoch}',
      distributionId: id,
      state: LinuxSessionState.running,
      startedAt: DateTime.now(),
      pid: null,
      rootfsPath: _ubuntuManager.ubuntuRoot ?? '',
      command: '/bin/bash',
    );
  }

  @override
  Future<void> stop() async {
    _ubuntuManager?.stop();
  }

  @override
  Future<LinuxDistributionInfo> getInfo() async {
    if (_ubuntuManager == null) {
      // Fallback si UbuntuManager no está inicializado
      return const LinuxDistributionInfo(
        id: 'Ubuntu',
        name: 'Ubuntu Linux',
        version: 'rolling',
        idLike: 'debian',
        prettyName: 'Ubuntu GNU/Linux Rolling',
        homeUrl: 'https://www.Ubuntu.org',
        supportUrl: 'https://www.Ubuntu.org/docs/',
      );
    }

    // Leer /etc/os-release del rootfs Ubuntu
    final ubuntuRoot = _ubuntuManager.ubuntuRoot;
    if (ubuntuRoot != null) {
      final etcOsRelease = File('$ubuntuRoot/etc/os-release');
      if (await etcOsRelease.exists()) {
        final content = await etcOsRelease.readAsString();
        final osRelease = _parseOsRelease(content);
        return LinuxDistributionInfo.fromOsRelease(osRelease);
      }
    }

    // Fallback si /etc/os-release no existe
    return const LinuxDistributionInfo(
      id: 'Ubuntu',
      name: 'Ubuntu Linux',
      version: 'rolling',
      idLike: 'debian',
      prettyName: 'Ubuntu GNU/Linux Rolling',
      homeUrl: 'https://www.Ubuntu.org',
      supportUrl: 'https://www.Ubuntu.org/docs/',
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

