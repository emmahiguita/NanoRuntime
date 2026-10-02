part of 'runtime_engine.dart';

// Serializa cambios de motor/modelo. Nunca carga LiteRT mientras el supervisor GGUF siga vivo.
mixin _RuntimeLocalLifecycle
    on StateNotifier<EngineStatus>, _RuntimeGgufLifecycle {
  LiteRtInferenceAdapter get liteRt;
  EngineWatchdogCoordinator get _watchdog;
  String? get _selectedPath;
  set _selectedPath(String? value);
  Future<void> get _lifecycleTail;
  set _lifecycleTail(Future<void> value);
  bool get _usesLiteRt => _selectedPath?.endsWith('.litertlm') == true;

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _lifecycleTail.then((_) => action());
    _lifecycleTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<EngineStatus> start({String? modelPath}) => _serialize(() async {
    final path = modelPath ?? _selectedPath ?? state.modelPath;
    if (path?.endsWith('.litertlm') != true) {
      if (liteRt.isConfigured && !await liteRt.release()) {
        throw StateError('No se pudo liberar el motor LiteRT');
      }
      _selectedPath = path;
      _watchdog.start();
      return _startGguf(modelPath: path);
    }
    if (_selectedPath == path &&
        liteRt.isConfigured &&
        state.phase == EnginePhase.ready) {
      return state;
    }
    _watchdog.pause();
    _selectedPath = path;
    state = state.copyWith(
      phase: EnginePhase.starting,
      modelPath: path,
      clearReason: true,
    );
    try {
      if (!await _stopGguf()) throw StateError('No se pudo detener nanortime');
      state = state.copyWith(phase: EnginePhase.starting, modelPath: path);
      final available = await liteRt.checkAvailability();
      final backend = available['hasGpuOpenCl'] == true ? 'gpu' : 'cpu';
      if (!await liteRt.initialize(modelPath: path!, backend: backend)) {
        throw StateError('LiteRT no confirmó la carga');
      }
      state = EngineStatus(
        port: state.port,
        phase: EnginePhase.ready,
        modelPath: path,
      );
    } catch (error) {
      state = EngineStatus(
        port: state.port,
        phase: EnginePhase.failed,
        modelPath: path,
        reason: error.toString(),
      );
    }
    return state;
  });

  // Detener cancela inferencia y espera close JNI; no inventa una liberación de memoria.
  Future<bool> stop() => _serialize(() async {
    _watchdog.pause();
    final native = !liteRt.isConfigured || await liteRt.release();
    final gguf = await _stopGguf();
    if (native && gguf) {
      _selectedPath = null;
      state = EngineStatus(port: state.port);
    }
    return native && gguf;
  });
}
