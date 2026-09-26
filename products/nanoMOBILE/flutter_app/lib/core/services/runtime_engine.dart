// runtime_engine.dart — Dueño y orquestador del ciclo de vida del motor nanortime.
// QUÉ HACE: Administra el inicio, detención, verificación de salud y recuperación de nanortime.
// CÓMO FUNCIONA: Comunica vía canal con el supervisor nativo y sondea endpoints HTTP reales.
// POR QUÉ: Aplica Clean Architecture y SOLID para desacoplar el estado y el watchdog en módulos < 200 líneas.
library;

import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'engine_status.dart';
import 'engine_watchdog_coordinator.dart';
import 'llm_engine_client.dart';
import 'nano_runtime_api.dart';

export 'engine_status.dart';

/// Dueño Dart del motor nanortime: arranca/detiene vía canal `com.nanoai/engine`,
/// escucha los estados push del supervisor Kotlin y verifica el estado real por HTTP.
class RuntimeEngineNotifier extends StateNotifier<EngineStatus>
    with WidgetsBindingObserver {
  final NanoRuntimeApi _api;
  final LLMEngineClient _client;
  late final EngineWatchdogCoordinator _watchdog;

  static const Duration startTimeout = Duration(seconds: 45);

  RuntimeEngineNotifier(this._api, {int port = 8080})
    : _client = LLMEngineClient(baseUrl: 'http://127.0.0.1:$port'),
      super(EngineStatus(port: port)) {
    _watchdog = EngineWatchdogCoordinator(
      api: _api,
      client: _client,
      getStatus: () => state,
      onStart: ({modelPath}) => start(modelPath: modelPath),
      onStop: stop,
      onStatusUpdate: (s) => state = s,
    );
    _api.setEngineStateListener(_onEngineStateEvent);
    WidgetsBinding.instance.addObserver(this);
    _watchdog.start();
    unawaited(refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('[engine] lifecycle resumed → health check inmediato');
      unawaited(_watchdog.healthTick());
    }
  }

  LLMEngineClient get client => _client;
  EnginePhase get phase => state.phase;
  bool get isLive => state.isLive;
  String? get reason => state.reason;

  /// Arranca el motor (spawn vía supervisor Kotlin) y espera hasta un estado terminal.
  Future<EngineStatus> start({String? modelPath}) async {
    if (state.phase == EnginePhase.ready || state.phase == EnginePhase.degraded) {
      if (modelPath == null || state.modelPath == modelPath) return state;
      await stop();
    }
    debugPrint('[engine] start() fase=${state.phase.name} model=$modelPath');
    state = state.copyWith(phase: EnginePhase.starting, modelPath: modelPath ?? state.modelPath, clearReason: true);

    final accepted = await _api.engineStart(port: state.port, modelPath: modelPath);
    if (!accepted) {
      state = state.copyWith(phase: EnginePhase.failed, reason: 'canal engine rechazó el start');
      return state;
    }

    final deadline = DateTime.now().add(startTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (state.phase != EnginePhase.starting) return state.isLive ? refresh() : state;
      final snapshot = await _api.engineGetState();
      if (snapshot != null) {
        final st = snapshot['state'];
        if (st == 'ready') {
          _applyStateMap(snapshot, scheduleRefresh: false);
          return refresh();
        }
        if (st == 'failed') {
          _applyStateMap(snapshot, scheduleRefresh: false);
          return state;
        }
      }
    }
    state = state.copyWith(phase: EnginePhase.failed, reason: 'timeout esperando ready (${startTimeout.inSeconds}s)');
    return state;
  }

  /// Detiene el motor (kill limpio SIGTERM→SIGKILL en el supervisor).
  Future<bool> stop() async {
    final ok = await _api.engineStop();
    if (ok) state = EngineStatus(port: state.port);
    return ok;
  }

  /// Re-verifica el estado real: snapshot del canal + probe HTTP.
  Future<EngineStatus> refresh() async {
    final snapshot = await _api.engineGetState();
    if (snapshot != null) _applyStateMap(snapshot, scheduleRefresh: false);
    final s = state;
    if (!s.isLive) return s;

    final online = await _isOnlineWithNativeFallback();
    if (state != s) return state;
    if (!online) {
      state = s.copyWith(phase: EnginePhase.idle, reason: '/health no responde');
      return state;
    }
    final hasModel = await _client.hasModel();
    if (state != s) return state;
    state = s.copyWith(phase: hasModel ? EnginePhase.ready : EnginePhase.degraded, clearReason: true);
    return state;
  }

  Future<bool> _isOnlineWithNativeFallback() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (await _client.isOnline(attempts: 1, requestTimeout: const Duration(seconds: 2))) return true;
      final health = await _api.engineHealth();
      if (health?['status'] == 'ok') return true;
      await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
    }
    return false;
  }

  /// Espera a que el motor esté listo para inferir. Si está idle arranca.
  Future<bool> ensureReady({String? modelPath}) async {
    var s = state;
    debugPrint('[engine] ensureReady fase=${s.phase.name} model=$modelPath');
    if (s.isLive && modelPath != null && s.modelPath != modelPath) {
      await stop();
      s = state;
    }
    if (s.phase == EnginePhase.idle || s.phase == EnginePhase.failed) {
      s = await start(modelPath: modelPath);
    }
    if (s.phase == EnginePhase.starting) {
      await start(modelPath: modelPath);
      s = state;
    }
    return s.phase == EnginePhase.ready;
  }

  void _onEngineStateEvent(Map<dynamic, dynamic> map) {
    if (!mounted) return;
    _applyStateMap(map, scheduleRefresh: false);
  }

  void _applyStateMap(Map<dynamic, dynamic> map, {bool scheduleRefresh = true}) {
    final raw = map['state'];
    if (raw is! String) return;
    final pid = map['pid'];
    final reason = map['reason'];
    switch (raw) {
      case 'idle':
        state = EngineStatus(port: state.port);
      case 'starting':
        state = state.copyWith(phase: EnginePhase.starting, clearReason: true);
      case 'ready':
        state = state.copyWith(phase: EnginePhase.ready, pid: pid is int ? pid : state.pid, clearReason: true);
        if (scheduleRefresh) unawaited(refresh());
      case 'failed':
        state = state.copyWith(phase: EnginePhase.failed, reason: reason is String ? reason : 'fallo del motor');
    }
  }

  @override
  void dispose() {
    _watchdog.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _api.clearEngineStateListener();
    _client.dispose();
    super.dispose();
  }
}

final runtimeEngineProvider = StateNotifierProvider<RuntimeEngineNotifier, EngineStatus>(
  (ref) => RuntimeEngineNotifier(NanoRuntimeApi.instance),
);
