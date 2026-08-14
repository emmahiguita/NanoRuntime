import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/core/models/chat_models.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/features/models/application/models_provider.dart';
import 'package:nanoai/features/models/domain/detected_model.dart';
import 'package:nanoai/features/models/domain/local_model.dart';
import 'package:nanoai/features/models/domain/local_model_repository.dart';
import 'package:nanoai/features/models/domain/model_storage_repository.dart';

/// Fakes de la frontera storage SAF: sin canal, sin IO. Cada fake registra
/// las llamadas recibidas para poder asertar el contrato completo.
class FakeStorageRepository implements ModelStorageRepository {
  FakeStorageRepository({
    this.tree,
    this.scanResult = const [],
    this.fdPath,
  });

  String? tree;
  List<DetectedModel> scanResult;
  String? fdPath;

  int scanCalls = 0;
  final List<String> openedUris = [];

  @override
  Future<String?> pickTree() async => tree;

  @override
  Future<String?> persistedTree() async => tree;

  @override
  Future<List<DetectedModel>> scan() async {
    scanCalls++;
    if (tree == null) throw StateError('storage tree no concedido');
    return scanResult;
  }

  @override
  Future<String?> openFd(String uri) async {
    openedUris.add(uri);
    return fdPath;
  }
}

class FakeLocalRepository implements LocalModelRepository {
  const FakeLocalRepository(this.models);

  final List<LocalModel> models;

  @override
  Future<List<LocalModel>> listModels() async => models;
}

/// ChatNotifier que solo registra selectModel: sin IO, sin timers.
class _RecordingChatNotifier extends ChatNotifier {
  _RecordingChatNotifier(Ref ref) : super.fixed(ref, const ChatState());

  final List<(String, String?)> selected = [];

  @override
  void selectModel(String name, {String? path}) {
    selected.add((name, path));
  }
}

DetectedModel _detected(
  String name, {
  DetectedModelFormat format = DetectedModelFormat.gguf,
  bool magicOk = true,
  int sizeBytes = 2 * 1000 * 1000 * 1000,
}) {
  return DetectedModel(
    name: name,
    sizeBytes: sizeBytes,
    uri: 'content://tree/primary/$name',
    format: format,
    magicOk: magicOk,
  );
}

LocalModel _catalogModel(String fileName) {
  return LocalModel(
    id: fileName,
    name: fileName,
    params: '1B',
    quant: 'Q4_K_M',
    sizeGb: 1.0,
    ramGb: 2.0,
    fileName: fileName,
    description: 'test',
    template: ChatTemplate.qwen,
    downloadState: ModelDownloadState.notInstalled,
    progress: 0,
    url: 'https://example.invalid/$fileName',
    sha256: 'x' * 64,
    active: false,
    loading: false,
  );
}

ProviderContainer _container({
  required FakeStorageRepository storage,
  List<LocalModel> catalog = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      modelStorageRepositoryProvider.overrideWithValue(storage),
      localModelRepositoryProvider.overrideWithValue(
        FakeLocalRepository(catalog),
      ),
      chatProvider.overrideWith(_RecordingChatNotifier.new),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('Detección de modelos en storage SAF', () {
    test('maybeAutoScan sin árbol concedido: no escanea y marca treeGranted '
        'false', () async {
      final storage = FakeStorageRepository(tree: null);
      final container = _container(storage: storage);

      await container.read(modelsProvider.notifier).maybeAutoScan();

      final state = container.read(modelsProvider);
      expect(state.treeGranted, isFalse);
      expect(state.detected, isEmpty);
      expect(storage.scanCalls, 0);
    });

    test('scanStorage con árbol: puebla detected y deduplica contra el '
        'catálogo por nombre de archivo', () async {
      final storage = FakeStorageRepository(
        tree: 'content://tree/primary',
        scanResult: [
          _detected('mistral-7b-instruct-v0.3.Q4_K_M.gguf'),
          _detected('qwen2.5-0.5b-instruct-q4_0.gguf'), // ya en catálogo
        ],
      );
      final container = _container(
        storage: storage,
        catalog: [_catalogModel('qwen2.5-0.5b-instruct-q4_0.gguf')],
      );

      await container.read(modelsProvider.notifier).scanStorage();

      final state = container.read(modelsProvider);
      expect(state.scanning, isFalse);
      expect(storage.scanCalls, 1);
      expect(state.detected, hasLength(1));
      expect(
        state.detected.single.name,
        'mistral-7b-instruct-v0.3.Q4_K_M.gguf',
      );
    });

    test('escaneo sin árbol lanzado a mano: scanError honesto, detected '
        'vacío', () async {
      final storage = FakeStorageRepository(tree: null);
      final container = _container(storage: storage);

      await container.read(modelsProvider.notifier).scanStorage();

      final state = container.read(modelsProvider);
      expect(state.scanning, isFalse);
      expect(state.detected, isEmpty);
      expect(state.scanError, contains('Escanear storage'));
    });

    test('auto-escaneo repetido en <30 s no re-walkea el storage', () async {
      final storage = FakeStorageRepository(
        tree: 'content://tree/primary',
        scanResult: [_detected('tiny.gguf')],
      );
      final container = _container(storage: storage);
      final notifier = container.read(modelsProvider.notifier);

      await notifier.maybeAutoScan();
      expect(storage.scanCalls, 1);

      await notifier.maybeAutoScan();
      expect(storage.scanCalls, 1, reason: 'segundo escaneo debe saltarse');
    });

    test('useDetected: abre fd y selecciona el modelo con el path del fd',
        () async {
      final storage = FakeStorageRepository(
        tree: 'content://tree/primary',
        fdPath: '/proc/self/fd/42',
      );
      final container = _container(storage: storage);
      final model = _detected('mistral.Q4_K_M.gguf');

      await container.read(modelsProvider.notifier).useDetected(model);

      expect(storage.openedUris, [model.uri]);
      final chat = container.read(chatProvider.notifier);
      final recording = chat as _RecordingChatNotifier;
      expect(recording.selected, [('mistral.Q4_K_M.gguf', '/proc/self/fd/42')]);
      final state = container.read(modelsProvider);
      expect(state.loadingDetectedUri, isNull);
    });

    test('useDetected con fd denegado: error honesto y sin selección',
        () async {
      final storage = FakeStorageRepository(tree: 'content://tree/primary');
      final container = _container(storage: storage);

      await container
          .read(modelsProvider.notifier)
          .useDetected(_detected('broken.gguf'));

      final state = container.read(modelsProvider);
      expect(state.scanError, contains('fd denegado'));
      expect(state.loadingDetectedUri, isNull);
      final recording =
          container.read(chatProvider.notifier) as _RecordingChatNotifier;
      expect(recording.selected, isEmpty);
    });

    test('useDetected con modelo no usable (magic malo): no hace nada',
        () async {
      final storage = FakeStorageRepository(tree: 'content://tree/primary');
      final container = _container(storage: storage);

      await container
          .read(modelsProvider.notifier)
          .useDetected(_detected('fake.gguf', magicOk: false));

      expect(storage.openedUris, isEmpty);
      final recording =
          container.read(chatProvider.notifier) as _RecordingChatNotifier;
      expect(recording.selected, isEmpty);
    });
  });

  group('DetectedModel (dominio puro)', () {
    test('usable = GGUF con magic verificado', () {
      expect(_detected('a.gguf').usable, isTrue);
      expect(_detected('b.gguf', magicOk: false).usable, isFalse);
      expect(
        _detected('c.safetensors', format: DetectedModelFormat.safetensors)
            .usable,
        isFalse,
      );
      expect(
        _detected('d.onnx', format: DetectedModelFormat.onnx).usable,
        isFalse,
      );
    });
  });
}
