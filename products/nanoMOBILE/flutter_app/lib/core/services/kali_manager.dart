import 'dart:io';
import 'package:crypto/crypto.dart';

import 'nano_runtime_api.dart';
import 'proot_manager.dart';
import '../../features/terminal/i_bin_executor.dart';

/// Gestiona la instalación y ejecución de Kali Linux ARM64 dentro de un rootfs
/// aislado vía proot.
///
/// Flujo:
///   1. kali install → descarga kalifs-arm64-minimal.tar.xz (~200 MB)
///   2. kali extract → extrae el rootfs en files/nano/distros/kali/
///   3. kali shell → lanza bash dentro de Kali vía proot
///   4. kali run <cmd> → ejecuta un comando dentro de Kali
class KaliManager {
  static const Map<String, List<String>> auditGroups = {
    'Base': ['bash', 'coreutils', 'util-linux', 'procps', 'psmisc', 'file'],
    'Shell': ['vim', 'nano', 'less', 'more', 'man-db', 'tmux', 'screen'],
    'Net': ['openssh', 'curl', 'wget', 'rsync', 'netcat-openbsd', 'socat'],
    'Audit': ['nmap', 'tcpdump', 'sqlite', 'openssl', 'gpg', 'gnupg'],
    'Dev': ['git', 'python3', 'perl', 'ruby', 'nodejs', 'npm', 'cargo', 'gcc', 'make'],
    'Web': ['lynx', 'w3m'],
  };
  /// Kali ARM64 minimal rootfs (basado en Debian, ~200MB).
  /// URL del build oficial de Kali NetHunter para ARM64.
  ///
  /// A-22b: la URL anterior (kalifs-arm64-minimal.tar.xz) devolvía HTTP 404
  /// — el naming oficial migró a kali-nethunter-rootfs-* (verificado
  /// 2026-08-13). El hash se lee de SHA256SUMS oficial; fail-closed: si no
  /// coincide o está vacío, la instalación aborta.
  static const rootfsUrl =
      'https://kali.download/nethunter-images/current/rootfs/kali-nethunter-rootfs-minimal-arm64.tar.xz';
  /// SHA256 oficial del tarball (SHA256SUMS, 2026-08-13). Actualizar cuando
  /// Kali publique un build nuevo — NUNCA dejar vacío (instalación aborta).
  /// Fuente: https://kali.download/nethunter-images/current/rootfs/SHA256SUMS
  static const expectedSha256 =
      'd6403a5da175df325611d23af4b92330856059c45454eced7f4cdf3ca6df2e4e';

  final ProotManager _proot;
  final IBinExecutor _shell;
  String? _distDir; // files/nano/distros/
  String? _kaliRoot; // files/nano/distros/kali/
  bool _installed = false;
  bool _downloading = false;

  bool get isInstalled => _installed;
  bool get isDownloading => _downloading;
  String? get kaliRoot => _kaliRoot;

  final void Function(String msg)? onLog;

  KaliManager({required ProotManager proot, required IBinExecutor shell, this.onLog})
      : _proot = proot, _shell = shell;

  /// Verifica si Kali ya está instalado (comprueba /bin/bash dentro del rootfs).
  Future<bool> checkInstalled() async {
    if (_kaliRoot == null) await _resolveDirs();
    if (_kaliRoot == null) return false;
    final bash = File('$_kaliRoot/bin/bash');
    _installed = bash.existsSync();
    return _installed;
  }

  /// Descarga y extrae el rootfs de Kali Linux.
  Future<bool> install(void Function(String stage, int pct) onProgress) async {
    if (_installed) return true;
    if (_kaliRoot == null) await _resolveDirs();
    if (_kaliRoot == null) return false;

    final base = _distDir!;
    final tarball = '$base/kalifs-arm64.tar.xz';

    _downloading = true;
    onProgress('download', 0);

    try {
      // 1. Descargar rootfs (~200 MB)
      await NanoRuntimeApi.instance.downloadFile(rootfsUrl, tarball);
      onProgress('download', 100);

      // P2 fail-closed: instalar un rootfs de ~200MB bajado por HTTP sin
      // verificar su hash es aceptar suministro comprometido o corrupto.
      // Antes '' saltaba la verificación en silencio; ahora aborta.
      // Hash oficial: kali.download/nethunter-images/current/rootfs/SHA256SUMS
      if (expectedSha256.isEmpty) {
        log('ERROR: SHA256 del rootfs no configurado (KaliManager.expectedSha256).');
        log('       Instalación abortada: no se instala un rootfs sin verificar.');
        log('       Fuente oficial: https://kali.download/nethunter-images/current/rootfs/SHA256SUMS');
        onProgress('error', 0);
        return false;
      }

      // Verify SHA256 checksum (obligatorio)
      onProgress('verify', 0);
      log('Verifying rootfs integrity (SHA256)...');
      final tarballFile = File(tarball);
      if (!tarballFile.existsSync()) {
        log('Error: tarball not found after download');
        return false;
      }
      final fileBytes = await tarballFile.readAsBytes();
      final actualHash = sha256.convert(fileBytes).toString();
      if (actualHash != expectedSha256) {
        log('SECURITY: Rootfs checksum mismatch!');
        log('  Expected: $expectedSha256');
        log('  Got:      $actualHash');
        log('  The downloaded file may be corrupted or tampered with.');
        log('  Aborting installation for safety.');
        try { tarballFile.deleteSync(); } catch (_) {}
        onProgress('error', 0);
        return false;
      }
      log('Rootfs integrity verified (SHA256).');
      onProgress('verify', 100);

      // 2. Extraer tarball con proot + tar (más rápido que ZipInputStream)
      onProgress('extract', 0);
      Directory(_kaliRoot!).createSync(recursive: true);

      log('Extrayendo Kali rootfs (~200 MB, puede tardar ~2-3 min)...');

      // toybox no interpreta pipes — usar bash directamente para la extracción.
      // xz -dc descomprime el stream, tar -x extrae los archivos.
      final bashResult = await _shell.bash(
        'cd "$_kaliRoot" && xz -dc "$tarball" | tar -x',
        timeout: const Duration(minutes: 5),
      );
      if (bashResult.exitCode != 0) {
        log('Extracción fallida (exit=${bashResult.exitCode}): ${bashResult.stderr}');
        return false;
      }

      onProgress('extract', 100);

      // 3. Configurar DNS para que Kali pueda resolver dominios
      try {
        await File('$_kaliRoot/etc/resolv.conf')
            .writeAsString('nameserver 8.8.8.8\nnameserver 1.1.1.1\n');
      } catch (_) {}

      // 4. Limpiar tarball para ahorrar espacio
      try { File(tarball).deleteSync(); } catch (_) {}

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

  /// Lanza un comando dentro de Kali vía proot con streaming.
  Future<int> run(
    String command,
    List<String> args, {
    void Function(String line)? onOut,
    void Function(String line)? onErr,
  }) async {
    if (!_installed) {
      onErr?.call('kali: no instalado. Ejecuta "kali install" primero.');
      return 1;
    }
    return _proot.exec(
      rootfs: _kaliRoot!,
      command: command,
      args: args,
      onOut: onOut,
      onErr: onErr,
    );
  }

  /// Abre una shell interactiva dentro de Kali.
  Future<int> shell({
    void Function(String line)? onOut,
    void Function(String line)? onErr,
  }) async {
    return run('/bin/bash', ['-c', 'exec bash --norc'], onOut: onOut, onErr: onErr);
  }

  Map<String, bool> auditTools() {
    final root = _kaliRoot;
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
    final missing = audit.entries.where((entry) => !entry.value).map((entry) => entry.key).toList();
    missing.sort();
    return missing;
  }

  String coverageSummary() {
    final audit = auditTools();
    if (audit.isEmpty) return 'kali audit: rootfs no disponible';
    final total = audit.length;
    final installed = audit.values.where((value) => value).length;
    return 'kali audit: $installed/$total herramientas detectadas';
  }

  void log(String msg) => onLog?.call(msg);

  Future<void> _resolveDirs() async {
    try {
      final base = await NanoRuntimeApi.instance.getFilesDir();
      if (base != null && base.isNotEmpty) {
        _distDir = '$base/distros';
        _kaliRoot = '$_distDir/kali';
      }
    } catch (_) {
      _distDir = null;
      _kaliRoot = null;
    }
  }
}
