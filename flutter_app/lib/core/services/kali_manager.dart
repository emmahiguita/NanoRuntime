import 'dart:io';
import 'package:flutter/services.dart';
import 'proot_manager.dart';
import 'shell_executor.dart';

/// Gestiona la instalación y ejecución de Kali Linux ARM64 dentro de un rootfs
/// aislado vía proot.
///
/// Flujo:
///   1. kali install → descarga kalifs-arm64-minimal.tar.xz (~200 MB)
///   2. kali extract → extrae el rootfs en files/nano/distros/kali/
///   3. kali shell → lanza bash dentro de Kali vía proot
///   4. kali run <cmd> → ejecuta un comando dentro de Kali
class KaliManager {
  static const _channel = MethodChannel('com.nanoai/exec_bin');

  /// Kali ARM64 minimal rootfs (basado en Debian, ~200MB).
  /// URL del build oficial de Kali NetHunter para ARM64.
  static const rootfsUrl =
      'https://kali.download/nethunter-images/current/rootfs/kalifs-arm64-minimal.tar.xz';

  final ProotManager _proot;
  final ShellExecutor _shell;
  String? _distDir; // files/nano/distros/
  String? _kaliRoot; // files/nano/distros/kali/
  bool _installed = false;
  bool _downloading = false;

  bool get isInstalled => _installed;
  bool get isDownloading => _downloading;
  String? get kaliRoot => _kaliRoot;

  final void Function(String msg)? onLog;

  KaliManager({required ProotManager proot, required ShellExecutor shell, this.onLog})
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
      await _channel.invokeMethod('downloadFile', {
        'url': rootfsUrl,
        'destPath': tarball,
      });
      onProgress('download', 100);

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

  void log(String msg) => onLog?.call(msg);

  Future<void> _resolveDirs() async {
    try {
      final base = await _channel.invokeMethod<String>('getFilesDir');
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
