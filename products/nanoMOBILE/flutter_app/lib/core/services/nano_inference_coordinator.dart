// Una fachada, un runtime: comparación opcional con datos reales, sin motores duplicados.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'generative_inference_port.dart';
import 'litert_inference_adapter.dart';
import 'runtime_engine.dart';
import 'inference_benchmark_runner.dart';
export 'inference_benchmark_runner.dart';

enum LocalEngineType { llamaCpp, liteRt }

class NanoInferenceCoordinator extends ChangeNotifier {
  final RuntimeEngineNotifier _runtime;
  bool _switching = false;
  bool _benchmarking = false;
  NanoInferenceCoordinator({required RuntimeEngineNotifier llamaEngine})
    : _runtime = llamaEngine;
  LocalEngineType get activeType =>
      _runtime.currentModelPath?.endsWith('.litertlm') == true
      ? LocalEngineType.liteRt
      : LocalEngineType.llamaCpp;
  bool get isSwitching => _switching;
  LiteRtInferenceAdapter get liteRt => _runtime.liteRt;
  RuntimeEngineNotifier get llama => _runtime;
  GenerativeInferencePort get activePort => activeType == LocalEngineType.liteRt
      ? liteRt
      : LocalLlamaInferenceAdapter(client: _runtime.client);

  // El runtime compara ruta y readiness; no basta con que coincida el nombre del backend.
  Future<bool> switchToEngine(
    LocalEngineType target, {
    required String modelPath,
    String backend = 'gpu',
  }) async {
    if ((target == LocalEngineType.liteRt) != modelPath.endsWith('.litertlm')) {
      throw ArgumentError('El formato no corresponde al motor elegido');
    }
    _switching = true;
    notifyListeners();
    try {
      return await _runtime.ensureReady(modelPath: modelPath);
    } finally {
      _switching = false;
      notifyListeners();
    }
  }

  Future<List<EngineBenchmarkResult>> runBenchmarkComparison({
    required String prompt,
    required String ggufModelPath,
    required String liteRtModelPath,
  }) async {
    if (_benchmarking || _runtime.client.hasActiveStreamRequest) {
      throw StateError('Hay una inferencia activa; espera antes de comparar');
    }
    _benchmarking = true;
    final originalPath = _runtime.currentModelPath;
    try {
      return [
        await measureLocalEngine(
          this,
          LocalEngineType.liteRt,
          liteRtModelPath,
          prompt,
        ),
        await measureLocalEngine(
          this,
          LocalEngineType.llamaCpp,
          ggufModelPath,
          prompt,
        ),
      ];
    } finally {
      try {
        if (originalPath != null && originalPath.isNotEmpty) {
          await _runtime.ensureReady(modelPath: originalPath);
        } else {
          await _runtime.stop();
        }
      } finally {
        _benchmarking = false;
      }
    }
  }
}

final nanoInferenceCoordinatorProvider = Provider<NanoInferenceCoordinator>((
  ref,
) {
  final coordinator = NanoInferenceCoordinator(
    llamaEngine: ref.watch(runtimeEngineProvider.notifier),
  );
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
