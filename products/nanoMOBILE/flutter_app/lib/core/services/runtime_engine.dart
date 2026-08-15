import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'nano_runtime_api.dart';
import 'llm_engine_client.dart';

/// Fase del motor nanortime segÃºn la evidencia real (canal + HTTP).
///
/// - [EnginePhase.idle]: no arrancado.
/// - [EnginePhase.starting]: spawn aceptado por el supervisor Kotlin,
///   health poll en curso.
/// - [EnginePhase.ready]: /health OK y /api/status 200 (modelo cargado).
/// - [EnginePhase.degraded]: /health OK pero /api/status 503
///   runtime_unavailable â€” motor vivo sin GGUF instalado (B5).
/// - [EnginePhase.failed]: el supervisor reportÃ³ fallo (spawn, health
///   timeout, proceso muerto).
enum EnginePhase { idle, starting, ready, degraded, failed }

/// Estado observable del motor para el chip del dashboard.
class EngineStatus {
  final EnginePhase phase;
  final int? pid;
  final int port;
  final String? reason;

  /// Ruta del GGUF con el que arrancÃ³ el motor (null = --no-model).
  /// Permite detectar cambio de modelo y reiniciar honestamente.
  final String? modelPath;

  const EngineStatus({
    this.phase = EnginePhase.idle,
    this.pid,
    this.port = 8080,
    this.reason,
    this.modelPath,
  });

  EngineStatus copyWith({
    EnginePhase? phase,
    int? pid,
    int? port,
    String? reason,
    String? modelPath,
    bool clearReason = false,
    bool clearModelPath = false,
  }) => EngineStatus(
    phase: phase ?? this.phase,
    pid: pid ?? this.pid,
    port: port ?? this.port,
    reason: clearReason ? null : (reason ?? this.reason),
    modelPath: clearModelPath ? null : (modelPath ?? this.modelPath),
  );

  bool get isLive =>
      phase == EnginePhase.ready || phase == EnginePhase.degraded;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EngineStatus &&
          phase == other.phase &&
          pid == other.pid &&
          port == other.port &&
          reason == other.reason &&
          modelPath == other.modelPath;

  @override
  int get hashCode => Object.hash(phase, pid, port, reason, modelPath);
}

/// DueÃ±o Dart del motor nanortime: arranca/detiene vÃ­a canal `com.nanoai/engine`,
/// escucha los estados push del supervisor Kotlin y verifica el estado real
/// por HTTP (probe honesto â€” nunca un estado supuesto).
///
/// El [client] es la interfaz de inferencia (SSE /completion) que consumen
/// ChatNotifier y demÃ¡s: nadie crea LLMEngineClient directo.
class RuntimeEngineNotifier extends StateNotifier<EngineStatus> {
  final NanoRuntimeApi _api;
  final LLMEngineClient _client;

  /// Espera mÃ¡xima por el estado `ready` tras arrancar (poll 250ms).
  static const Duration startTimeout = Duration(seconds: 45);

  RuntimeEngineNotifier(this._api, {int port = 8080})
    : _client = LLMEngineClient(baseUrl: 'http://127.0.0.1:$port'),
      super(EngineStatus(port: port)) {
    _api.setEngineStateListener(_onEngineStateEvent);
  }

  /// Cliente HTTP de inferencia contra el motor. Ãšnico punto de acceso.
  LLMEngineClient get client => _client;

  /// Accesos rÃ¡pidos al estado actual (evitan `state.phase` en call sites).
  EnginePhase get phase => state.phase;
  bool get isLive => state.isLive;
  String? get reason => state.reason;

  /// Arranca el motor (spawn vÃ­a supervisor Kotlin) y espera hasta
  /// [EnginePhase.ready]/[EnginePhase.degraded]/[EnginePhase.failed].
  Future<EngineStatus> start({String? modelPath}) async {
    if (state.phase == EnginePhase.ready ||
        state.phase == EnginePhase.degraded) {
      if (modelPath == null || state.modelPath == modelPath) return state;
      await stop();
    }
    debugPrint('[engine] start() fase=${state.phase.name} model=$modelPath');
    state = state.copyWith(
      phase: EnginePhase.starting,
      modelPath: modelPath ?? state.modelPath,
      clearReason: true,
    );

    final accepted = await _api.engineStart(
      port: state.port,
      modelPath: modelPath,
    );
    debugPrint('[engine] engineStart accepted=$accepted');
    if (!accepted) {
      state = state.copyWith(
        phase: EnginePhase.failed,
        reason: 'canal engine rechazÃ³ el start',
      );
      return state;
    }

    // Los estados llegan por evento engineState; ademÃ¡s se hace poll del
    // snapshot por si el evento se perdiÃ³ (p. ej. canal sin listener listo).
    final deadline = DateTime.now().add(startTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (state.phase != EnginePhase.starting) {
        if (state.isLive) {
          debugPrint('[engine] poll verifica fase=${state.phase.name}');
          return refresh();
        }
        debugPrint('[engine] poll terminado por fase=${state.phase.name}');
        return state;
      }
      final snapshot = await _api.engineGetState();
      if (snapshot != null) {
        final st = snapshot['state'];
        debugPrint('[engine] snapshot=$st pid=${snapshot['pid']}');
        // 'idle'/'starting' durante starting NO son terminales: currentState()
        // del supervisor devuelve Idle hasta que el handle queda registrado
        // (extractEngineBlocking + spawn en curso, puede tardar segundos).
        // Solo 'ready' (handle vivo) termina el poll; failed llega por evento.
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
    state = state.copyWith(
      phase: EnginePhase.failed,
      reason:
          'timeout esperando ready tras arrancar (${startTimeout.inSeconds}s)',
    );
    debugPrint('[engine] timeout sin estado terminal');
    return state;
  }

  /// Detiene el motor (kill limpio SIGTERMâ†’SIGKILL en el supervisor).
  Future<bool> stop() async {
    final ok = await _api.engineStop();
    if (ok) state = EngineStatus(port: state.port);
    return ok;
  }

  /// Re-verifica el estado real: snapshot del canal + probe HTTP.
  /// Decide entre ready (con modelo) y degraded (sin modelo) por /api/status.
  Future<EngineStatus> refresh() async {
    final snapshot = await _api.engineGetState();
    if (snapshot != null) _applyStateMap(snapshot, scheduleRefresh: false);
    final s = state;
    if (!s.isLive) return s;

    final online = await _isOnlineWithNativeFallback();
    if (!online) {
      state = s.copyWith(
        phase: EnginePhase.idle,
        reason: '/health no responde',
      );
      return state;
    }
    final hasModel = await _client.hasModel();
    state = s.copyWith(
      phase: hasModel ? EnginePhase.ready : EnginePhase.degraded,
      clearReason: true,
    );
    return state;
  }

  Future<bool> _isOnlineWithNativeFallback() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      if (await _client.isOnline()) return true;
      final health = await _api.engineHealth();
      final nativeOk = health?['status'] == 'ok';
      if (nativeOk) {
        debugPrint('[engine] /health Dart fall?; canal nativo confirma ok');
        return true;
      }
      await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
    }
    return false;
  }

  /// Espera a que el motor estÃ© listo para inferir. Si estÃ¡ idle arranca;
  /// si acaba degraded, devuelve false con [reason] informativo.
  ///
  /// Cambio de modelo honesto: si el motor estÃ¡ vivo pero con un GGUF
  /// distinto del pedido, se detiene y rearranca con el nuevo --model.
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

  void _applyStateMap(
    Map<dynamic, dynamic> map, {
    bool scheduleRefresh = true,
  }) {
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
        // El supervisor confirma proceso sano; la distinciÃ³n ready/degraded
        // (Â¿hay modelo?) se resuelve en refresh() vÃ­a /api/status.
        state = state.copyWith(
          phase: EnginePhase.ready,
          pid: pid is int ? pid : state.pid,
          clearReason: true,
        );
        if (scheduleRefresh) unawaited(refresh());
      case 'failed':
        state = state.copyWith(
          phase: EnginePhase.failed,
          reason: reason is String ? reason : 'fallo del motor',
        );
    }
  }

  @override
  void dispose() {
    _api.clearEngineStateListener();
    _client.dispose();
    super.dispose();
  }
}

final runtimeEngineProvider =
    StateNotifierProvider<RuntimeEngineNotifier, EngineStatus>(
      (ref) => RuntimeEngineNotifier(NanoRuntimeApi.instance),
    );
