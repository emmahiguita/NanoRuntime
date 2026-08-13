import 'package:flutter/foundation.dart';

import 'nano_runtime_api.dart';

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

  /// U-10: el OS mató el runtime en segundo plano (heartbeat vivo sin
  /// apagado limpio). La UI de lanzamiento lo muestra como aviso honesto
  /// de restauración.
  final bool wasKilledByOs;

  const DesktopStatus({
    required this.running,
    required this.reachable,
    required this.port,
    this.installed = false,
    this.graphicalExtras = false,
    this.stage = 'idle',
    this.lastError,
    this.wasKilledByOs = false,
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
      wasKilledByOs: raw['wasKilledByOs'] == true,
    );
  }
}

class PackageService {
  const PackageService();

  /// Delega en [NanoRuntimeApi]: frontera única hacia el canal exec_bin.
  static NanoRuntimeApi get _runtime => NanoRuntimeApi.instance;

  Future<bool> installPackages(List<String> packages) async {
    try {
      return await _runtime.installPackages(packages);
    } catch (e) {
      debugPrint('[pkg] installPackages error: $e');
      return false;
    }
  }

  Future<bool> installGraphical() async {
    try {
      return await _runtime.installGraphical();
    } catch (e) {
      debugPrint('[pkg] installGraphical error: $e');
      return false;
    }
  }

  Future<bool> startDesktop({
    String vncPassword = '',
    int? width,
    int? height,
  }) async {
    try {
      return await _runtime.startDesktop(
        vncPassword: vncPassword,
        width: width,
        height: height,
      );
    } catch (e) {
      debugPrint('[desktop] startDesktop error: $e');
      return false;
    }
  }

  /// Permisos de lectura de medios para el visor de archivos del escritorio.
  Future<bool> requestStoragePermission() async {
    try {
      return await _runtime.requestStoragePermission();
    } catch (e) {
      debugPrint('[desktop] requestStoragePermission error: $e');
      return false;
    }
  }

  Future<DesktopStatus> getDesktopStatus() async {
    try {
      final resp = await _runtime.getDesktopStatus();
      return DesktopStatus.fromMap(resp);
    } catch (e) {
      debugPrint('[desktop] getDesktopStatus error: $e');
      return DesktopStatus.offline;
    }
  }

  Future<void> stopDesktop() async {
    try {
      await _runtime.stopDesktop();
    } catch (e) {
      debugPrint('[desktop] stopDesktop error: $e');
    }
  }

  /// Lanza una app gráfica sobre el escritorio proyectado.
  /// El lado nativo valida contra allowlist (aterm/pcmanfm/mousepad/feh).
  Future<bool> launchApp(String app) async {
    try {
      return await _runtime.launchApp(app);
    } catch (e) {
      debugPrint('[desktop] launchApp($app) error: $e');
      return false;
    }
  }
}
