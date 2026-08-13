import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DesktopStatus {
  final bool running;
  final bool reachable;
  final int port;

  /// Binario Xvnc presente en el rootfs (instalación gráfica completa).
  final bool installed;

  /// Extras gráficos presentes (dbus/pcmanfm/feh/mousepad). Si faltan, la
  /// pantalla de lanzamiento dispara installGraphical incremental.
  final bool graphicalExtras;

  /// Etapa real del arranque (idle/starting/xvnc/rfb/wm/ready/failed/stopped).
  final String stage;

  /// Último error del backend si stage == failed.
  final String? lastError;

  const DesktopStatus({
    required this.running,
    required this.reachable,
    required this.port,
    this.installed = false,
    this.graphicalExtras = false,
    this.stage = 'idle',
    this.lastError,
  });

  bool get ready => reachable;
  bool get failed => stage == 'failed';

  static const offline = DesktopStatus(
    running: false,
    reachable: false,
    port: 5901,
  );

  factory DesktopStatus.fromMap(Map<dynamic, dynamic>? raw) {
    if (raw == null) return offline;
    return DesktopStatus(
      running: raw['running'] == true,
      reachable: raw['reachable'] == true,
      port: raw['port'] as int? ?? 5901,
      installed: raw['installed'] == true,
      graphicalExtras: raw['graphicalExtras'] == true,
      stage: raw['stage'] as String? ?? 'idle',
      lastError: raw['lastError'] as String?,
    );
  }
}

class PackageService {
  static const _channel = MethodChannel('com.nanoai/exec_bin');

  const PackageService();

  Future<bool> installPackages(List<String> packages) async {
    try {
      final resp = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'installPackages',
        {'packages': packages},
      );
      return resp?['installed'] == true;
    } catch (e) {
      debugPrint('[pkg] installPackages error: $e');
      return false;
    }
  }

  Future<bool> installGraphical() async {
    try {
      final resp = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'installGraphical',
        {},
      );
      return resp?['installed'] == true;
    } catch (e) {
      debugPrint('[pkg] installGraphical error: $e');
      return false;
    }
  }

  Future<bool> startDesktop() async {
    try {
      // El channel Kotlin responde result.success(true) (Boolean), no Map.
      // El cast viejo a Map<dynamic, dynamic> lanzaba
      // "type 'bool' is not a subtype of type 'Map<dynamic, dynamic>?'"
      // en cada arranque del desktop.
      final ok = await _channel.invokeMethod<bool>('startDesktop', {});
      return ok == true;
    } catch (e) {
      debugPrint('[desktop] startDesktop error: $e');
      return false;
    }
  }

  Future<DesktopStatus> getDesktopStatus() async {
    try {
      final resp = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getDesktopStatus',
        {},
      );
      return DesktopStatus.fromMap(resp);
    } catch (e) {
      debugPrint('[desktop] getDesktopStatus error: $e');
      return DesktopStatus.offline;
    }
  }

  Future<void> stopDesktop() async {
    try {
      await _channel.invokeMethod('stopDesktop', {});
    } catch (e) {
      debugPrint('[desktop] stopDesktop error: $e');
    }
  }
}
