// nano_inference_coordinator.dart — Fachada y coordinador de inferencia local.
//
// QUÉ HACE:
// Administra el ciclo de vida de los 3 motores locales (llama.cpp, LiteRT-LM, MNN-LLM)
// y garantiza que sólo un motor esté activo a la vez en memoria.
//
// CÓMO FUNCIONA:
// 1. Usa `ModelBackendType` explícito (resuelto vía `NeuralCatalog.backendForPath`),
//    eliminando la detección frágil basada en extensiones de archivo.
// 2. Ofrece `activePort` (`GenerativeInferencePort`) para consumo agnóstico por agentes.
// 3. Facilita benchmarks honestos midiendo en el dispositivo (sin cifras predecididas).
//
// POR QUÉ:
// Evita colisiones de memoria en el OPPO, respeta SOLID (DIP, SRP) y desacopla la
// selección del motor de las vistas de usuario.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/catalog_models.dart';
import 'generative_inference_port.dart';
import 'litert_inference_adapter.dart';
import 'mnn_inference_adapter.dart';
import 'runtime_engine.dart';
import 'inference_benchmark_runner.dart';
export 'inference_benchmark_runner.dart';

enum LocalEngineType { llamaCpp, liteRt, mnn }

class NanoInferenceCoordinator extends ChangeNotifier {
  final RuntimeEngineNotifier _runtime;
  bool _switching = false;
  bool _benchmarking = false;

  NanoInferenceCoordinator({required RuntimeEngineNotifier llamaEngine})
    : _runtime = llamaEngine;

  // QUÉ HACE: Determina el motor activo a partir del backend explícito actual.
  // POR QUÉ: No depende de extensiones .litertlm o .gguf en la ruta del archivo.
  LocalEngineType get activeType => switch (_runtime.currentBackendType) {
    ModelBackendType.litertlm => LocalEngineType.liteRt,
    ModelBackendType.mnn => LocalEngineType.mnn,
    ModelBackendType.gguf => LocalEngineType.llamaCpp,
  };

  bool get isSwitching => _switching;
  LiteRtInferenceAdapter get liteRt => _runtime.liteRt;
  MnnInferenceAdapter get mnn => _runtime.mnn;
  RuntimeEngineNotifier get llama => _runtime;

  // QUÉ HACE: Expone el puerto polimórfico de inferencia del motor activo.
  GenerativeInferencePort get activePort => switch (activeType) {
    LocalEngineType.liteRt => liteRt,
    LocalEngineType.mnn => mnn,
    LocalEngineType.llamaCpp => LocalLlamaInferenceAdapter(client: _runtime.client),
  };

  // QUÉ HACE: Cambia de motor garantizando que el modelo corresponda al backend solicitado.
  // CÓMO FUNCIONA: Consulta NeuralCatalog.backendForPath y serializa la parada y arranque.
  Future<bool> switchToEngine(
    LocalEngineType target, {
    required String modelPath,
    String backend = 'gpu',
  }) async {
    final expectedBackend = switch (target) {
      LocalEngineType.liteRt => ModelBackendType.litertlm,
      LocalEngineType.mnn => ModelBackendType.mnn,
      LocalEngineType.llamaCpp => ModelBackendType.gguf,
    };
    final resolvedBackend = NeuralCatalog.backendForPath(modelPath);
    if (expectedBackend != resolvedBackend) {
      throw ArgumentError(
        'El formato del modelo ($resolvedBackend) no corresponde al motor ($expectedBackend)',
      );
    }
    _switching = true;
    notifyListeners();
    try {
      return await _runtime.ensureReady(
        modelPath: modelPath,
        backendType: expectedBackend,
      );
    } finally {
      _switching = false;
      notifyListeners();
    }
  }

  // QUÉ HACE: Ejecuta comparación de benchmark empírica entre modelos en el mismo dispositivo.
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
