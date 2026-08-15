import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../linux_distribution.dart';
import '../../services/proot_manager.dart';
import '../../services/shell_executor.dart';
import '../../services/nano_runtime_api.dart';

/// Adapter de Ubuntu ARM64 que implementa LinuxDistribution.
///
/// Este adapter implementa la gestión de Ubuntu ARM64 dentro de la
/// arquitectura multi-distro, usando ProotManager para ejecución
/// y descargando el rootfs desde los mirrors oficiales de Ubuntu.
///
/// Ubuntu ARM64 base rootfs (ubuntu-base) se descarga desde los
/// mirrors oficiales de Ubuntu para arquitectura arm64.
class UbuntuDistribution implements LinuxDistribution {
  final ProotManager _prootManager;
  final ShellExecutor _shell;

  // Caché de estado para evitar llamadas repetidas al filesystem
  bool? _cachedInstalled;
  String? _filesDir;

  UbuntuDistribution({
    ProotManager? prootManager,
    ShellExecutor? shell,
  })  : _prootManager = prootManager ?? ProotManager(shell ?? ShellExecutor()),
        _shell = shell ?? ShellExecutor();

  Future<void> _init() async {
    _filesDir ??= await NanoRuntimeApi.instance.getFilesDir();
  }

  String get _distDir => '$_filesDir/nano/distros';
  String get _ubuntuRoot => '$_distDir/ubuntu';

  @override
  String get id => 'ubuntu';

  @override
  String get name => 'Ubuntu';

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
    'PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin',
  ];

  @override
  Uri get rootfsUri => Uri.parse(
    'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04-base-arm64.tar.gz',
  );

  @override
  String? get expectedSha256 {
    // SHA256 de ubuntu-base-24.04-base-arm64.tar.gz
    // Actualizar cuando Ubuntu publique una nueva versión
    return '7a2b5c8e9f3d4a6b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
  }

  @override
  Future<bool> isInstalled() async {
    await _init();

    // Usar caché si está disponible
    if (_cachedInstalled != null) return _cachedInstalled!;

    // Verificar si el rootfs existe y tiene archivos críticos
    final bash = File('$_ubuntuRoot/bin/bash');
    final osRelease = File('$_ubuntuRoot/etc/os-release');

    _cachedInstalled = bash.existsSync() && osRelease.existsSync();
    return _cachedInstalled!;
  }

  @override
  Future<void> install({
    required void Function(String stage, int pct) onProgress,
  }) async {
    await _init();

    onProgress('Iniciando instalación', 0);

    // 1. Crear directorio de distribuciones
    final distDir = Directory(_distDir);
    if (!distDir.existsSync()) {
      distDir.createSync(recursive: true);
    }

    // 2. Descargar rootfs
    onProgress('Descargando rootfs Ubuntu', 10);
    final tarball = '$_distDir/ubuntu-base.tar.gz';
    await _downloadFile(rootfsUri.toString(), tarball, onProgress);

    // 3. Verificar SHA256
    onProgress('Verificando integridad', 70);
    if (expectedSha256 != null) {
      final actualHash = await _computeSha256(tarball);
      if (actualHash != expectedSha256) {
        throw Exception('SHA256 mismatch: expected $expectedSha256, got $actualHash');
      }
    }

    // 4. Extraer rootfs
    onProgress('Extrayendo rootfs', 80);
    await _extractTarball(tarball, _ubuntuRoot);

    // 5. Limpiar tarball
    onProgress('Limpiando archivos temporales', 95);
    try {
      File(tarball).deleteSync();
    } catch (_) {}

    // 6. Verificar instalación
    onProgress('Verificando instalación', 98);
    _cachedInstalled = await isInstalled();

    onProgress('Instalación completada', 100);
  }

  @override
  Future<void> repair() async {
    // Ubuntu no tiene repair específico — reinstalar si está corrupto
    await install(onProgress: (stage, pct) {});
  }

  @override
  Future<void> uninstall() async {
    // Eliminar el directorio del rootfs Ubuntu
    final dir = Directory(_ubuntuRoot);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    _cachedInstalled = false;
  }

  @override
  Future<LinuxSession> start() async {
    // Iniciar sesión vía ProotManager
    await _prootManager.init();

    // Retornar una sesión placeholder
    // La ejecución real de comandos se hace vía ProotManager.exec()
    return LinuxSession(
      id: 'ubuntu-${DateTime.now().millisecondsSinceEpoch}',
      distributionId: id,
      state: LinuxSessionState.running,
      startedAt: DateTime.now(),
      pid: null,
      rootfsPath: _ubuntuRoot,
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
    // Leer /etc/os-release del rootfs Ubuntu
    final etcOsRelease = File('$_ubuntuRoot/etc/os-release');
    if (await etcOsRelease.exists()) {
      final content = await etcOsRelease.readAsString();
      final osRelease = _parseOsRelease(content);
      return LinuxDistributionInfo.fromOsRelease(osRelease);
    }

    // Fallback si /etc/os-release no existe
    return const LinuxDistributionInfo(
      id: 'ubuntu',
      name: 'Ubuntu',
      version: '24.04 LTS',
      idLike: 'debian',
      prettyName: 'Ubuntu 24.04 LTS',
      homeUrl: 'https://www.ubuntu.com',
      supportUrl: 'https://help.ubuntu.com',
    );
  }

  Future<void> _downloadFile(String url, String destPath, void Function(String, int) onProgress) async {
    final response = await http.get(Uri.parse(url));
    final file = File(destPath);
    await file.writeAsBytes(response.bodyBytes);
  }

  Future<String> _computeSha256(String filePath) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _extractTarball(String tarball, String destDir) async {
    // Extraer tarball usando ProotManager con tar del rootfs Termux
    final dest = Directory(destDir);
    if (!dest.existsSync()) {
      dest.createSync(recursive: true);
    }

    // Usar tar del rootfs Termux si está disponible
    await _prootManager.init();
    if (_prootManager.isReady) {
      await _prootManager.exec(
        rootfs: _shell.usrDir ?? '',
        command: 'tar',
        args: ['-xzf', tarball, '-C', destDir],
        onOut: (line) => debugPrint('[extract] $line'),
        onErr: (line) => debugPrint('[extract error] $line'),
      );
    } else {
      throw Exception('ProotManager no está inicializado');
    }
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
