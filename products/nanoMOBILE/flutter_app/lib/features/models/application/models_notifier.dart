import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/features/models/application/models_state.dart';
import 'package:nanoai/features/models/data/catalog_local_model_repository.dart';
import 'package:nanoai/features/models/data/model_downloader.dart';
import 'package:nanoai/features/models/domain/local_model.dart';
import 'package:nanoai/features/models/domain/local_model_repository.dart';

class ModelsNotifier extends StateNotifier<ModelsState> {
  final Ref _ref;
  final LocalModelRepository _repository;
  final ModelDownloader _downloader;

  // Una descarga a la vez (GGUF de varios GB): la activa posee el token.
  String? _downloadingId;

  ModelsNotifier(this._ref, this._repository, {ModelDownloader? downloader})
    : _downloader = downloader ?? ModelDownloader(),
      super(const ModelsState()) {
    _load();
  }

  /// Test-only: emits a fixed state without IO.
  @visibleForTesting
  ModelsNotifier.fixed(Ref ref, super.initial)
    : _ref = ref,
      _repository = const CatalogLocalModelRepository(),
      _downloader = ModelDownloader();

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

  @override
  void dispose() {
    _downloader.dispose();
    super.dispose();
  }
}
