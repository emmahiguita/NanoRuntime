import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/core/services/nano_runtime_api.dart';
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

  // Último escaneo exitoso por vía: throttles independientes — un escaneo
  // SAF no debe impedir el escaneo completo del storage (y viceversa).
  DateTime? _lastSafScanAt;
  DateTime? _lastAllScanAt;

  // Última lista detectada exitosa: permite reconciliar el catálogo cuando
  // listModels termina DESPUÉS del escaneo (race del arranque).
  List<DetectedModel>? _lastDetected;

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
      final lastDetected = _lastDetected;
      // Si el escaneo terminó primero, reconcilia de inmediato: sin esto el
      // catálogo sobrescribiría la lista con modelos sin reconciliar.
      state = lastDetected != null && !state.scanning
          ? _applyScan(lastDetected, models: models)
          : state.copyWith(models: models);
    } catch (e) {
      debugPrint('[models] listModels falló: $e');
    }
  }

  /// Descarga real del GGUF (URL HuggingFace + SHA256 obligatorio).
  ///
  /// Estados: notInstalled → downloading (progress) → verifying → installed,
  /// o failed con mensaje honesto. Cancelable con [cancelDownload].
  Future<void> downloadModel(String id) async {
    // firstWhere sin orElse lanza StateError si el catálogo aún no cargó
    // (race de arranque) o el id no existe; guardamos en vez de tirar.
    LocalModel? item;
    for (final model in state.models) {
      if (model.id == id) {
        item = model;
        break;
      }
    }
    if (item == null) return;
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
  void loadModel(String id, {bool confirmedExtreme = false}) {
    LocalModel? item;
    for (final model in state.models) {
      if (model.id == id) {
        item = model;
        break;
      }
    }
    if (item == null || !item.installed || item.localPath == null) return;
    state = state.copyWith(
      models: [
        for (final model in state.models)
          model.copyWith(active: model.id == id, loading: model.id == id),
      ],
      activeDetected: null,
    );
    _ref
        .read(chatProvider.notifier)
        .selectModel(
          item.name,
          path: item.localPath,
          confirmedExtreme: confirmedExtreme,
        );
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
  /// concedido y el último escaneo SAF tiene más de 30 s (no re-walkear
  /// el storage en cada navegación). Se llama DESPUÉS de [maybeAutoScanAll]:
  /// si el acceso completo está concedido, el árbol SAF es subconjunto del
  /// storage compartido y no se re-walkea.
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
    if (state.allFilesGranted) return;
    final last = _lastSafScanAt;
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
    final last = _lastAllScanAt;
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
    if (state.scanning) return; // un escaneo a la vez, da igual la vía
    state = state.copyWith(scanning: true, scanError: null);
    try {
      final detected = await _storage.scanAll();
      if (!mounted) return;
      _lastAllScanAt = DateTime.now();
      state = _applyScan(detected);
    } on StateError {
      // El canal lanza StateError cuando el permiso MANAGE no está
      // concedido: mensaje propio, distinto del flujo SAF.
      if (!mounted) return;
      _lastAllScanAt = null;
      state = state.copyWith(
        scanning: false,
        scanError: 'Acceso al storage no concedido. Toca "Conceder acceso".',
      );
    } catch (e) {
      _scanFailed(e);
    }
  }

  Future<void> _scanInternal() async {
    if (state.scanning) return; // un escaneo a la vez, da igual la vía
    state = state.copyWith(scanning: true, scanError: null);
    try {
      final detected = await _storage.scan();
      if (!mounted) return;
      _lastSafScanAt = DateTime.now();
      state = _applyScan(detected);
    } catch (e) {
      _scanFailed(e);
    }
  }

  /// Aplica una lista detectada al estado: reconcilia el catálogo (con
  /// [models] si se pasa, p. ej. cuando _load termina después del escaneo)
  /// y expone las tarjetas detected restantes.
  ModelsState _applyScan(
    List<DetectedModel> detected, {
    List<LocalModel>? models,
  }) {
    _lastDetected = detected;
    final reconciled = _reconcileDetectedWithCatalog(detected, models: models);
    return state.copyWith(
      scanning: false,
      models: reconciled.models,
      detected: reconciled.detected,
      scanError: null,
    );
  }

  /// Reconciles external storage findings with the downloadable catalog.
  ///
  /// A catalog model is considered installed when the exact catalog file is
  /// found with a direct readable path from MANAGE_EXTERNAL_STORAGE AND its
  /// size matches the catalog (±10%): sin eso, un archivo corrupto o distinto
  /// con el mismo nombre se marcaría instalado sin verificación de hash.
  /// SAF-only matches remain visible as detected cards because they need fd
  /// opening.
  _CatalogReconciliation _reconcileDetectedWithCatalog(
    List<DetectedModel> detected, {
    List<LocalModel>? models,
  }) {
    final current = models ?? state.models;
    final detectedByName = {
      for (final model in detected)
        if (model.usable && model.path != null) model.name.toLowerCase(): model,
    };

    final reconciledModels = [
      for (final model in current)
        if (detectedByName[model.fileName.toLowerCase()] case final found?
            when _sizeMatchesCatalog(model, found))
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

  /// El tamaño del archivo detectado debe coincidir con el declarado en el
  /// catálogo (±10%: los sizeGb son aproximados). Sin coincidencia no se
  /// marca el catálogo instalado: el archivo queda como tarjeta detected
  /// para uso directo, con aviso honesto en la tarjeta.
  bool _sizeMatchesCatalog(LocalModel catalog, DetectedModel found) {
    if (found.sizeBytes <= 0) return false;
    final expectedBytes = catalog.sizeGb * 1024 * 1024 * 1024;
    final delta = (found.sizeBytes - expectedBytes).abs();
    return delta <= expectedBytes * 0.10;
  }

  void _scanFailed(Object e) {
    if (!mounted) return;
    _lastSafScanAt = null;
    _lastAllScanAt = null;
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
  ///
  /// Se permite intentar modelos aunque el scanner marque incompatibilidad
  /// (formato no GGUF o magic no válido): el aviso honesto vive en la tarjeta
  /// detected (_DetectedCard), no en scanError, que es exclusivo del escaneo.
  Future<void> useDetected(DetectedModel model) async {
    if (state.loadingDetectedUri != null) return; // una apertura a la vez
    final directPath = model.path;
    state = state.copyWith(loadingDetectedUri: directPath ?? model.uri);
    if (directPath != null) {
      // El storage externo (FUSE) es lento para el acceso random de pesos
      // (mmap + dequant por token). Copiar al storage interno de la app antes
      // de cargar: el mismo modelo pasa de lento a ~5 tok/s.
      final internalPath = await _copyToInternal(directPath, model.name);
      if (!mounted) return;
      if (internalPath == null) {
        state = state.copyWith(
          loadingDetectedUri: null,
          scanError: 'No se pudo copiar ${model.name} al storage interno.',
        );
        return;
      }
      state = state.copyWith(
        loadingDetectedUri: null,
        activeDetected: model.name,
      );
      _ref
          .read(chatProvider.notifier)
          .selectModel(model.name, path: internalPath);
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
      state = state.copyWith(
        loadingDetectedUri: null,
        activeDetected: model.name,
      );
      _ref.read(chatProvider.notifier).selectModel(model.name, path: fdPath);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(
        loadingDetectedUri: null,
        scanError: 'No se pudo abrir ${model.name}: $e',
      );
    }
  }

  /// Copia un GGUF del storage externo al interno de la app (files/nano/models/).
  /// El externo vía FUSE es lento para el acceso random de pesos; el interno
  /// permite mmap rápido. Idempotente: si ya existe con el mismo tamaño, no
  /// recopia.
  Future<String?> _copyToInternal(String srcPath, String name) async {
    try {
      final filesDir = await NanoRuntimeApi.instance.getFilesDir();
      if (filesDir == null) return null;
      final destDir = '$filesDir/models';
      await Directory(destDir).create(recursive: true);
      final dest = '$destDir/$name';
      final destFile = File(dest);
      final srcFile = File(srcPath);
      if (await destFile.exists() &&
          await destFile.length() == await srcFile.length()) {
        return dest;
      }
      await srcFile.copy(dest);
      return dest;
    } catch (e) {
      debugPrint('[models] copy to internal falló: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _downloader.dispose();
    super.dispose();
  }
}
