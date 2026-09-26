// engine_watchdog_coordinator.dart — Coordinador de salud y recuperación del motor.
// QUÉ HACE: Monitorea periódicamente /health y métricas de memoria del SO para prevenir bloqueos y OOM.
// CÓMO FUNCIONA: Temporizador periódico (2s) que sondea HTTP, consulta MemoryGuard y serializa recuperaciones.
// POR QUÉ: Extraído de runtime_engine.dart para aislar la lógica de watchdog y cumplir límite < 200 líneas.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'engine_status.dart';
import 'engine_supervisor.dart';
import 'llm_engine_client.dart';
import 'nano_runtime_api.dart';

class EngineWatchdogCoordinator {
  final NanoRuntimeApi _api;
  final LLMEngineClient _client;
  final EngineStatus Function() _getStatus;
  final Future<EngineStatus> Function({String? modelPath}) _onStart;
  final Future<bool> Function() _onStop;
  final void Function(EngineStatus status) _onStatusUpdate;

  final EngineSupervisorState _supervisor = EngineSupervisorState();
  final MemoryGuardState _memoryGuard = MemoryGuardState();
  Timer? _healthTimer;

  bool _recoveryInProgress = false;
  bool _healthCheckInProgress = false;
  bool _memoryCheckInProgress = false;
  MemoryPressureState? _lastMemoryState;
  bool _deliberateStop = false;

  EngineWatchdogCoordinator({
    required NanoRuntimeApi api,
    required LLMEngineClient client,
    required EngineStatus Function() getStatus,
    required Future<EngineStatus> Function({String? modelPath}) onStart,
    required Future<bool> Function() onStop,
    required void Function(EngineStatus status) onStatusUpdate,
  }) : _api = api,
       _client = client,
       _getStatus = getStatus,
       _onStart = onStart,
       _onStop = onStop,
       _onStatusUpdate = onStatusUpdate;

  void start() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(healthTick());
      unawaited(_memoryTick());
    });
  }

  Future<void> healthTick() async {
    if (_recoveryInProgress || _healthCheckInProgress) return;
    final s = _getStatus();
    if (s.phase == EnginePhase.idle) return;
    if (_client.hasActiveStreamRequest) return;
    _healthCheckInProgress = true;
    try {
      if (await _client.isOnline(
        attempts: 1,
        requestTimeout: const Duration(seconds: 2),
      )) {
        _supervisor.onHealthOk();
        return;
      }
      final snapshot = await _api.engineGetState();
      final processAlive = snapshot?['process_alive'] == true;
      final intent = _supervisor.onHealthFail(
        nowMs: DateTime.now().millisecondsSinceEpoch,
        processAlive: processAlive,
        deliberateStop: _deliberateStop,
      );
      if (intent != RecoveryIntent.none) {
        await _recover(intent);
      }
    } finally {
      _healthCheckInProgress = false;
    }
  }

  Future<void> _memoryTick() async {
    if (_recoveryInProgress || _memoryCheckInProgress) return;
    final s = _getStatus();
    if (s.phase == EnginePhase.idle || s.phase == EnginePhase.failed) return;
    _memoryCheckInProgress = true;
    try {
      final metrics = await _api.getMetrics();
      if (metrics == null) return;
      final freeMemMb = _extractFreeMemMb(metrics);
      if (freeMemMb == null) return;

      final newState = _memoryGuard.update(freeMemMb);
      if (newState == _lastMemoryState) return;
      _lastMemoryState = newState;
      debugPrint('[watchdog] memory ${newState.name} (${freeMemMb}MB libre)');

      if (newState == MemoryPressureState.normal) {
        _deliberateStop = false;
        return;
      }
      final intent = _memoryGuard.intent();
      if (intent == RecoveryIntent.none) return;
      _deliberateStop = true;
      await _recover(intent);
    } finally {
      _memoryCheckInProgress = false;
    }
  }

  int? _extractFreeMemMb(Map<dynamic, dynamic> m) {
    for (final k in [
      'memAvailableMb',
      'mem_available_mb',
      'availableMb',
      'available_mb',
      'MemAvailable',
      'freeMemMb',
    ]) {
      final v = m[k];
      if (v is num) return v.toInt();
    }
    return null;
  }

  Future<void> _recover(RecoveryIntent intent) async {
    if (_recoveryInProgress) return;
    _recoveryInProgress = true;
    try {
      switch (intent) {
        case RecoveryIntent.none:
        case RecoveryIntent.trimCaches:
        case RecoveryIntent.cancelGeneration:
          break;
        case RecoveryIntent.unloadModel:
          await _onStop();
          break;
        case RecoveryIntent.fallbackSafeModel:
          await _recoverWithSafeModel();
          break;
        case RecoveryIntent.restartEngine:
          await _restartEngineSafely();
          break;
      }
    } finally {
      _recoveryInProgress = false;
    }
  }

  Future<void> _restartEngineSafely() async {
    debugPrint('[watchdog] recuperación: restart seguro');
    final modelPath = _getStatus().modelPath;
    _onStatusUpdate(
      _getStatus().copyWith(phase: EnginePhase.starting, clearReason: true),
    );
    await _onStop();
    final result = await _onStart(modelPath: modelPath);
    if (result.isLive) {
      _supervisor.onModelReady();
    } else {
      await _recoverWithSafeModel();
    }
  }

  Future<void> _recoverWithSafeModel() async {
    debugPrint('[watchdog] recuperación: fallback al modelo seguro');
    final current = _getStatus().modelPath;
    if (current == null) {
      await _onStop();
      return;
    }
    await _onStop();
    final result = await _onStart(modelPath: null);
    if (result.isLive) _supervisor.onModelReady();
  }

  void dispose() {
    _healthTimer?.cancel();
    _healthTimer = null;
  }
}
