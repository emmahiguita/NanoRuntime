import 'dart:io';

import 'package:flutter/foundation.dart';

import '../linux_distribution.dart';
import '../../services/sha256_file.dart';
import '../../services/shell_executor.dart';
import '../../services/proot_manager.dart';
import '../../services/nano_runtime_api.dart';
import '../../../features/terminal/i_bin_executor.dart';

/// Adapter de Ubuntu ARM64 que implementa LinuxDistribution.
///
/// Este adapter implementa la gestión de Ubuntu ARM64 dentro de la
/// arquitectura multi-distro. El rootfs ubuntu-base se descarga desde
/// los mirrors oficiales de Ubuntu y se extrae con el mismo patrón que
/// KaliManager: binarios del rootfs Termux ejecutándose nativos (sin
/// jail proot) para que el tarball y el destino sean visibles.
///
/// Flujo de instalación:
///   1. download  — channel nativo (streaming en Kotlin, no RAM)
///   2. verify    — SHA256 fail-closed contra SHA256SUMS oficial
///   3. extract   — tar -xzf a directorio temporal
///   4. configure — DNS + sources.list (ubuntu-base no los trae)
///   5. finalize  — promover tmp a ubicación final (rollback seguro)
class UbuntuDistribution implements LinuxDistribution {
  final IBinExecutor _shell;

  // UBUNTU-EXEC-01: proot es el jail compartido de ejecución (mismo patrón
  // KaliManager). Lazy para reusar _shell sin duplicar instancias.
  ProotManager? _proot;
  ProotManager get _prootMgr => _proot ??= ProotManager(_shell);

  // Caché de estado para evitar llamadas repetidas al filesystem
  bool? _cachedInstalled;
  String? _filesDir;

  UbuntuDistribution({IBinExecutor? shell, ProotManager? proot})
    : _shell = shell ?? ShellExecutor(),
      _proot = proot;

  Future<void> _init() async {
    if (_filesDir != null) return;
    final dir = await NanoRuntimeApi.instance.getFilesDir();
    if (dir == null || dir.isEmpty) {
      throw StateError(
        'getFilesDir no disponible: no se puede operar con el rootfs',
      );
    }
    _filesDir = dir;
  }

  /// getFilesDir() ya retorna `<filesDir>/nano` (Kotlin
  /// ExecBinChannelHandler.handleGetFilesDir) — no añadir /nano de nuevo.
  String get _distDir => '$_filesDir/distros';
  String get _ubuntuRoot => '$_distDir/ubuntu';
  String get _tmpRoot => '$_distDir/.ubuntu-tmp';
  String get _tarball => '$_distDir/ubuntu-base.tar.gz';

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
    'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.4-base-arm64.tar.gz',
  );

  @override
  String? get expectedSha256 {
    // SHA256 de ubuntu-base-24.04.4-base-arm64.tar.gz
    // Verificado contra la fuente oficial el 2026-08-15:
    // https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/SHA256SUMS
    return '04207713ece899c3740823d33690441ad3a7f0ded1101aca744e2b0f37ac7ff2';
  }

  @override
  Future<bool> isInstalled() async {
    await _init();

    // Usar caché si está disponible
    if (_cachedInstalled != null) return _cachedInstalled!;

    // Verificar que el rootfs existe y tiene archivos críticos
    final bash = File('$_ubuntuRoot/bin/bash');
    final osRelease = File('$_ubuntuRoot/etc/os-release');
    final loader = File('$_ubuntuRoot/lib/ld-linux-aarch64.so.1');

    _cachedInstalled =
        bash.existsSync() && osRelease.existsSync() && loader.existsSync();
    return _cachedInstalled!;
  }

  @override
  Future<void> install({
    required void Function(String stage, int pct) onProgress,
  }) async {
    await _init();

    try {
      // 1. Crear directorio de distribuciones
      Directory(_distDir).createSync(recursive: true);

      // 2. Validar URL antes de delegar la descarga al channel nativo
      _validateDownloadUrl(rootfsUri);

      // 3. Descargar rootfs vía channel nativo (streaming en Kotlin,
      //    no carga el tarball en RAM como http.bodyBytes)
      onProgress('download', 0);
      final ok = await NanoRuntimeApi.instance.downloadFile(
        rootfsUri.toString(),
        _tarball,
      );
      if (!ok) {
        throw Exception('Descarga falló: downloadFile retornó false');
      }
      onProgress('download', 100);

      // 4. Verificar SHA256 (fail-closed: sin hash configurado se aborta)
      onProgress('verify', 0);
      if (expectedSha256 == null || expectedSha256!.isEmpty) {
        throw Exception(
          'SHA256 no configurado: no se instala un rootfs sin verificar',
        );
      }
      final actualHash = await _computeSha256(_tarball);
      if (actualHash != expectedSha256) {
        throw Exception(
          'SHA256 mismatch: expected $expectedSha256, got $actualHash',
        );
      }
      onProgress('verify', 100);

      // 5. Extraer a directorio temporal y validar archivos críticos
      onProgress('extract', 0);
      _cleanupDir(_tmpRoot);
      await _extractTarball(_tarball, _tmpRoot);
      _validateRootfs(_tmpRoot);
      onProgress('extract', 100);

      // 6. Configurar antes de promover: ubuntu-base no trae DNS ni
      //    sources.list (debootstrap los genera). Sin esto, apt y DNS
      //    quedan muertos dentro del rootfs.
      onProgress('configure', 0);
      await _writePostInstallConfig(_tmpRoot);
      onProgress('configure', 100);

      // 7. Promover tmp a ubicación final, reemplazando cualquier
      //    instalación previa o parcial. La previa se renombra a
      //    .ubuntu-old ANTES del promote: si el rename nuevo falla,
      //    se restaura la instalación anterior.
      onProgress('finalize', 0);
      final oldRoot = '$_distDir/.ubuntu-old';
      _cleanupDir(oldRoot);
      if (Directory(_ubuntuRoot).existsSync()) {
        Directory(_ubuntuRoot).renameSync(oldRoot);
      }
      try {
        Directory(_tmpRoot).renameSync(_ubuntuRoot);
      } catch (e) {
        // Rollback del promote: restaurar la instalación previa
        if (Directory(oldRoot).existsSync()) {
          Directory(oldRoot).renameSync(_ubuntuRoot);
        }
        rethrow;
      }
      _cleanupDir(oldRoot);
      onProgress('finalize', 100);

      // 8. Limpiar tarball para ahorrar espacio
      _cleanupFile(_tarball);

      // 9. Verificar instalación final desde disco (sin caché)
      _cachedInstalled = null;
      if (!await isInstalled()) {
        throw Exception('Instalación no verificada: faltan archivos críticos');
      }

      onProgress('done', 100);
    } catch (e) {
      // Rollback: no dejar rootfs temporal ni tarball parcial
      _cleanupDir(_tmpRoot);
      _cleanupFile(_tarball);
      _cachedInstalled = null;
      rethrow;
    }
  }

  @override
  Future<void> repair() async {
    // No hay repair incremental: limpiar estado corrupto y reinstalar
    await uninstall();
    await install(onProgress: (stage, pct) {});
  }

  @override
  Future<void> uninstall() async {
    await _init();
    // Eliminar rootfs, temporales y tarball residual
    _cleanupDir(_ubuntuRoot);
    _cleanupDir(_tmpRoot);
    _cleanupDir('$_distDir/.ubuntu-old');
    _cleanupFile(_tarball);
    _cachedInstalled = false;
  }

  @override
  Future<LinuxSession> start() async {
    await _init();
    // Patrón del codebase: la ejecución real de comandos se hace vía
    // ShellExecutor/ProotManager.exec cuando se necesita.
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

  /// Ejecuta un comando dentro del rootfs Ubuntu vía proot (streaming).
  /// Espejo de KaliManager.run — ProotManager es el jail compartido.
  Future<int> run(
    String command,
    List<String> args, {
    void Function(String line)? onOut,
    void Function(String line)? onErr,
  }) async {
    if (!await isInstalled()) {
      onErr?.call('ubuntu: no instalado. Instálalo desde Nano Linux.');
      return 1;
    }
    return _prootMgr.exec(
      rootfs: _ubuntuRoot,
      command: command,
      args: args,
      onOut: onOut,
      onErr: onErr,
    );
  }

  /// Shell interactiva dentro del rootfs Ubuntu vía proot.
  /// Mismo patrón verificado de KaliManager.shell.
  Future<int> shell({
    void Function(String line)? onOut,
    void Function(String line)? onErr,
  }) {
    return run(
      '/bin/bash',
      const ['-c', 'exec bash --norc'],
      onOut: onOut,
      onErr: onErr,
    );
  }

  @override
  Future<LinuxDistributionInfo> getInfo() async {
    await _init();
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

  /// Valida que la URL de descarga sea HTTPS y de un dominio oficial.
  /// El channel nativo solo descarga; esta capa impone la allowlist.
  void _validateDownloadUrl(Uri uri) {
    if (uri.scheme != 'https') {
      throw Exception('Solo HTTPS está permitido para descargas de seguridad');
    }

    const allowedDomains = [
      'cdimage.ubuntu.com',
      'releases.ubuntu.com',
      'old-releases.ubuntu.com',
      'archive.ubuntu.com',
    ];

    if (!allowedDomains.contains(uri.host)) {
      throw Exception('Dominio no permitido: ${uri.host}');
    }
  }

  /// TER-32: hash streaming compartido (tarball ~35MB sin cargar en RAM).
  Future<String> _computeSha256(String filePath) => sha256File(filePath);

  Future<void> _extractTarball(String tarball, String destDir) async {
    Directory(destDir).createSync(recursive: true);

    // Patrón KaliManager: binarios del rootfs Termux ejecutándose nativos
    // con paths del host visibles. NO usar proot aquí — dentro del jail
    // (rootfs Termux) el tarball y el destino en files/nano/distros/
    // no son visibles y tar muere con "Cannot open".
    final result = await _shell.bash(
      'tar -xzf "$tarball" -C "$destDir"',
      timeout: const Duration(minutes: 5),
    );
    if (result.exitCode != 0) {
      throw Exception(
        'Extracción fallida (exit=${result.exitCode}): ${result.stderr}',
      );
    }
  }

  /// Verifica que el rootfs extraído tenga los archivos críticos para
  /// arrancar: bash, os-release y el loader dinámico arm64.
  void _validateRootfs(String root) {
    final required = [
      '$root/bin/bash',
      '$root/etc/os-release',
      '$root/lib/ld-linux-aarch64.so.1',
    ];
    for (final path in required) {
      if (!File(path).existsSync()) {
        throw Exception('Rootfs incompleto: falta $path');
      }
    }
  }

  /// Configuración mínima para que Ubuntu sea usable:
  /// - /etc/resolv.conf: DNS (ubuntu-base no lo trae)
  /// - /etc/apt/sources.list: mirrors arm64 de noble
  Future<void> _writePostInstallConfig(String root) async {
    await File(
      '$root/etc/resolv.conf',
    ).writeAsString('nameserver 8.8.8.8\nnameserver 1.1.1.1\n');

    // arm64 oficial de Ubuntu usa ports.ubuntu.com (verificado 2026-08-15:
    // ports.ubuntu.com/ubuntu-ports/dists/noble/Release lista arm64)
    final sources = [
      'deb http://ports.ubuntu.com/ubuntu-ports noble main universe',
      'deb http://ports.ubuntu.com/ubuntu-ports noble-updates main universe',
      'deb http://ports.ubuntu.com/ubuntu-ports noble-security main universe',
    ].join('\n');
    await File('$root/etc/apt/sources.list').writeAsString('$sources\n');
  }

  void _cleanupDir(String path) {
    try {
      final dir = Directory(path);
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    } catch (e) {
      debugPrint('[ubuntu] cleanup dir $path: $e');
    }
  }

  void _cleanupFile(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (e) {
      debugPrint('[ubuntu] cleanup file $path: $e');
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
