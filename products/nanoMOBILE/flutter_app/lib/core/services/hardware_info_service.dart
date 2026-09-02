import 'dart:io';
import 'package:flutter/foundation.dart';

import 'nano_runtime_api.dart';

/// Servicio de información de hardware del device.
///
/// Extraído de _TermState (SRP). Encapsula lecturas de sysfs, thermal zones,
/// GPU info, y device identity via MethodChannel. Sin dependencias de Flutter
/// Widgets — puro dart:io + platform channel.
class HardwareInfoService {
  Map<String, dynamic>? _devId;

  /// Identidad del device (uid, uname, hostname, meminfo...) poblada async.
  Map<String, dynamic>? get deviceId => _devId;

  /// Obtiene identidad real del device desde la plataforma.
  Future<void> fetchDeviceIdentity() async {
    try {
      final raw = await NanoRuntimeApi.instance.getDeviceIdentity();
      if (raw == null) {
        _devId = null;
        return;
      }
      _devId = raw.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {
      _devId = null;
    }
  }

  /// Lee temperatura del CPU desde thermal_zones del kernel Linux.
  /// Prueba varias rutas comunes en Android (Snapdragon, Mediatek, Exynos).
  /// Retorna °C o null si ninguna ruta es legible.
  /// AND-003 FIX: Ejecuta en isolate para no bloquear el UI thread con syscalls síncronos.
  Future<double?> readCpuTemp() async {
    return await compute(_readCpuTempSync, null);
  }

  /// Implementación síncrona interna (ejecutada en isolate).
  static double? _readCpuTempSync(void _) {
    const paths = [
      '/sys/class/thermal/thermal_zone0/temp',
      '/sys/class/thermal/thermal_zone1/temp',
      '/sys/devices/virtual/thermal/thermal_zone0/temp',
      '/sys/class/hwmon/hwmon0/temp1_input',
    ];
    for (final p in paths) {
      try {
        final raw = File(p).readAsStringSync().trim();
        final v = double.tryParse(raw);
        if (v == null) continue;
        // > 200 probablemente es millidegrees (ej: 38500 = 38.5°C)
        return v > 200 ? v / 1000.0 : v;
      } catch (_) {}
    }
    return null;
  }

  /// Lee información de GPU desde /sys/class/kgsl/kgsl-3d0/ (Adreno)
  /// o /sys/kernel/gpu/ (Mali). Retorna Map con name, freqMhz, tempC,
  /// gpuLoad, gpuMemMb. Campos ausentes si la ruta no existe en el device.
  Map<String, dynamic> readGpuInfo() {
    return _readGpuInfoSync(_devId);
  }

  /// Implementación síncrona interna
  static Map<String, dynamic> _readGpuInfoSync(Map<String, dynamic>? devId) {
    final info = <String, dynamic>{};
    // Adreno (Qualcomm Snapdragon)
    const kgslBase = '/sys/class/kgsl/kgsl-3d0';
    try {
      final gpuclk = File('$kgslBase/gpuclk').readAsStringSync().trim();
      final hz = int.tryParse(gpuclk);
      if (hz != null) info['freqMhz'] = (hz / 1000000).round();
    } catch (_) {}
    try {
      final gpuBusy = File('$kgslBase/gpubusy').readAsStringSync().trim();
      final parts = gpuBusy.split(RegExp(r'\s+'));
      if (parts.length == 2) {
        final busy = double.tryParse(parts[0]);
        final total = double.tryParse(parts[1]);
        if (busy != null && total != null && total > 0) {
          info['gpuLoad'] = (busy / total * 100).roundToDouble();
        }
      }
    } catch (_) {}
    try {
      final devfreq = File(
        '$kgslBase/devfreq/cur_freq',
      ).readAsStringSync().trim();
      final hz = int.tryParse(devfreq);
      if (hz != null && !info.containsKey('freqMhz')) {
        info['freqMhz'] = (hz / 1000000).round();
      }
    } catch (_) {}
    // GPU temperature (thermal_zone varies by device)
    const tempZones = [
      '/sys/class/kgsl/kgsl-3d0/temp',
      '/sys/class/thermal/thermal_zone2/temp',
      '/sys/class/thermal/thermal_zone5/temp',
    ];
    for (final p in tempZones) {
      try {
        final raw = File(p).readAsStringSync().trim();
        final v = double.tryParse(raw);
        if (v != null) {
          info['tempC'] = v > 200 ? v / 1000.0 : v;
          break;
        }
      } catch (_) {}
    }
    // GPU name from dtb/model or fallback to SoC
    try {
      final nameFile = File('$kgslBase/name');
      if (nameFile.existsSync()) {
        info['name'] = nameFile.readAsStringSync().trim();
      }
    } catch (_) {}
    // Legacy Mali GPU path
    if (!info.containsKey('name')) {
      try {
        final mali = File('/sys/kernel/gpu/gpu_model');
        if (mali.existsSync()) info['name'] = mali.readAsStringSync().trim();
      } catch (_) {}
    }
    // Fallback: detectar del cpuHardware
    if (!info.containsKey('name')) {
      final hw = devId?['cpuHardware'] as String? ?? '';
      if (hw.contains('SDM') || hw.contains('SM') || hw.contains('SC')) {
        info['name'] = 'Adreno';
      } else if (hw.contains('MT')) {
        info['name'] = 'Mali';
      } else if (hw.contains('Exynos')) {
        info['name'] = 'Mali';
      }
    }
    // GPU dedicated memory: el sysfs de kgsl expone el descriptor pero no un
    // tamaño portable en bytes (varía por SoC). No se inventa un valor fijo
    // (antes 512 hardcodeado): sin lectura real, el campo no se reporta.
    return info;
  }
}
