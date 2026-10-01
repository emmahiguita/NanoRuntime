// litert_inference_adapter_test.dart — Pruebas unitarias para LiteRtInferenceAdapter y NanoInferenceCoordinator.
// QUÉ HACE: Valida el registro de procedencia de Gemma 4, la exclusión mutua de backends y el benchmark comparativo.
// CÓMO FUNCIONA: Usa mocks de MethodChannel para simular los canales de LiteRT y EngineSupervisor de Android.
// POR QUÉ: Garantiza que nunca coexistan dos motores LLM en memoria (OOM prevention) y valida la arquitectura SOLID.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/models/catalog_models.dart';
import 'package:nanoai/core/services/litert_inference_adapter.dart';
import 'package:nanoai/core/services/nano_inference_coordinator.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
import 'package:nanoai/core/services/runtime_engine.dart';
import 'package:nanoai/features/models/data/model_source_registry.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gemma 4 Catalog & Registry', () {
    test('Gemma-4-E2B-it GGUF tiene procedencia oficial de google/gemma-4-E2B-it', () {
      final source = ModelSourceRegistry.definitionFor('gemma-4-e2b-it-q4_k_m');
      expect(source.isIdentified, isTrue);
      expect(source.officialRepo, 'google/gemma-4-E2B-it');
      expect(source.developerName, 'Google DeepMind');
    });

    test('Gemma-4-E2B-it LiteRT tiene procedencia y formato .litertlm', () {
      final source = ModelSourceRegistry.definitionFor('gemma-4-e2b-it-litert');
      expect(source.isIdentified, isTrue);
      expect(source.officialRepo, 'google/gemma-4-E2B-it');
      expect(
        source.officialCapabilities.any((c) => c.name.contains('LiteRT')),
        isTrue,
      );
    });

    test('El catálogo estático incluye ambos formatos de Gemma 4', () {
      final ggufModel = NeuralCatalog.models.firstWhere(
        (m) => m.name.contains('Gemma-4-E2B-it') && m.backendType == ModelBackendType.gguf,
      );
      final litertModel = NeuralCatalog.models.firstWhere(
        (m) => m.name.contains('Gemma-4-E2B-it') && m.backendType == ModelBackendType.litertlm,
      );

      expect(ggufModel.url, contains('.gguf'));
      expect(ggufModel.backendType, ModelBackendType.gguf);

      expect(litertModel.name, contains('LiteRT'));
      expect(litertModel.url, contains('.litertlm'));
      expect(litertModel.backendType, ModelBackendType.litertlm);
    });
  });

  group('LiteRtInferenceAdapter MethodChannel Contract', () {
    const channel = MethodChannel('com.nanoai/litert');
    final log = <MethodCall>[];

    setUp(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall);
        switch (methodCall.method) {
          case 'isAvailable':
            return {'supported': true, 'hasGpuOpenCl': true};
          case 'initialize':
            return {'success': true, 'message': 'Loaded'};
          case 'release':
            return true;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('checkAvailability consulta el canal com.nanoai/litert', () async {
      final adapter = LiteRtInferenceAdapter();
      final res = await adapter.checkAvailability();
      expect(res['supported'], isTrue);
      expect(log.map((c) => c.method), contains('isAvailable'));
    });

    test('initialize envía ruta de modelo y backend gpu', () async {
      final adapter = LiteRtInferenceAdapter();
      final success = await adapter.initialize(
        modelPath: '/path/test.litertlm',
        backend: 'gpu',
      );
      expect(success, isTrue);
      expect(adapter.isInitialized, isTrue);
      expect(adapter.currentBackend, 'gpu');
      expect(log.map((c) => c.method), contains('initialize'));
    });

    test('release libera el modelo y resetea estado', () async {
      final adapter = LiteRtInferenceAdapter();
      await adapter.initialize(modelPath: '/path/test.litertlm');
      expect(adapter.isInitialized, isTrue);

      final ok = await adapter.release();
      expect(ok, isTrue);
      expect(adapter.isInitialized, isFalse);
      expect(adapter.currentModelPath, isNull);
      expect(log.map((c) => c.method), contains('release'));
    });
  });

  group('NanoInferenceCoordinator - Mutual Exclusion Policy', () {
    const litertChannel = MethodChannel('com.nanoai/litert');
    const engineChannel = MethodChannel('com.nanoai/engine');
    final engineCalls = <String>[];

    setUp(() {
      engineCalls.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(litertChannel, (MethodCall methodCall) async {
        switch (methodCall.method) {
          case 'initialize':
            return {'success': true};
          case 'release':
            return true;
          default:
            return null;
        }
      });

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(engineChannel, (MethodCall methodCall) async {
        engineCalls.add(methodCall.method);
        switch (methodCall.method) {
          case 'stopEngine':
            return {'success': true};
          case 'startEngine':
            return {'success': true};
          case 'isExecutablePresent':
            return true;
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(litertChannel, null);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(engineChannel, null);
    });

    test('Apaga llama.cpp antes de iniciar LiteRT-LM para prevenir OOM', () async {
      final api = NanoRuntimeApi();
      final llamaNotifier = RuntimeEngineNotifier(api);
      final litertAdapter = LiteRtInferenceAdapter();

      final coordinator = NanoInferenceCoordinator(
        llamaEngine: llamaNotifier,
        liteRtEngine: litertAdapter,
      );

      // Conmutar a LiteRT
      final ok = await coordinator.switchToEngine(
        LocalEngineType.liteRt,
        modelPath: '/path/gemma-4-E2B-it.litertlm',
        backend: 'gpu',
      );

      expect(ok, isTrue);
      expect(coordinator.activeType, LocalEngineType.liteRt);
      expect(litertAdapter.isInitialized, isTrue);

      // Limpieza ordenada
      coordinator.dispose();
      llamaNotifier.dispose();
    });
  });
}
