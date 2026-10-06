import 'dart:io';

import 'nano_runtime_api.dart';
import 'sha256_file.dart';
import 'proot_manager.dart';
import '../../features/terminal/i_bin_executor.dart';

/// Gestiona la instalación y ejecución de Ubuntu Linux ARM64 dentro de un rootfs
/// aislado vía proot.
///
/// Flujo:
///   1. Ubuntu install → descarga Ubuntufs-arm64-minimal.tar.xz (~200 MB)
///   2. Ubuntu extract → extrae el rootfs en files/nano/distros/Ubuntu/
///   3. Ubuntu shell → lanza bash dentro de Ubuntu vía proot
///   4. Ubuntu run <cmd> → ejecuta un comando dentro de Ubuntu
class UbuntuManager {
  static const Map<String, List<String>> auditGroups = {
    'Base': ['bash', 'coreutils', 'util-linux', 'procps', 'psmisc', 'file'],
    'Shell': ['vim', 'nano', 'less', 'more', 'man-db', 'tmux', 'screen'],
    'Net': ['openssh', 'curl', 'wget', 'rsync', 'netcat-openbsd', 'socat'],
    'Audit': ['nmap', 'tcpdump', 'sqlite', 'openssl', 'gpg', 'gnupg'],
    'Dev': [
      'git',
      'python3',
      'perl',
      'ruby',
      'nodejs',
      'npm',
      'cargo',
      'gcc',
      'make',
    ],
    'Web': ['lynx', 'w3m'],
  };

  /// Ubuntu ARM64 minimal rootfs oficial (Ubuntu Base 24.04.5 LTS ARM64).
  ///
  /// QUÉ HACE:
  /// Define la dirección URL segura (HTTPS) desde los servidores oficiales de Canonical
  /// para descargar la imagen base mínima de Ubuntu para arquitecturas ARM64 (móviles).
  ///
  /// POR QUÉ:
  /// Usar HTTPS previene ataques de Man-in-the-Middle (MITM). La versión 24.04.5
  /// es la versión LTS activa verificada en cdimage.ubuntu.com.
  static const rootfsUrl =
      'https://cdimage.ubuntu.com/ubuntu-base/releases/24.04/release/ubuntu-base-24.04.5-base-arm64.tar.gz';

  /// Hash criptográfico SHA-256 oficial verificado.
  ///
  /// CÓMO FUNCIONA:
  /// Cada byte del archivo descargado se pasa por el algoritmo SHA-256. El resultado
  /// debe coincidir exactamente con este valor publicado por Canonical en SHA256SUMS.
  /// Si un solo bit es alterado o se descarga corrupto, la instalación aborta (Fail-Closed).
  static const expectedSha256 =
      'a91d5a93010193712d346d761372b7c9db6dfcf093893161c64ca107f05914f2';

  final ProotManager _proot;
  final IBinExecutor _shell;
  String? _distDir; // files/nano/distros/
  String? _ubuntuRoot; // files/nano/distros/Ubuntu/
  bool _installed = false;
  bool _downloading = false;

  bool get isInstalled => _installed;
  bool get isDownloading => _downloading;
  String? get ubuntuRoot => _ubuntuRoot;

  /// Termina cualquier proceso de PRoot activo en este entorno.
  void stop() => _proot.killAll();

  final void Function(String msg)? onLog;

  UbuntuManager({
    required ProotManager proot,
    required IBinExecutor shell,
    this.onLog,
  }) : _proot = proot,
       _shell = shell;

  /// Verifica si Ubuntu está instalado comprobando múltiples archivos críticos.
  /// Solo verificar /bin/bash es insuficiente: una extracción parcial puede
  /// dejar ese archivo presente mientras el resto del rootfs está incompleto.
  Future<bool> checkInstalled() async {
    if (_ubuntuRoot == null) await _resolveDirs();
    if (_ubuntuRoot == null) return false;
    // Check a set of critical paths that are present in a healthy rootfs.
    const criticalPaths = [
      'bin/bash',
      'bin/sh',
      'usr/bin/apt-get',
      'etc/os-release',
    ];
    for (final rel in criticalPaths) {
      if (!File('$_ubuntuRoot/$rel').existsSync()) {
        _installed = false;
        return false;
      }
    }
    _installed = true;
    return true;
  }

  /// Descarga y extrae el rootfs de Ubuntu Linux.
  Future<bool> install(void Function(String stage, int pct) onProgress) async {
    if (_installed) return true;
    if (_ubuntuRoot == null) await _resolveDirs();
    if (_ubuntuRoot == null) return false;

    final base = _distDir!;
    // El archivo oficial es un tarball comprimido con gzip (.tar.gz)
    final tarball = '$base/ubuntufs-arm64.tar.gz';

    _downloading = true;
    onProgress('download', 0);

    try {
      // 1. Descargar rootfs oficial (~200 MB)
      await NanoRuntimeApi.instance.downloadFile(rootfsUrl, tarball);
      onProgress('download', 100);

      // P2 fail-closed: verificar integridad criptográfica antes de descomprimir.
      // Si el archivo no existe o el SHA256 no coincide, se aborta la instalación.
      final tarballFile = File(tarball);
      if (!tarballFile.existsSync()) {
        log('Error: tarball no encontrado tras la descarga');
        return false;
      }

      if (expectedSha256.isNotEmpty) {
        // Verificar suma de comprobación SHA256 mediante streaming para evitar sobrecarga de RAM
        onProgress('verify', 0);
        log('Verificando integridad del RootFS (SHA-256)...');
        final actualHash = await sha256File(tarball);
        if (actualHash != expectedSha256) {
          log('SEGURIDAD: ¡El hash SHA-256 no coincide!');
          log('  Esperado: $expectedSha256');
          log('  Obtenido: $actualHash');
          log('  El archivo descargado podría estar corrupto o alterado.');
          log('  Instalación abortada por seguridad.');
          try {
            tarballFile.deleteSync();
          } catch (_) {}
          onProgress('error', 0);
          return false;
        }
        log('Integridad del RootFS verificada con éxito (SHA-256 válido).');
        onProgress('verify', 100);
      } else {
        log('WARNING: Instalando Ubuntu sin verificar el SHA256 (desarrollo).');
      }

      // 2. Extraer tarball con staging atómico para evitar rootfs corrupto
      // si la extracción se cancela o falla a la mitad.
      onProgress('extract', 0);

      final stagingDir = '${_distDir!}/.Ubuntu-staging';
      // Limpiar staging previo si existe (extracción interrumpida anterior).
      try {
        Directory(stagingDir).deleteSync(recursive: true);
      } catch (_) {}
      Directory(stagingDir).createSync(recursive: true);

      log('Extrayendo Ubuntu rootfs (~200 MB, puede tardar ~1-2 min)...');

      // CORRECCIÓN TÉCNICA: El paquete es .tar.gz (GZIP), no .tar.xz (XZ).
      // Usar gzip -dc o tar -xzf previene el error "format not recognized" de xz.
      final bashResult = await _shell.bash(
        'cd "$stagingDir" && gzip -dc "$tarball" | tar -x',
        timeout: const Duration(minutes: 5),
      );
      if (bashResult.exitCode != 0) {
        log(
          'Extracción fallida (exit=${bashResult.exitCode}): ${bashResult.stderr}',
        );
        // Clean up partial staging dir on failure.
        try {
          Directory(stagingDir).deleteSync(recursive: true);
        } catch (_) {}
        return false;
      }

      // Verificar que archivos críticos existen en staging antes de promover.
      const criticalPaths = ['bin/bash', 'bin/sh', 'usr/bin/apt-get'];
      for (final rel in criticalPaths) {
        if (!File('$stagingDir/$rel').existsSync()) {
          log('Staging incompleto: falta $rel. Abortando.');
          try {
            Directory(stagingDir).deleteSync(recursive: true);
          } catch (_) {}
          return false;
        }
      }

      // Promoción atómica: renombrar staging → destino final.
      // Si el destino anterior existe (instalación previa), eliminarlo primero.
      try {
        Directory(_ubuntuRoot!).deleteSync(recursive: true);
      } catch (_) {}
      Directory(stagingDir).renameSync(_ubuntuRoot!);

      onProgress('extract', 100);

      // 3. Configurar DNS para que Ubuntu pueda resolver dominios
      try {
        await File(
          '$_ubuntuRoot/etc/resolv.conf',
        ).writeAsString('nameserver 8.8.8.8\nnameserver 1.1.1.1\n');
      } catch (_) {}

      // 4. Limpiar tarball para ahorrar espacio
      try {
        File(tarball).deleteSync();
      } catch (_) {}

      _installed = await checkInstalled();
      onProgress('done', _installed ? 100 : 0);
      return _installed;
    } catch (e) {
      log('Error: $e');
      onProgress('error', 0);
      return false;
    } finally {
      _downloading = false;
    }
  }

  /// Lanza un comando dentro de Ubuntu vía proot con streaming.
  Future<int> run(
    String command,
    List<String> args, {
    void Function(String line)? onOut,
    void Function(String line)? onErr,
  }) async {
    if (!_installed) {
      onErr?.call('Ubuntu: no instalado. Ejecuta "Ubuntu install" primero.');
      return 1;
    }
    return _proot.exec(
      rootfs: _ubuntuRoot!,
      command: command,
      args: args,
      onOut: onOut,
      onErr: onErr,
    );
  }

  /// Abre una shell interactiva dentro de Ubuntu.
  Future<int> shell({
    void Function(String line)? onOut,
    void Function(String line)? onErr,
  }) async {
    return run(
      '/bin/bash',
      ['-c', 'exec bash --norc'],
      onOut: onOut,
      onErr: onErr,
    );
  }

  Map<String, bool> auditTools() {
    final root = _ubuntuRoot;
    if (root == null) return const {};
    final out = <String, bool>{};
    for (final group in auditGroups.entries) {
      for (final tool in group.value) {
        final candidates = [
          File('$root/bin/$tool'),
          File('$root/usr/bin/$tool'),
          File('$root/usr/sbin/$tool'),
          File('$root/sbin/$tool'),
        ];
        out[tool] = candidates.any((f) => f.existsSync());
      }
    }
    return out;
  }

  List<String> missingTools() {
    final audit = auditTools();
    final missing = audit.entries
        .where((entry) => !entry.value)
        .map((entry) => entry.key)
        .toList();
    missing.sort();
    return missing;
  }

  String coverageSummary() {
    final audit = auditTools();
    if (audit.isEmpty) return 'Ubuntu audit: rootfs no disponible';
    final total = audit.length;
    final installed = audit.values.where((value) => value).length;
    return 'Ubuntu audit: $installed/$total herramientas detectadas';
  }

  void log(String msg) => onLog?.call(msg);

  Future<void> _resolveDirs() async {
    try {
      final base = await NanoRuntimeApi.instance.getFilesDir();
      if (base != null && base.isNotEmpty) {
        _distDir = '$base/distros';
        _ubuntuRoot = '$_distDir/Ubuntu';
      }
    } catch (_) {
      _distDir = null;
      _ubuntuRoot = null;
    }
  }
}

