part of 'runtime_engine.dart';

// Preserva el supervisor GGUF existente: solo se extrae para mantener responsabilidades y tamaño.
mixin _RuntimeGgufLifecycle on StateNotifier<EngineStatus> {
  NanoRuntimeApi get _api;
  LLMEngineClient get _client;
  Future<EngineStatus> refresh();
  static const startTimeout = RuntimeEngineNotifier.startTimeout;

  /// Arranca el motor (spawn vía supervisor Kotlin) y espera hasta un estado terminal.
  Future<EngineStatus> _startGguf({String? modelPath}) async {
    if (state.phase == EnginePhase.ready ||
        state.phase == EnginePhase.degraded) {
      if (modelPath == null || state.modelPath == modelPath) return state;
      // QUÉ HACE: deja que Kotlin compare la ruta solicitada con el proceso real.
      // CÓMO FUNCIONA: engineStart es idempotente y el supervisor nativo conoce su ruta.
      // POR QUÉ: un snapshot Ready puede no traer modelPath; detener por caché nula aborta la carga.
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
    if (!accepted) {
      state = state.copyWith(
        phase: EnginePhase.failed,
        reason: 'canal engine rechazó el start',
      );
      return state;
    }

    final deadline = DateTime.now().add(startTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (state.phase != EnginePhase.starting) {
        return state.isLive ? refresh() : state;
      }
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
    state = state.copyWith(
      phase: EnginePhase.failed,
      reason: 'timeout esperando ready (${startTimeout.inSeconds}s)',
    );
    return state;
  }

  /// Detiene el motor (kill limpio SIGTERM→SIGKILL en el supervisor).
  Future<bool> _stopGguf() async {
    final ok = await _api.engineStop();
    if (ok) state = EngineStatus(port: state.port);
    return ok;
  }

  Future<bool> _isOnlineWithNativeFallback() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (await _client.isOnline(
        attempts: 1,
        requestTimeout: const Duration(seconds: 2),
      )) {
        return true;
      }
      final health = await _api.engineHealth();
      if (health?['status'] == 'ok') return true;
      await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
    }
    return false;
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
}
