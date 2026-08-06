import 'dart:io';
import 'package:flutter/services.dart';

/// Ejecuta comandos reales usando bash/toybox extraídos de assets/bin/.
///
/// Flujo:
///   1. Copia bash y toybox de assets al dir privado de la app (files/nano/)
///   2. Los marca ejecutables vía MethodChannel (SELinux permite exec de archivos propios)
///   3. Ejecuta comandos con dart:io Process.run; si SELinux lo bloquea,
///      cae en probeExec del platform channel (ProcessBuilder nativo).
class ShellExecutor {
  static const _channel = MethodChannel('com.nanoai/exec_bin');

  String? _binDir;
  bool _initialized = false;
  bool get initialized => _initialized;
  String? get binDir => _binDir;

  Future<void> init() async {
    if (_initialized) return;
    try {
      _binDir = await _channel.invokeMethod<String>('getFilesDir');
      if (_binDir == null || _binDir!.isEmpty) return;

      await _extractAsset('assets/bin/bash', '$_binDir/bash');
      await _extractAsset('assets/bin/toybox', '$_binDir/toybox');

      await _channel.invokeMethod('makeExecutable', '$_binDir/bash');
      await _channel.invokeMethod('makeExecutable', '$_binDir/toybox');

      _initialized = true;
    } catch (_) {
      // Sin platform channel (p.ej. tests, desktop): sin shell real.
    }
  }

  Future<void> _extractAsset(String assetPath, String destPath) async {
    final dest = File(destPath);
    if (dest.existsSync()) return;
    final data = await rootBundle.load(assetPath);
    await dest.writeAsBytes(data.buffer.asUint8List());
  }

  /// Ejecuta un binario real con argumentos. Retorna stdout, stderr, exitCode.
  /// Prueba dart:io primero; si falla, usa probeExec del platform channel.
  Future<ShellResult> exec(String command, List<String> args,
      {String? workDir}) async {
    if (!_initialized) await init();

    // Intento 1: dart:io Process.run
    try {
      final result = await Process.run(
        command,
        args,
        workingDirectory: workDir ?? _binDir,
        runInShell: false,
      );
      return ShellResult(
        stdout: result.stdout.toString().trim(),
        stderr: result.stderr.toString().trim(),
        exitCode: result.exitCode,
      );
    } catch (e1) {
      // Intento 2: platform channel ProcessBuilder nativo
      try {
        final map = await _channel.invokeMethod('probeExec', {
          'path': command,
          'args': args,
        }) as Map?;
        if (map == null) throw Exception('probeExec null');
        return ShellResult(
          stdout: (map['out'] as String? ?? '').trim(),
          stderr: ((map['err'] as String?) ?? '').trim(),
          exitCode: (map['rc'] as int?) ??
              ((map['error'] as String?) != null ? 127 : 1),
        );
      } catch (e2) {
        return ShellResult(
          stdout: '',
          stderr: 'exec bloqueado: dart=$e1, native=$e2',
          exitCode: 127,
        );
      }
    }
  }

  /// Ejecuta comando vía bash -c.
  Future<ShellResult> bash(String cmd) async {
    if (!_initialized) await init();
    if (_binDir == null) {
      return ShellResult(stdout: '', stderr: 'bash: sin bin dir', exitCode: 1);
    }
    return exec('$_binDir/bash', ['-c', cmd]);
  }

  /// Ejecuta comando vía toybox (multi-call: toybox ls, toybox ps, etc.).
  Future<ShellResult> toybox(List<String> args) async {
    if (!_initialized) await init();
    if (_binDir == null) {
      return ShellResult(
          stdout: '', stderr: 'toybox: sin bin dir', exitCode: 1);
    }
    return exec('$_binDir/toybox', args);
  }
}

class ShellResult {
  final String stdout;
  final String stderr;
  final int exitCode;
  const ShellResult(
      {required this.stdout, required this.stderr, required this.exitCode});
}
