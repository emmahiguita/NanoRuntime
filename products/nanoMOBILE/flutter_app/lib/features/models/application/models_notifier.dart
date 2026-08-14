import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/features/models/application/models_state.dart';
import 'package:nanoai/features/models/data/catalog_local_model_repository.dart';
import 'package:nanoai/features/models/data/channel_model_storage_repository.dart';
import 'package:nanoai/features/models/data/model_downloader.dart';
import 'package:nanoai/features/models/domain/detected_model.dart';
import 'package:nanoai/features/models/domain/local_model.dart';
import 'package:nanoai/features/models/domain/local_model_repository.dart';
import 'package:nanoai/features/models/domain/model_storage_repository.dart';

class ModelsNotifier extends StateNotifier<ModelsState> {
  final Ref _ref;
  final LocalModelRepository _repository;
  final ModelDownloader _downloader;
  final ModelStorageRepository _storage;

  // Una descarga a la vez (GGUF de varios GB): la activa posee el token.
  String? _downloadingId;

  // Último escaneo exitoso: evita re-walkear el storage en cada navegación.
  DateTime? _lastScanAt;

  ModelsNotifier(
    this._ref,
    this._repository, {
    ModelDownloader? downloader,
    ModelStorageRepository? storage,
  }) : _downloader = downloader ?? ModelDownloader(),
       _storage = storage ?? const ChannelModelStorageRepository(),
       super(const ModelsState()) {
    _load();
  }

  /// Test-only: emits a fixed state without IO.
  @visibleForTesting
  ModelsNotifier.fixed(Ref ref, super.initial, {ModelStorageRepository? storage})
    : _ref = ref,
      _repository = const CatalogLocalModelRepository(),
      _downloader = ModelDownloader(),
      _storage = storage ?? const ChannelModelStorageRepository();

  Future<void> _load() async {
    try {
      final models = await _repository.listModels();
      if (!mounted) return;
      state = state.copyWith(models: models);
    } catch (e) {
      debugPrint('[models] listModels falló: $e');
    }
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void setFilter(String? quant) {
    state = state.copyWith(quantFilter: quant);
  }

  /// Descarga real del GGUF (URL HuggingFace + SHA256 obligatorio).
  ///
  /// Estados: notInstalled → downloading (progress) → verifying → installed,
  /// o failed con mensaje honesto. Cancelable con [cancelDownload].
  Future<void> downloadModel(String id) async {
    final item = state.models.firstWhere((model) => model.id == id);
    if (item.installed) return;
    if (_downloadingId != null) return; // una descarga a la vez

    _downloadingId = id;
    _update(
      id,
      downloadState: ModelDownloadState.downloading,
      progress: 0,
      clearError: true,
    );

    try {
      final dir = await CatalogLocalModelRepository.modelsDir();
      if (dir == null) {
        throw DownloadException(
          'getFilesDir no disponible — no se puede descargar',
        );
      }
      final destPath = '$dir/${item.fileName}';

      final file = await _downloader.download(
        url: item.url,
        destPath: destPath,
        expectedSha256: item.sha256,
        onProgress: (p) {
          if (mounted && _downloadingId == id) _update(id, progress: p);
        },
        cancelToken: () async => _downloadingId != id,
      );

      if (!mounted) return;
      _downloadingId = null;
      _update(
        id,
        downloadState: ModelDownloadState.installed,
        progress: 1.0,
        localPath: file.path,
        clearError: true,
      );
    } on DownloadException catch (e) {
      if (!mounted) return;
      if (_downloadingId == id) {
        _downloadingId = null;
        _update(id, downloadState: ModelDownloadState.failed, error: e.message);
      }
    } catch (e) {
      if (!mounted) return;
      if (_downloadingId == id) {
        _downloadingId = null;
        _update(id, downloadState: ModelDownloadState.failed, error: '$e');
      }
    }
  }

  /// Cancela la descarga en curso (token de cancelación cierra el stream).
  void cancelDownload() {
    if (_downloadingId == null) return;
    _downloadingId = null;
  }

  void _update(
    String id, {
    ModelDownloadState? downloadState,
    double? progress,
    String? localPath,
    String? error,
    bool clearError = false,
  }) {
    state = state.copyWith(
      models: [
        for (final model in state.models)
          model.id == id
              ? model.copyWith(
                  downloadState: downloadState,
                  progress: progress,
                  localPath: localPath,
                  error: error,
                  clearError: clearError,
                )
              : model,
      ],
    );
  }

  /// Selecciona un modelo instalado y lo pasa al motor real.
  ///
  /// Si el GGUF no está instalado, no hay nada que cargar: la UI lo impide
  /// (botón de descarga primero). El path real del GGUF llega a ChatNotifier,
  /// que lo usa en el arranque del motor (--model <path>).
  void loadModel(String id) {
    final item = state.models.firstWhere((model) => model.id == id);
    if (!item.installed || item.localPath == null) return;
    state = state.copyWith(
      models: [
        for (final model in state.models)
          model.copyWith(active: model.id == id, loading: model.id == id),
      ],
    );
    _ref
        .read(chatProvider.notifier)
        .selectModel(item.name, path: item.localPath);
  }

  // ── Detección de modelos en storage SAF ────────────────────────────────

  /// Escaneo completo del árbol SAF. Idempotente: si ya está corriendo,
  /// ignora la llamada.
  Future<void> scanStorage() async {
    if (state.scanning) return;
    await _scanInternal();
  }

  /// Primer uso: abre el selector de carpeta, persiste el grant y escanea.
  /// Si el usuario cancela, no cambia nada.
  Future<void> pickTreeAndScan() async {
    if (state.scanning) return;
    final uri = await _storage.pickTree();
    if (uri == null) return; // usuario canceló
    await _scanInternal();
  }

  /// Auto-escaneo al entrar a la pantalla. Solo si el árbol ya está
  /// concedido y el último escaneo tiene más de 30 s (no re-walkear
  /// el storage en cada navegación).
  Future<void> maybeAutoScan() async {
    String? tree;
    try {
      tree = await _storage.persistedTree();
    } catch (_) {
      // Canal sin handler (tests/desktop): no hay storage SAF disponible.
      tree = null;
    }
    if (!mounted) return;
    state = state.copyWith(treeGranted: tree != null);
    if (tree == null) return;
    final last = _lastScanAt;
    if (last != null && DateTime.now().difference(last).inSeconds < 30) return;
    await _scanInternal();
  }

  Future<void> _scanInternal() async {
    state = state.copyWith(scanning: true, scanError: null);
    try {
      final detected = await _storage.scan();
      if (!mounted) return;
      _lastScanAt = DateTime.now();
      state = state.copyWith(
        scanning: false,
        detected: _deduped(detected),
        scanError: null,
      );
    } catch (e) {
      _scanFailed(e);
    }
  }

  /// Quita de la lista los detectados que ya están en el catálogo
  /// (mismo nombre de archivo): el catálogo ya sabe instalarlos.
  List<DetectedModel> _deduped(List<DetectedModel> detected) {
    final catalogNames = {
      for (final model in state.models) model.fileName.toLowerCase(),
    };
    return [
      for (final model in detected)
        if (!catalogNames.contains(model.name.toLowerCase())) model,
    ];
  }

  void _scanFailed(Object e) {
    if (!mounted) return;
    _lastScanAt = null;
    state = state.copyWith(
      scanning: false,
      scanError: e is StateError
          ? 'No hay storage concedido. Toca "Escanear storage".'
          : 'Escaneo falló: $e',
    );
  }

  /// Usa un modelo detectado directamente desde su ubicación original:
  /// abre el fd en el worker (:nanoshell) y arranca el engine con el path
  /// `/proc/self/fd/N`. Cero copias de archivos pesados.
  Future<void> useDetected(DetectedModel model) async {
    if (!model.usable) return;
    if (state.loadingDetectedUri != null) return; // una apertura a la vez
    state = state.copyWith(
      loadingDetectedUri: model.uri,
      scanError: null,
    );
    try {
      final fdPath = await _storage.openFd(model.uri);
      if (!mounted) return;
      if (fdPath == null) {
        state = state.copyWith(
          loadingDetectedUri: null,
          scanError: 'No se pudo abrir ${model.name} (fd denegado).',
        );
        return;
      }
      state = state.copyWith(loadingDetectedUri: null);
      _ref
          .read(chatProvider.notifier)
          .selectModel(model.name, path: fdPath);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        loadingDetectedUri: null,
        scanError: 'No se pudo abrir ${model.name}: $e',
      );
    }
  }

  @override
  void dispose() {
    _downloader.dispose();
    super.dispose();
  }
}
