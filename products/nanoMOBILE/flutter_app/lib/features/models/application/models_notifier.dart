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

class _CatalogReconciliation {
  const _CatalogReconciliation(this.models, this.detected);

  final List<LocalModel> models;
  final List<DetectedModel> detected;
}

class ModelsNotifier extends StateNotifier<ModelsState> {
  final Ref _ref;
  final LocalModelRepository _repository;
  final ModelDownloader _downloader;
  final ModelStorageRepository _storage;
  final Future<String?> Function() _modelsDir;

  // Una descarga a la vez (GGUF de varios GB): la activa posee el token.
  String? _downloadingId;

  // Último escaneo exitoso: evita re-walkear el storage en cada navegación.
  DateTime? _lastScanAt;

  ModelsNotifier(
    this._ref,
    this._repository, {
    ModelDownloader? downloader,
    ModelStorageRepository? storage,
    Future<String?> Function()? modelsDir,
  }) : _downloader = downloader ?? ModelDownloader(),
       _storage = storage ?? const ChannelModelStorageRepository(),
       _modelsDir = modelsDir ?? CatalogLocalModelRepository.modelsDir,
       super(const ModelsState()) {
    _load();
  }

  /// Test-only: emits a fixed state without IO.
  @visibleForTesting
  ModelsNotifier.fixed(
    Ref ref,
    super.initial, {
    ModelStorageRepository? storage,
    Future<String?> Function()? modelsDir,
  }) : _ref = ref,
       _repository = const CatalogLocalModelRepository(),
       _downloader = ModelDownloader(),
       _storage = storage ?? const ChannelModelStorageRepository(),
       _modelsDir = modelsDir ?? CatalogLocalModelRepository.modelsDir;

  Future<void> _load() async {
    try {
      final models = await _repository.listModels();
      if (!mounted) return;
      state = state.copyWith(models: models);
    } catch (e) {
      debugPrint('[models] listModels falló: $e');
    }
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
      final dir = await _modelsDir();
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
        onVerifying: () {
          if (mounted && _downloadingId == id) {
            _update(
              id,
              downloadState: ModelDownloadState.verifying,
              progress: 1,
            );
          }
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
    final id = _downloadingId;
    if (id == null) return;
    _downloadingId = null;
    _update(
      id,
      downloadState: ModelDownloadState.failed,
      progress: 0,
      error: 'descarga cancelada',
    );
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

  // ── Escaneo automático de todo el storage (MANAGE_EXTERNAL_STORAGE) ────

  /// Auto-escaneo de todo el storage al entrar. Es la vía principal: si el
  /// permiso está concedido, encuentra los GGUF con su ruta real sin pedir
  /// carpeta ni descargar nada. Mismo throttle de 30 s que el SAF.
  Future<void> maybeAutoScanAll() async {
    bool granted;
    try {
      granted = await _storage.hasAllFilesAccess();
    } catch (_) {
      // Canal sin handler (tests/desktop): sin scanner de storage completo.
      granted = false;
    }
    if (!mounted) return;
    state = state.copyWith(allFilesGranted: granted);
    if (!granted) return;
    final last = _lastScanAt;
    if (last != null && DateTime.now().difference(last).inSeconds < 30) return;
    await _scanAllInternal();
  }

  /// Abre la pantalla del sistema para conceder el permiso. Si queda
  /// concedido al volver, escanea de inmediato.
  Future<void> requestAllFilesAccess() async {
    final granted = await _storage.requestAllFilesAccess();
    if (!mounted) return;
    state = state.copyWith(allFilesGranted: granted);
    if (granted) await _scanAllInternal();
  }

  /// Escaneo manual de todo el storage. Idempotente contra el spinner.
  Future<void> scanStorageAll() async {
    if (state.scanning) return;
    await _scanAllInternal();
  }

  Future<void> _scanAllInternal() async {
    state = state.copyWith(scanning: true, scanError: null);
    try {
      final detected = await _storage.scanAll();
      if (!mounted) return;
      _lastScanAt = DateTime.now();
      final reconciled = _reconcileDetectedWithCatalog(detected);
      state = state.copyWith(
        scanning: false,
        models: reconciled.models,
        detected: reconciled.detected,
        scanError: null,
      );
    } on StateError {
      // El canal lanza StateError cuando el permiso MANAGE no está
      // concedido: mensaje propio, distinto del flujo SAF.
      if (!mounted) return;
      _lastScanAt = null;
      state = state.copyWith(
        scanning: false,
        scanError: 'Acceso al storage no concedido. Toca "Conceder acceso".',
      );
    } catch (e) {
      _scanFailed(e);
    }
  }

  Future<void> _scanInternal() async {
    state = state.copyWith(scanning: true, scanError: null);
    try {
      final detected = await _storage.scan();
      if (!mounted) return;
      _lastScanAt = DateTime.now();
      final reconciled = _reconcileDetectedWithCatalog(detected);
      state = state.copyWith(
        scanning: false,
        models: reconciled.models,
        detected: reconciled.detected,
        scanError: null,
      );
    } catch (e) {
      _scanFailed(e);
    }
  }

  /// Reconciles external storage findings with the downloadable catalog.
  ///
  /// A catalog model is considered installed when the exact catalog file is
  /// found with a direct readable path from MANAGE_EXTERNAL_STORAGE. SAF-only
  /// matches remain visible as detected cards because they need fd opening.
  _CatalogReconciliation _reconcileDetectedWithCatalog(
    List<DetectedModel> detected,
  ) {
    final detectedByName = {
      for (final model in detected)
        if (model.usable && model.path != null) model.name.toLowerCase(): model,
    };

    final reconciledModels = [
      for (final model in state.models)
        if (detectedByName[model.fileName.toLowerCase()] case final found?)
          model.copyWith(
            downloadState: ModelDownloadState.installed,
            progress: 1,
            localPath: found.path,
            clearError: true,
          )
        else
          model,
    ];

    final catalogNames = {
      for (final model in reconciledModels)
        if (model.installed) model.fileName.toLowerCase(),
    };
    final visibleDetected = [
      for (final model in detected)
        if (!catalogNames.contains(model.name.toLowerCase())) model,
    ];

    return _CatalogReconciliation(reconciledModels, visibleDetected);
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

  /// Usa un modelo detectado directamente desde su ubicación original.
  ///
  /// Con MANAGE_EXTERNAL_STORAGE el scanner devuelve el path absoluto: el
  /// worker (:nanoshell) lo abre directo y el engine lo lee con
  /// `--model <path>`. Cero copias de archivos pesados. Si vino del árbol
  /// SAF (sin path), se abre el fd en el worker (`/proc/self/fd/N`).
  Future<void> useDetected(DetectedModel model) async {
    // Permitimos intentar modelos aun cuando el scanner marque incompatibilidad
    // (ej. formato no GGUF o magic no válido). Se expone un aviso honesto en
    // scanError pero se deja al usuario probar el modelo. Evita bloquear la UI.
    if (state.loadingDetectedUri != null) return; // una apertura a la vez
    final directPath = model.path;
    state = state.copyWith(
      loadingDetectedUri: directPath ?? model.uri,
      scanError: null,
    );
    if (directPath != null) {
      if (!mounted) return;
      state = state.copyWith(loadingDetectedUri: null);
      if (!model.usable) {
        // Aviso honesto: modelo detectado no compatible, intentando de todos modos.
        state = state.copyWith(
          scanError: 'Modelo detectado no totalmente compatible: ${model.name}. Intentando cargar de todos modos.',
        );
      }
      _ref
          .read(chatProvider.notifier)
          .selectModel(model.name, path: directPath);
      return;
    }
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
      _ref.read(chatProvider.notifier).selectModel(model.name, path: fdPath);
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
