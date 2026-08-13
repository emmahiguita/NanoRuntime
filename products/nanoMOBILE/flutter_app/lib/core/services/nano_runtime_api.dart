import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Nombres de canales — espejo Dart de `ChannelNames.kt`.
///
/// Frontera única Flutter↔NanoRuntime. Los servicios de dominio deben llamar
/// a [NanoRuntimeApi] (o usar estas constantes) en vez de repetir strings.
abstract final class NanoRuntimeChannels {
  static const runtime = 'com.nanoai/runtime';
  static const execBin = 'com.nanoai/exec_bin';
  static const pty = 'com.nanoai/pty';
  static const deviceMetrics = 'com.nanoai/device_metrics';
  static const navigation = 'com.nanoai/navigation';
}

/// Resultado del handshake de runtime.
class RuntimeInfo {
  /// false cuando el runtime no responde (tests, desktop, engine sin nativo).
  final bool available;

  /// Versión reportada por `getRuntimeVersion`. 0 si no disponible.
  final int version;

  /// Capacidades reportadas por `getCapabilities`.
  final Set<String> capabilities;

  /// Warning no fatal cuando las versiones Dart/nativo difieren.
  final String? warning;

  const RuntimeInfo._({
    required this.available,
    required this.version,
    required this.capabilities,
    this.warning,
  });

  const RuntimeInfo.unavailable()
    : available = false,
      version = 0,
      capabilities = const {},
      warning = null;

  bool supports(String capability) => capabilities.contains(capability);
}

/// Fachada única sobre el runtime nativo (worker, rootfs, desktop, PTY).
///
/// Única puerta de entrada de la UI hacia los canales `exec_bin`, `pty` y
/// `device_metrics`. El handshake consulta `com.nanoai/runtime` una sola vez
/// (memoizado) y degrada con warning si las versiones difieren — nunca lanza.
///
/// Contrato del canal en Kotlin:
/// `android/.../channels/RuntimeChannelHandler.kt` (RUNTIME_VERSION).
class NanoRuntimeApi {
  NanoRuntimeApi._();

  static final NanoRuntimeApi instance = NanoRuntimeApi._();

  /// Versión de contrato que este Dart conoce. Debe coincidir con
  /// `RuntimeChannelHandler.RUNTIME_VERSION` en Kotlin.
  static const supportedRuntimeVersion = 1;

  static const _runtime = MethodChannel(NanoRuntimeChannels.runtime);
  static const _exec = MethodChannel(NanoRuntimeChannels.execBin);
  static const _pty = MethodChannel(NanoRuntimeChannels.pty);
  static const _metrics = MethodChannel(NanoRuntimeChannels.deviceMetrics);

  Future<RuntimeInfo>? _handshake;

  /// Handshake memoizado: se ejecuta una sola vez por proceso.
  Future<RuntimeInfo> handshake() => _handshake ??= _doHandshake();

  Future<RuntimeInfo> _doHandshake() async {
    try {
      final version = await _runtime.invokeMethod<int>('getRuntimeVersion');
      final caps =
          (await _runtime.invokeListMethod<String>('getCapabilities')) ??
          const <String>[];
      String? warning;
      if (version == null || version == 0) {
        warning = 'runtime no reportó versión';
      } else if (version > supportedRuntimeVersion) {
        warning =
            'runtime nativo v$version más nuevo que Dart '
            'v$supportedRuntimeVersion — actualizar app';
      } else if (version < supportedRuntimeVersion) {
        warning =
            'runtime nativo v$version más viejo que Dart '
            'v$supportedRuntimeVersion — actualizar runtime';
      }
      debugPrint(
        '[runtime] handshake v${version ?? "?"} '
        'caps=${caps.join(",")}${warning != null ? " WARN: $warning" : ""}',
      );
      return RuntimeInfo._(
        available: true,
        version: version ?? 0,
        capabilities: caps.toSet(),
        warning: warning,
      );
    } on MissingPluginException {
      return _unavailable('MissingPluginException');
    } on PlatformException catch (e) {
      return _unavailable(e.code);
    } catch (e) {
      return _unavailable('$e');
    }
  }

  RuntimeInfo _unavailable(String reason) {
    debugPrint('[runtime] handshake no disponible: $reason');
    return const RuntimeInfo.unavailable();
  }

  // ── rootfs ──

  /// Ruta base `files/nano/` del sandbox. Null si el canal no responde.
  Future<String?> getFilesDir() async {
    try {
      return await _exec.invokeMethod<String>('getFilesDir');
    } catch (e) {
      debugPrint('[runtime] getFilesDir error: $e');
      return null;
    }
  }

  Future<bool> downloadBootstrap(String url) async {
    try {
      return await _exec.invokeMethod<bool>('downloadBootstrap', url) == true;
    } catch (e) {
      debugPrint('[runtime] downloadBootstrap error: $e');
      return false;
    }
  }

  /// Extrae un bootstrap zip. Retorna archivos extraídos, -1 en fallo.
  Future<int> extractBootstrap(String zipPath, String destDir) async {
    try {
      final resp = await _exec.invokeMethod<Map<dynamic, dynamic>>(
        'extractBootstrap',
        {'zipPath': zipPath, 'destDir': destDir},
      );
      return (resp?['filesExtracted'] as num?)?.toInt() ?? -1;
    } catch (e) {
      debugPrint('[runtime] extractBootstrap error: $e');
      return -1;
    }
  }

  Future<bool> isBootstrapInstalled(String usrDir) async {
    try {
      return await _exec.invokeMethod<bool>('isBootstrapInstalled', usrDir) ==
          true;
    } catch (e) {
      debugPrint('[runtime] isBootstrapInstalled error: $e');
      return false;
    }
  }

  Future<bool> downloadFile(String url, String destPath) async {
    try {
      return await _exec.invokeMethod<bool>('downloadFile', {
        'url': url,
        'destPath': destPath,
      }) == true;
    } catch (e) {
      debugPrint('[runtime] downloadFile error: $e');
      return false;
    }
  }

  // ── exec ──

  Future<bool> makeExecutable(String path) async {
    try {
      return await _exec.invokeMethod<bool>('makeExecutable', path) == true;
    } catch (e) {
      debugPrint('[runtime] makeExecutable error: $e');
      return false;
    }
  }

  /// Ejecuta un binario y captura salida completa. Map {rc, out, err} o null.
  Future<Map<dynamic, dynamic>?> probeExec(
    String path,
    List<String> args,
  ) async {
    try {
      return await _exec.invokeMethod<Map<dynamic, dynamic>>('probeExec', {
        'path': path,
        'args': args,
      });
    } catch (e) {
      debugPrint('[runtime] probeExec error: $e');
      return null;
    }
  }

  // ── worker ──

  /// Spawnea un binario en el proceso `:nanoshell` (sin GPU). Retorna taskId.
  Future<String?> workerSpawn({
    required String binaryPath,
    required List<String> argv,
    Map<String, String>? envp,
    String? ldPreload,
  }) async {
    try {
      final resp = await _exec.invokeMethod<Map<dynamic, dynamic>>(
        'workerSpawn',
        {
          'binaryPath': binaryPath,
          'argv': argv,
          'envp': envp ?? const {},
          'ldPreload': ldPreload,
        },
      );
      return resp?['taskId'] as String?;
    } catch (e) {
      debugPrint('[runtime] workerSpawn error: $e');
      return null;
    }
  }

  Future<bool> workerKill() async {
    try {
      return await _exec.invokeMethod<bool>('workerKill') == true;
    } catch (e) {
      debugPrint('[runtime] workerKill error: $e');
      return false;
    }
  }

  // ── packages / desktop ──

  Future<bool> installPackages(List<String> packages) async {
    try {
      final resp = await _exec.invokeMethod<Map<dynamic, dynamic>>(
        'installPackages',
        {'packages': packages},
      );
      return resp?['installed'] == true;
    } catch (e) {
      debugPrint('[runtime] installPackages error: $e');
      return false;
    }
  }

  Future<bool> installGraphical() async {
    try {
      final resp = await _exec.invokeMethod<Map<dynamic, dynamic>>(
        'installGraphical',
        {},
      );
      return resp?['installed'] == true;
    } catch (e) {
      debugPrint('[runtime] installGraphical error: $e');
      return false;
    }
  }

  /// El canal responde Boolean (no Map). Timeout nativo: 60s.
  Future<bool> startDesktop() async {
    try {
      return await _exec.invokeMethod<bool>('startDesktop', {}) == true;
    } catch (e) {
      debugPrint('[runtime] startDesktop error: $e');
      return false;
    }
  }

  Future<void> stopDesktop() async {
    try {
      await _exec.invokeMethod('stopDesktop', {});
    } catch (e) {
      debugPrint('[runtime] stopDesktop error: $e');
    }
  }

  Future<Map<dynamic, dynamic>?> getDesktopStatus() async {
    try {
      return await _exec.invokeMethod<Map<dynamic, dynamic>>(
        'getDesktopStatus',
        {},
      );
    } catch (e) {
      debugPrint('[runtime] getDesktopStatus error: $e');
      return null;
    }
  }

  // ── pty (primitivas; PtySession las consume) ──

  Future<num?> ptySpawn({
    required List<String> argv,
    Map<String, String>? envp,
    String? ldPreload,
    int rows = 24,
    int cols = 80,
  }) async {
    try {
      return await _pty.invokeMethod<num?>('ptySpawn', {
        'argv': argv,
        'envp': envp ?? const {},
        'ldPreload': ldPreload,
        'rows': rows,
        'cols': cols,
      });
    } catch (e) {
      debugPrint('[runtime] ptySpawn error: $e');
      return null;
    }
  }

  Future<int> ptyWrite(int id, Uint8List data) async {
    try {
      return await _pty.invokeMethod<int>('ptyWrite', {
        'id': id,
        'data': data,
      }) ?? 0;
    } catch (e) {
      debugPrint('[runtime] ptyWrite error: $e');
      return 0;
    }
  }

  Future<Uint8List?> ptyRead(int id, {int maxBytes = 4096}) async {
    try {
      return await _pty.invokeMethod<Uint8List?>('ptyRead', {
        'id': id,
        'maxBytes': maxBytes,
      });
    } catch (e) {
      debugPrint('[runtime] ptyRead error: $e');
      return null;
    }
  }

  Future<void> ptyResize(int id, int rows, int cols) async {
    try {
      await _pty.invokeMethod('ptyResize', {'id': id, 'rows': rows, 'cols': cols});
    } catch (e) {
      debugPrint('[runtime] ptyResize error: $e');
    }
  }

  Future<void> ptyKill(int id, {int signal = 2}) async {
    try {
      await _pty.invokeMethod('ptyKill', {'id': id, 'signal': signal});
    } catch (e) {
      debugPrint('[runtime] ptyKill error: $e');
    }
  }

  Future<void> ptyClose(int id) async {
    try {
      await _pty.invokeMethod('ptyClose', {'id': id});
    } catch (e) {
      debugPrint('[runtime] ptyClose error: $e');
    }
  }

  Future<int?> ptyGetPid(int id) async {
    try {
      return await _pty.invokeMethod<int>('ptyGetPid', {'id': id});
    } catch (e) {
      debugPrint('[runtime] ptyGetPid error: $e');
      return null;
    }
  }

  Future<int> ptyIsAlive(int id) async {
    try {
      return await _pty.invokeMethod<int>('ptyIsAlive', {'id': id}) ?? 1;
    } catch (e) {
      debugPrint('[runtime] ptyIsAlive error: $e');
      // Fallo = asumir vivo: el caller sigue haciendo polling en vez de
      // marcar la sesión como terminada por un error de canal.
      return 1;
    }
  }

  // ── device metrics ──

  Future<Map<dynamic, dynamic>?> getMetrics() async {
    try {
      return await _metrics.invokeMethod<Map<dynamic, dynamic>>('getMetrics');
    } catch (e) {
      debugPrint('[runtime] getMetrics error: $e');
      return null;
    }
  }

  Future<Map<dynamic, dynamic>?> getDeviceIdentity() async {
    try {
      return await _metrics.invokeMethod<Map<dynamic, dynamic>>(
        'getDeviceIdentity',
      );
    } catch (e) {
      debugPrint('[runtime] getDeviceIdentity error: $e');
      return null;
    }
  }
}
