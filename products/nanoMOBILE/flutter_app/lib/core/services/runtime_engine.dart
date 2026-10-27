// Dueño único de los motores locales: GGUF por supervisor/HTTP y LiteRT por JNI.
// Serializa cambios, comparte el cliente con chat/Personal y evita dos modelos activos.
// Separa cada ciclo de vida para conservar recuperación GGUF sin sondear HTTP en LiteRT.
library;

import 'dart:async';
import 'execution_budget.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'engine_status.dart';
import '../models/catalog_models.dart';
import 'engine_watchdog_coordinator.dart';
import 'llm_engine_client.dart';
import 'nano_runtime_api.dart';
import 'litert_inference_adapter.dart';
import 'mnn_inference_adapter.dart';
import 'remote_inference_config.dart';
import 'routed_llm_engine_client.dart';
export 'engine_status.dart';
part 'runtime_gguf_lifecycle.dart';
part 'runtime_local_lifecycle.dart';

/// Selecciona el transporte real por formato y conserva permisos/prompts de los consumidores.
class RuntimeEngineNotifier extends StateNotifier<EngineStatus>
    with WidgetsBindingObserver, _RuntimeGgufLifecycle, _RuntimeLocalLifecycle {
  @override
  final NanoRuntimeApi _api;
  @override
  final LLMEngineClient _client;
  @override
  final LiteRtInferenceAdapter liteRt = LiteRtInferenceAdapter();
  @override
  final MnnInferenceAdapter mnn = MnnInferenceAdapter();
  late final RoutedLlmEngineClient _routedClient;
  @override
  String? _selectedPath;
  @override
  ModelBackendType _selectedBackend = ModelBackendType.gguf;
  @override
  Future<void> _lifecycleTail = Future<void>.value();
  @override
  late final EngineWatchdogCoordinator _watchdog;
  bool _isRemoteInference = false;
  @override
  bool get isRemoteInference => _isRemoteInference;

  static const Duration startTimeout = Duration(seconds: 45);

  RuntimeEngineNotifier(this._api, {int port = 8080, Ref? ref})
    : _client = LLMEngineClient(baseUrl: 'http://127.0.0.1:$port'),
      super(EngineStatus(port: port)) {
    _routedClient = RoutedLlmEngineClient(
      llama: _client,
      liteRt: liteRt,
      mnn: mnn,
      useLiteRt: () => _usesLiteRt,
      useMnn: () => _usesMnn,
    );
    _watchdog = EngineWatchdogCoordinator(
      api: _api,
      client: _client,
      getStatus: () => state,
      // Una recuperación GGUF ya iniciada no puede reactivar ni detener el LiteRT elegido después.
      onStart: ({modelPath}) =>
          _usesLocalRuntime ? Future.value(state) : start(modelPath: modelPath),
      onStop: () => _usesLocalRuntime ? Future.value(false) : stop(),
      onStatusUpdate: (s) {
        if (!_usesLocalRuntime) state = s;
      },
    );
    _api.setEngineStateListener(_onEngineStateEvent);
    WidgetsBinding.instance.addObserver(this);
    _watchdog.pause();
    if (ref != null) {
      ref.listen<RemoteInferenceConfig>(remoteInferenceConfigProvider, (_, next) {
        applyRemoteConfig(next);
      });
      applyRemoteConfig(ref.read(remoteInferenceConfigProvider));
    }
  }

  void applyRemoteConfig(RemoteInferenceConfig config) {
    _isRemoteInference = config.isRemote;
    _client.updateEndpoint(
      baseUrl: config.isRemote && config.serverUrl.isNotEmpty
          ? config.serverUrl
          : 'http://127.0.0.1:${state.port}',
      apiKey: config.isRemote && config.apiKey.isNotEmpty ? config.apiKey : null,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_usesLocalRuntime) {
      debugPrint('[engine] lifecycle resumed → health check inmediato');
      unawaited(_watchdog.healthTick());
    }
  }

  LLMEngineClient get client => _routedClient;
  String? get currentModelPath => _selectedPath ?? state.modelPath;
  ModelBackendType get currentBackendType => _selectedBackend;
  EnginePhase get phase => state.phase;
  bool get isLive => state.isLive;
  String? get reason => state.reason;

  /// Re-verifica el estado real: snapshot del canal + probe HTTP.
  @override
  Future<EngineStatus> refresh() async {
    if (_usesLocalRuntime) return state;
    if (isRemoteInference) {
      final s = state;
      final online = await _client.isOnline(attempts: 1, requestTimeout: const Duration(seconds: 3));
      if (state != s) return state;
      if (!online) {
        return state = s.copyWith(phase: EnginePhase.idle, reason: 'Servidor PC no responde (${_client.baseUrl})');
      }
      final hasModel = await _client.hasModel();
      if (state != s) return state;
      return state = hasModel
          ? s.copyWith(phase: EnginePhase.ready, clearReason: true)
          : s.copyWith(phase: EnginePhase.degraded, reason: 'Servidor PC online, sin modelo cargado');
    }
    final snapshot = await _api.engineGetState();
    if (snapshot != null) _applyStateMap(snapshot, scheduleRefresh: false);
    final s = state;
    if (!s.isLive) return s;

    final online = await _isOnlineWithNativeFallback();
    if (state != s) return state;
    if (!online) {
      return state = s.copyWith(phase: EnginePhase.idle, reason: '/health no responde');
    }
    final hasModel = await _client.hasModel();
    if (state != s) return state;
    return state = hasModel
        ? s.copyWith(phase: EnginePhase.ready, clearReason: true)
        : s.copyWith(phase: EnginePhase.degraded, reason: 'servidor vivo, pero el modelo no está cargado');
  }

  /// Espera a que el motor esté listo para inferir. Si está idle arranca.
  Future<bool> ensureReady({
    String? modelPath,
    ModelBackendType? backendType,
  }) async {
    final target = backendType ??
        (modelPath == null ? _selectedBackend : NeuralCatalog.backendForPath(modelPath));
    if (target != ModelBackendType.gguf) {
      return (await start(modelPath: modelPath, backendType: target)).phase == EnginePhase.ready;
    }
    var s = state;
    debugPrint('[engine] ensureReady fase=${s.phase.name} model=$modelPath');
    if ((s.isLive && modelPath != null && s.modelPath != modelPath) ||
        s.phase == EnginePhase.idle ||
        s.phase == EnginePhase.failed) {
      s = await start(modelPath: modelPath);
    } else if (s.phase == EnginePhase.starting) {
      await start(modelPath: modelPath);
      s = state;
    }
    if (s.isLive) s = await refresh();
    return s.phase == EnginePhase.ready;
  }

  void _onEngineStateEvent(Map<dynamic, dynamic> map) {
    if (!mounted || _usesLocalRuntime) return;
    _applyStateMap(map, scheduleRefresh: false);
  }

  @override
  void dispose() {
    _watchdog.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _api.clearEngineStateListener();
    unawaited(liteRt.release().catchError((Object _) => false));
    mnn.dispose();
    _routedClient.dispose();
    super.dispose();
  }
}

final runtimeEngineProvider =
    StateNotifierProvider<RuntimeEngineNotifier, EngineStatus>(
      (ref) => RuntimeEngineNotifier(NanoRuntimeApi.instance, ref: ref),
    );
