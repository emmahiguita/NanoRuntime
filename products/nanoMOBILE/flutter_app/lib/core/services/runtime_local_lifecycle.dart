part of 'runtime_engine.dart';

// Serializa cambios de motor/modelo. Nunca carga LiteRT mientras el supervisor GGUF siga vivo.
mixin _RuntimeLocalLifecycle
    on StateNotifier<EngineStatus>, _RuntimeGgufLifecycle {
  LiteRtInferenceAdapter get liteRt;
  MnnInferenceAdapter get mnn;
  ModelBackendType get _selectedBackend;
  set _selectedBackend(ModelBackendType value);
  EngineWatchdogCoordinator get _watchdog;
  String? get _selectedPath;
  set _selectedPath(String? value);
  Future<void> get _lifecycleTail;
  set _lifecycleTail(Future<void> value);
  bool get _usesLiteRt => _selectedBackend == ModelBackendType.litertlm;
  bool get _usesMnn => _selectedBackend == ModelBackendType.mnn;
  bool get _usesLocalRuntime => _usesLiteRt || _usesMnn;

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _lifecycleTail.then((_) => action());
    _lifecycleTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<EngineStatus> start({String? modelPath, ModelBackendType? backendType}) => _serialize(() async {
    final path = modelPath ?? _selectedPath ?? state.modelPath;
    final target = backendType ?? (modelPath == null
        ? _selectedBackend
        : NeuralCatalog.backendForPath(modelPath));
    _selectedBackend = target;
    if (target == ModelBackendType.gguf) {
      if (liteRt.isConfigured && !await liteRt.release()) {
        throw StateError('No se pudo liberar el motor LiteRT');
      }
      if (mnn.isConfigured && !await mnn.release()) {
        throw StateError('No se pudo liberar el motor MNN');
      }
      _selectedPath = path;
      _watchdog.start();
      return _startGguf(modelPath: path);
    }
    if (target == ModelBackendType.litertlm && _selectedPath == path &&
        liteRt.isConfigured &&
        state.phase == EnginePhase.ready) {
      return state;
    }
    if (target == ModelBackendType.mnn && _selectedPath == path &&
        mnn.isConfigured && state.phase == EnginePhase.ready) {
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
      if (target == ModelBackendType.litertlm) {
        if (mnn.isConfigured && !await mnn.release()) {
          throw StateError('No se pudo liberar el motor MNN');
        }
        final available = await liteRt.checkAvailability();
        final prefersGpu = available['hasGpuOpenCl'] == true;
        if (!await _initializeLiteRt(path!, prefersGpu: prefersGpu)) {
          throw StateError('LiteRT no confirmó la carga');
        }
      } else {
        if (liteRt.isConfigured && !await liteRt.release()) {
          throw StateError('No se pudo liberar el motor LiteRT');
        }
        if (!await mnn.initialize(modelPath: path!, backend: 'cpu')) {
          throw StateError('MNN no confirmó la carga del paquete');
        }
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

  // QUÉ HACE: Prueba GPU disponible y recupera con CPU si el delegado rechaza el modelo.
  // CÓMO FUNCIONA: Libera cualquier inicialización parcial antes del segundo intento.
  // POR QUÉ: Tener libOpenCL no garantiza que todas las operaciones del paquete sean compatibles.
  Future<bool> _initializeLiteRt(
    String path, {
    required bool prefersGpu,
  }) async {
    if (!prefersGpu) {
      return liteRt.initialize(modelPath: path, backend: 'cpu');
    }
    try {
      if (await liteRt.initialize(modelPath: path, backend: 'gpu')) return true;
    } catch (error) {
      debugPrint('[engine] LiteRT GPU no compatible: ${error.runtimeType}');
    }
    await liteRt.release();
    return liteRt.initialize(modelPath: path, backend: 'cpu');
  }

  // Detener cancela inferencia y espera close JNI; no inventa una liberación de memoria.
  Future<bool> stop() => _serialize(() async {
    _watchdog.pause();
    final liteRtStopped = !liteRt.isConfigured || await liteRt.release();
    final mnnStopped = !mnn.isConfigured || await mnn.release();
    final gguf = await _stopGguf();
    if (liteRtStopped && mnnStopped && gguf) {
      _selectedPath = null;
      _selectedBackend = ModelBackendType.gguf;
      state = EngineStatus(port: state.port);
    }
    return liteRtStopped && mnnStopped && gguf;
  });
}
