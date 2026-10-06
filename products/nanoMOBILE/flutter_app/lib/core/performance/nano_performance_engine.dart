/// NanoPerformanceEngine — Adaptación ADPF y Monitoreo Térmico en Flutter.
///
/// Responsabilidad Única (SRP):
/// Proveer la abstracción Dart para modular el rendimiento del hardware
/// (EAS Scheduler, PerformanceHintManager) y reaccionar a eventos térmicos.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../services/nano_runtime_api.dart';

enum NanoPerformanceMode { eco, balanced, turbo }

enum NanoThermalStatus {
  none,
  light,
  moderate,
  severe,
  critical,
  emergency,
  shutdown,
  unknown;

  static NanoThermalStatus fromInt(int val) => switch (val) {
    0 => NanoThermalStatus.none,
    1 => NanoThermalStatus.light,
    2 => NanoThermalStatus.moderate,
    3 => NanoThermalStatus.severe,
    4 => NanoThermalStatus.critical,
    5 => NanoThermalStatus.emergency,
    6 => NanoThermalStatus.shutdown,
    _ => NanoThermalStatus.unknown,
  };
}

class ThermalEvent {
  final NanoThermalStatus status;
  final int rawStatus;
  final String name;
  final double threadScale;

  const ThermalEvent({
    required this.status,
    required this.rawStatus,
    required this.name,
    required this.threadScale,
  });

  factory ThermalEvent.fromMap(Map<Object?, Object?> map) {
    final raw = (map['status'] as num?)?.toInt() ?? -1;
    return ThermalEvent(
      status: NanoThermalStatus.fromInt(raw),
      rawStatus: raw,
      name: (map['name'] as String?) ?? 'UNKNOWN',
      threadScale: (map['threadScale'] as num?)?.toDouble() ?? 1.0,
    );
  }

  static const normal = ThermalEvent(
    status: NanoThermalStatus.none,
    rawStatus: 0,
    name: 'NONE',
    threadScale: 1.0,
  );
}

class PerformanceSession {
  final NanoPerformanceEngine _engine;
  final NanoPerformanceMode mode;
  final NanoPerformanceMode previousMode;
  bool _closed = false;

  PerformanceSession._(this._engine, this.mode, this.previousMode);

  Future<void> reportWorkDuration(Duration duration) async {
    if (_closed) return;
    await _engine.reportWorkDuration(duration);
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    await _engine.setMode(previousMode);
  }
}

class NanoPerformanceEngine {
  static final NanoPerformanceEngine instance = NanoPerformanceEngine._();
  NanoPerformanceEngine._();

  static const _methodChannel = MethodChannel(NanoRuntimeChannels.performance);
  static const _eventChannel = EventChannel(NanoRuntimeChannels.thermalEvents);

  Stream<ThermalEvent>? _thermalStream;
  ThermalEvent _latestThermal = ThermalEvent.normal;
  ThermalEvent get latestThermal => _latestThermal;

  Stream<ThermalEvent> get thermalEvents {
    return _thermalStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) {
          if (event is Map) {
            final ev = ThermalEvent.fromMap(event);
            _latestThermal = ev;
            return ev;
          }
          return ThermalEvent.normal;
        })
        .handleError((e) {
          debugPrint('Error en stream térmico: $e');
          return ThermalEvent.normal;
        });
  }

  Future<bool> setMode(NanoPerformanceMode mode) async {
    try {
      final ok = await _methodChannel.invokeMethod<bool>('setMode', {
        'mode': mode.name,
      });
      return ok ?? false;
    } on PlatformException catch (e) {
      debugPrint('Fallo al configurar modo de rendimiento: ${e.message}');
      return false;
    }
  }

  Future<NanoPerformanceMode> getMode() async {
    try {
      final modeStr = await _methodChannel.invokeMethod<String>('getMode');
      return NanoPerformanceMode.values.firstWhere(
        (m) => m.name == modeStr?.toLowerCase(),
        orElse: () => NanoPerformanceMode.balanced,
      );
    } catch (_) {
      return NanoPerformanceMode.balanced;
    }
  }

  Future<ThermalEvent> getThermalStatus() async {
    try {
      final res = await _methodChannel.invokeMapMethod<Object?, Object?>(
        'getThermalStatus',
      );
      if (res != null) {
        _latestThermal = ThermalEvent.fromMap(res);
        return _latestThermal;
      }
    } catch (_) {}
    return ThermalEvent.normal;
  }

  Future<PerformanceSession> acquireSession({
    NanoPerformanceMode mode = NanoPerformanceMode.turbo,
  }) async {
    final prev = await getMode();
    await setMode(mode);
    return PerformanceSession._(this, mode, prev);
  }

  Future<void> reportWorkDuration(Duration duration) async {
    try {
      await _methodChannel.invokeMethod('reportWorkDuration', {
        'durationNs': duration.inMicroseconds * 1000,
      });
    } catch (_) {}
  }

  Future<Map<String, dynamic>> getCapabilities() async {
    try {
      final res = await _methodChannel.invokeMapMethod<Object?, Object?>(
        'getCapabilities',
      );
      return res?.cast<String, dynamic>() ?? {};
    } catch (_) {
      return {};
    }
  }

  /// Calcula dinámicamente los hilos óptimos para el runtime según el estado térmico.
  int computeAdaptiveThreads({required int baseThreads, double? threadScale}) {
    final scale = threadScale ?? _latestThermal.threadScale;
    final target = (baseThreads * scale).round();
    return target.clamp(1, baseThreads);
  }
}
