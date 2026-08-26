import 'dart:io';

import '../linux_distribution.dart';
import '../../services/kali_manager.dart';

/// Adapter de Kali Linux que implementa LinuxDistribution.
///
/// Este adapter envuelve el KaliManager existente sin modificarlo,
/// permitiendo que Kali funcione dentro de la nueva arquitectura
/// multi-distro sin romper la funcionalidad existente.
///
/// NO modificar KaliManager directamente — este adapter actúa como
/// puente entre la interfaz nueva y la implementación existente.
class KaliDistribution implements LinuxDistribution {
  final KaliManager? _kaliManager;

  // Caché de estado para evitar llamadas repetidas al filesystem
  bool? _cachedInstalled;

  KaliDistribution({KaliManager? kaliManager}) : _kaliManager = kaliManager;

  @override
  String get id => 'kali';

  @override
  String get name => 'Kali Linux';

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
  Uri get rootfsUri => Uri.parse(KaliManager.rootfsUrl);

  @override
  String? get expectedSha256 => KaliManager.expectedSha256;

  @override
  Future<bool> isInstalled() async {
    if (_kaliManager == null) return false;
    // Usar caché si está disponible
    if (_cachedInstalled != null) return _cachedInstalled!;

    // Delegar a KaliManager existente
    _cachedInstalled = await _kaliManager.checkInstalled();
    return _cachedInstalled!;
  }

  @override
  Future<void> install({
    required void Function(String stage, int pct) onProgress,
  }) async {
    if (_kaliManager == null) {
      throw StateError(
        'KaliManager no inicializado. Inyectar KaliManager antes de usar.',
      );
    }
    // Delegar a KaliManager existente con callback de progreso
    final success = await _kaliManager.install(onProgress);
    if (success) {
      _cachedInstalled = true;
    } else {
      _cachedInstalled = false;
    }
  }

  @override
  Future<void> repair() async {
    if (_kaliManager == null) {
      throw StateError(
        'KaliManager no inicializado. Inyectar KaliManager antes de usar.',
      );
    }
    // Kali no tiene repair específico — reinstalar si está corrupto
    final success = await _kaliManager.install((stage, pct) {});
    if (success) {
      _cachedInstalled = true;
    }
  }

  @override
  Future<void> uninstall() async {
    if (_kaliManager == null) return;
    // Eliminar el directorio del rootfs Kali
    final kaliRoot = _kaliManager.kaliRoot;
    if (kaliRoot != null) {
      final dir = Directory(kaliRoot);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    }
    _cachedInstalled = false;
  }

  @override
  Future<LinuxSession> start() async {
    if (_kaliManager == null) {
      throw StateError(
        'KaliManager no inicializado. Inyectar KaliManager antes de usar.',
      );
    }
    // Para MVP, retornar una sesión placeholder
    // La ejecución real de comandos se hace vía KaliManager.run()
    // cuando se necesita
    return LinuxSession(
      id: 'kali-${DateTime.now().millisecondsSinceEpoch}',
      distributionId: id,
      state: LinuxSessionState.running,
      startedAt: DateTime.now(),
      pid: null,
      rootfsPath: _kaliManager.kaliRoot ?? '',
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
    if (_kaliManager == null) {
      // Fallback si KaliManager no está inicializado
      return const LinuxDistributionInfo(
        id: 'kali',
        name: 'Kali Linux',
        version: 'rolling',
        idLike: 'debian',
        prettyName: 'Kali GNU/Linux Rolling',
        homeUrl: 'https://www.kali.org',
        supportUrl: 'https://www.kali.org/docs/',
      );
    }

    // Leer /etc/os-release del rootfs Kali
    final kaliRoot = _kaliManager.kaliRoot;
    if (kaliRoot != null) {
      final etcOsRelease = File('$kaliRoot/etc/os-release');
      if (await etcOsRelease.exists()) {
        final content = await etcOsRelease.readAsString();
        final osRelease = _parseOsRelease(content);
        return LinuxDistributionInfo.fromOsRelease(osRelease);
      }
    }

    // Fallback si /etc/os-release no existe
    return const LinuxDistributionInfo(
      id: 'kali',
      name: 'Kali Linux',
      version: 'rolling',
      idLike: 'debian',
      prettyName: 'Kali GNU/Linux Rolling',
      homeUrl: 'https://www.kali.org',
      supportUrl: 'https://www.kali.org/docs/',
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
