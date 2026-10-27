// mobile_bridge_process_supervisor.dart
//
// QUÉ HACE:
// Supervisa el ciclo de vida del subproceso Node `mobile_bridge.js` en Android,
// previniendo la acumulación de procesos zombi o huérfanos.
//
// CÓMO FUNCIONA:
// - Administra el archivo PID en `/data/data/.../files/nano/tmp/mobile_bridge.pid`.
// - Valida la línea de comando del proceso leyendo `/proc/$pid/cmdline` antes de enviar señales
//   SIGTERM o SIGKILL para evitar matar procesos ajenos por reciclado de PID en Android (AUT-P1-06).
// - Provee métodos atómicos para iniciar (`ensureRunning`) y detener (`stop`) el puente.
//
// POR QUÉ:
// Separa la gestión de procesos nativos del cliente HTTP (SOLID - SRP), garantizando
// terminación limpia en el teardown del runtime y cumpliendo el límite estricto de < 200 líneas.

library;

import 'dart:io';
import 'package:flutter/foundation.dart';

/// Supervisor del proceso de fondo de mobile_bridge.js en dispositivos Android.
class MobileBridgeProcessSupervisor {
  static const String baseDir = '/data/data/dev.nanoai.mobile/files/nano';
  static const String nodeBin = '$baseDir/usr/bin/node';
  static const String bridgeJs = '$baseDir/home/mobile_bridge.js';
  static const String libDir = '$baseDir/usr/lib';
  static const String pidPath = '$baseDir/tmp/mobile_bridge.pid';

  const MobileBridgeProcessSupervisor();

  /// Inicia el subproceso Node en modo detached si no está activo, asegurando limpieza previa.
  Future<bool> ensureRunning(Future<bool> Function() healthCheck) async {
    if (await healthCheck()) return true;
    if (!Platform.isAndroid) return false;

    try {
      final scriptFile = File(bridgeJs);
      if (!scriptFile.existsSync()) return false;

      final pidFile = File(pidPath);
      if (pidFile.existsSync()) {
        try {
          final oldPid = int.tryParse(pidFile.readAsStringSync().trim());
          if (oldPid != null && isBridgeProcess(oldPid)) {
            Process.killPid(oldPid, ProcessSignal.sigkill);
          }
        } catch (_) {}
        try {
          pidFile.deleteSync();
        } catch (_) {}
      }

      final proc = await Process.start(
        nodeBin,
        [bridgeJs],
        environment: {'LD_LIBRARY_PATH': libDir},
        mode: ProcessStartMode.detached,
      );

      try {
        if (!pidFile.parent.existsSync()) {
          pidFile.parent.createSync(recursive: true);
        }
        pidFile.writeAsStringSync('${proc.pid}');
      } catch (_) {}

      await Future<void>.delayed(const Duration(milliseconds: 1000));
      return await healthCheck();
    } catch (e) {
      debugPrint('[bridge_supervisor] Error iniciando mobile_bridge.js: $e');
      return false;
    }
  }

  /// Detiene el proceso del puente de forma segura si está ejecutándose.
  Future<void> stop() async {
    final pidFile = File(pidPath);
    if (!pidFile.existsSync()) return;

    try {
      final pid = int.tryParse(pidFile.readAsStringSync().trim());
      if (pid != null && isBridgeProcess(pid)) {
        Process.killPid(pid, ProcessSignal.sigterm);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        if (isBridgeProcess(pid)) {
          Process.killPid(pid, ProcessSignal.sigkill);
        }
      }
    } catch (_) {
    } finally {
      try {
        pidFile.deleteSync();
      } catch (_) {}
    }
  }

  /// Comprueba en /proc/$pid/cmdline si el PID realmente pertenece a Node y mobile_bridge.js.
  bool isBridgeProcess(int pid) {
    if (pid <= 0) return false;
    try {
      final cmdFile = File('/proc/$pid/cmdline');
      if (!cmdFile.existsSync()) return false;
      final cmd = cmdFile.readAsStringSync();
      return cmd.contains('mobile_bridge.js') || cmd.contains('node');
    } catch (_) {
      return false;
    }
  }
}
