// models_notifier.dart — Notificador de estado del catálogo neural móvil.
// QUÉ HACE: Administra catálogo, descargas, selección y eliminación de modelos locales y SD.
// CÓMO FUNCIONA: Orquesta servicios especializados delegando escaneo, descarga y ciclo de vida.
// POR QUÉ: Centraliza la reactividad de la UI asegurando arquitectura limpia y código < 200 líneas.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_model_picker_service.dart';
import 'models_download_service.dart';
import 'models_lifecycle_delegate.dart';
import 'models_reconciliation_service.dart';
import 'models_scan_coordinator.dart';
import 'models_state.dart';
import '../data/hugging_face_gguf_import_service.dart';
import '../data/catalog_local_model_repository.dart';
import '../data/channel_model_storage_repository.dart';
import '../domain/detected_model.dart';
import '../domain/local_model.dart';
import '../domain/local_model_repository.dart';
import '../domain/model_storage_repository.dart';

const _downloadDirPrefKey = 'nanoai_model_download_dir';
const _huggingFaceImportsPrefKey = 'nanoai_huggingface_gguf_imports';

class ModelsNotifier extends StateNotifier<ModelsState> {
  final Ref _ref;
  final LocalModelRepository _repository;
  final ModelsDownloadService _downloader;
  final ModelsScanCoordinator _scanner;
  final Future<String?> Function() _modelsDir;
  final _reconciler = const ModelsReconciliationService(),
      _lifecycle = const ModelsLifecycleDelegate(),
      _picker = const CustomModelPickerService();
  final _huggingFaceImporter = const HuggingFaceGgufImportService();
  String? _downloadingId;
  List<DetectedModel>? _lastDetected;
  List<DetectedModel> _huggingFaceImports = const [];
  bool _importingHuggingFace = false;

  ModelsNotifier(
    this._ref,
    this._repository, {
    ModelsDownloadService? downloader,
    ModelStorageRepository? storage,
    Future<String?> Function()? modelsDir,
  }) : _downloader = downloader ?? ModelsDownloadService(),
       _scanner = ModelsScanCoordinator(
         storage: storage ?? const ChannelModelStorageRepository(),
       ),
       _modelsDir = modelsDir ?? CatalogLocalModelRepository.modelsDir,
       super(
         ModelsState(models: CatalogLocalModelRepository.initialCatalog()),
       ) {
    _load();
  }

  // QUÉ HACE: Carga el catálogo base y verifica archivos instalados en disco.
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dir = prefs.getString(_downloadDirPrefKey);
      _huggingFaceImports = await _readHuggingFaceImports(prefs);
      final raw = await _repository.listModels();
      final models = await _reconciler.verifyConfiguredDirectory(raw, dir);
      if (!mounted) return;
      state = _lastDetected != null && !state.scanning
          ? _applyScan(
              _lastDetected!,
              models: models,
            ).copyWith(downloadDir: dir)
          : state.copyWith(
              models: models,
              detected: _mergeDetected(state.detected, _huggingFaceImports),
              downloadDir: dir,
            );
    } catch (e) {
      debugPrint('[models] listModels falló: $e');
    }
  }

  // QUÉ HACE: Establece y persiste la carpeta personalizada de descargas.
  Future<void> setDownloadDir(String? path) async {
    state = state.copyWith(downloadDir: path);
    final prefs = await SharedPreferences.getInstance();
    path == null
        ? await prefs.remove(_downloadDirPrefKey)
        : await prefs.setString(_downloadDirPrefKey, path);
  }

  // QUÉ HACE: Inicia la descarga HTTP/HF de un modelo con verificación hash progresiva.
  Future<void> downloadModel(String id) async {
    final item = state.models.where((m) => m.id == id).firstOrNull;
    if (item == null || item.installed || _downloadingId != null) return;
    _downloadingId = id;
    await _downloader.startDownload(
      item: item,
      configuredDir: state.downloadDir,
      defaultDirGetter: _modelsDir,
      onUpdate: (st, p, {path, error}) {
        if (!mounted) return;
        if (st == ModelDownloadState.installed ||
            st == ModelDownloadState.failed) {
          _downloadingId = null;
        }
        _update(
          id,
          downloadState: st,
          progress: p,
          localPath: path,
          error: error,
          clearError: st == ModelDownloadState.installed,
        );
      },
    );
  }

  // QUÉ HACE: Cancela la descarga activa liberando sockets.
  void cancelDownload() {
    _downloader.cancel();
    if (_downloadingId != null) {
      _update(
        _downloadingId!,
        downloadState: ModelDownloadState.failed,
        progress: 0,
        error: 'descarga cancelada',
      );
      _downloadingId = null;
    }
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
        for (final m in state.models)
          m.id == id
              ? m.copyWith(
                  downloadState: downloadState,
                  progress: progress,
                  localPath: localPath,
                  error: error,
                  clearError: clearError,
                )
              : m,
      ],
    );
  }

  // QUÉ HACE: Carga el modelo en el motor de inferencia local o Whisper.
  Future<void> loadModel(String id, {bool confirmedExtreme = false}) async {
    final item = state.models.where((m) => m.id == id).firstOrNull;
    if (item != null &&
        await _lifecycle.loadModel(
          ref: _ref,
          item: item,
          confirmedExtreme: confirmedExtreme,
        )) {
      state = state.copyWith(models: List.from(state.models));
    }
  }

  Future<void> unloadModel() async {
    await _lifecycle.unloadModel(_ref);
    if (mounted) state = state.copyWith(models: List.from(state.models));
  }

  Future<void> unloadVoiceModel() async {
    await _lifecycle.unloadVoiceModel();
    if (mounted) state = state.copyWith(models: List.from(state.models));
  }

  // QUÉ HACE: Elimina el binario de disco y actualiza el estado.
  Future<bool> deleteModel(String id) async {
    final item = state.models.where((m) => m.id == id).firstOrNull;
    if (item == null || _downloadingId == id) return false;
    // Mantiene el estado instalado si el motor no se detuvo o el borrado falló.
    final deleted = await _lifecycle.deleteModel(ref: _ref, item: item);
    if (deleted) {
      _update(
        id,
        downloadState: ModelDownloadState.notInstalled,
        progress: 0,
        clearError: true,
      );
    }
    return deleted;
  }

  Future<bool> deleteDetectedModel(
    DetectedModel model, {
    bool deletePhysicalFile = true,
  }) async {
    // Mantiene el modelo visible si el motor o el borrado físico no terminaron bien.
    final deleted = await _lifecycle.deleteDetectedModel(
      ref: _ref,
      model: model,
      deletePhysicalFile: deletePhysicalFile,
    );
    if (deleted) {
      _huggingFaceImports = _huggingFaceImports
          .where((m) => m.path != model.path && m.uri != model.uri)
          .toList(growable: false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _huggingFaceImportsPrefKey,
        _huggingFaceImports
            .where((m) => m.path != null)
            .map(
              (m) => jsonEncode({
                'name': m.name,
                'sizeBytes': m.sizeBytes,
                'path': m.path,
              }),
            )
            .toList(),
      );
      state = state.copyWith(
        detected: state.detected
            .where((m) => m.path != model.path && m != model)
            .toList(),
      );
    }
    return deleted;
  }

  // QUÉ HACE: Escaneos de almacenamiento SAF y general con auto-detección y permisos.
  Future<void> scanStorage() => _runScan(_scanner.scanSaf);
  Future<void> scanStorageAll() => _runScan(_scanner.scanAll);
  Future<void> pickTreeAndScan() async =>
      (state.scanning || await _scanner.pickTree() == null)
      ? null
      : scanStorage();

  Future<void> maybeAutoScan() async {
    final tree = await _scanner.persistedTree();
    if (mounted) state = state.copyWith(treeGranted: tree != null);
    if (tree != null &&
        !state.allFilesGranted &&
        !_scanner.shouldThrottleSafScan()) {
      await scanStorage();
    }
  }

  Future<void> maybeAutoScanAll() async {
    final granted = await _scanner.hasAllFilesAccess();
    if (mounted) state = state.copyWith(allFilesGranted: granted);
    if (granted && !_scanner.shouldThrottleAllScan()) await scanStorageAll();
  }

  Future<void> requestAllFilesAccess() async {
    final granted = await _scanner.requestAllFilesAccess();
    if (mounted) state = state.copyWith(allFilesGranted: granted);
    if (granted) await scanStorageAll();
  }

  Future<void> refreshCatalogAndStorage() async {
    final granted = await _scanner.hasAllFilesAccess();
    if (mounted) state = state.copyWith(allFilesGranted: granted);
    await _load();
    granted ? await scanStorageAll() : await maybeAutoScan();
  }

  Future<void> _runScan(Future<List<DetectedModel>> Function() scanner) async {
    if (state.scanning) return;
    state = state.copyWith(scanning: true, scanError: null);
    try {
      final detected = await scanner();
      if (mounted) state = _applyScan(detected);
    } catch (e) {
      if (!mounted) return;
      _scanner.resetThrottles();
      state = state.copyWith(
        scanning: false,
        scanError: e is StateError ? 'Permiso requerido.' : 'Escaneo falló: $e',
      );
    }
  }

  ModelsState _applyScan(
    List<DetectedModel> detected, {
    List<LocalModel>? models,
  }) {
    _lastDetected = detected;
    final r = _reconciler.reconcile(
      detected,
      currentModels: models ?? state.models,
    );
    return state.copyWith(
      scanning: false,
      models: r.models,
      detected: _mergeDetected(r.detected, _huggingFaceImports),
      scanError: null,
    );
  }

  Future<List<HuggingFaceGgufArtifact>> inspectHuggingFaceLink(String url) =>
      _huggingFaceImporter.inspect(url);

  /// Downloads one checksum-verified GGUF from a repository or file link.
  /// GGUF validity identifies the format; its task/runtime suitability remains
  /// unverified until the user tries it from the local-model card.
  Future<DetectedModel> importHuggingFaceArtifact(
    HuggingFaceGgufArtifact artifact, {
    void Function(double progress)? onProgress,
  }) async {
    if (_importingHuggingFace) {
      throw StateError('Ya hay una importación de Hugging Face en curso.');
    }
    _importingHuggingFace = true;
    try {
      final directory = state.downloadDir ?? await _modelsDir();
      if (directory == null || directory.isEmpty) {
        throw StateError('No se pudo encontrar la carpeta local de modelos.');
      }
      await Directory(directory).create(recursive: true);
      final safeRepo = artifact.repoId.replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );
      final fileName =
          '${safeRepo}__${artifact.fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')}';
      final destination = '$directory${Platform.pathSeparator}$fileName';
      if (await File(destination).exists()) {
        throw StateError('Ese archivo ya existe en la carpeta de modelos.');
      }

      final path = await _huggingFaceImporter.download(
        artifact: artifact,
        destinationPath: destination,
        onProgress: onProgress,
      );
      final file = File(path);
      final length = await file.length();
      final magic = await file.openRead(0, 4).first;
      final isGguf =
          length >= 24 &&
          magic.length >= 4 &&
          magic[0] == 0x47 &&
          magic[1] == 0x47 &&
          magic[2] == 0x55 &&
          magic[3] == 0x46;
      if (!isGguf) {
        await file.delete();
        throw const FormatException(
          'El archivo descargado no tiene una cabecera GGUF válida.',
        );
      }

      final imported = DetectedModel(
        name: fileName,
        sizeBytes: length,
        uri: file.uri.toString(),
        format: DetectedModelFormat.gguf,
        magicOk: true,
        path: file.path,
      );
      _huggingFaceImports = _mergeDetected(_huggingFaceImports, [imported]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _huggingFaceImportsPrefKey,
        _huggingFaceImports
            .where((model) => model.path != null)
            .map(
              (model) => jsonEncode({
                'name': model.name,
                'sizeBytes': model.sizeBytes,
                'path': model.path,
              }),
            )
            .toList(),
      );
      if (mounted) {
        state = state.copyWith(
          detected: _mergeDetected(state.detected, [imported]),
          scanError: null,
        );
      }
      return imported;
    } finally {
      _importingHuggingFace = false;
    }
  }

  Future<List<DetectedModel>> _readHuggingFaceImports(
    SharedPreferences prefs,
  ) async {
    final models = <DetectedModel>[];
    for (final raw
        in prefs.getStringList(_huggingFaceImportsPrefKey) ?? const []) {
      try {
        final data = jsonDecode(raw);
        if (data is! Map<String, dynamic>) continue;
        final path = data['path'] as String?;
        if (path == null) continue;
        final file = File(path);
        if (!await file.exists() || await file.length() < 24) continue;
        final magic = await file.openRead(0, 4).first;
        if (magic.length < 4 ||
            magic[0] != 0x47 ||
            magic[1] != 0x47 ||
            magic[2] != 0x55 ||
            magic[3] != 0x46) {
          continue;
        }
        models.add(
          DetectedModel(
            name: data['name'] as String? ?? file.uri.pathSegments.last,
            sizeBytes: await file.length(),
            uri: file.uri.toString(),
            format: DetectedModelFormat.gguf,
            magicOk: true,
            path: path,
          ),
        );
      } catch (error) {
        debugPrint('[models] Importación HF guardada inválida: $error');
      }
    }
    return models;
  }

  List<DetectedModel> _mergeDetected(
    List<DetectedModel> first,
    List<DetectedModel> second,
  ) {
    final byPath = <String, DetectedModel>{};
    for (final model in [...first, ...second]) {
      final key = model.path ?? model.uri;
      byPath[key] = model;
    }
    return byPath.values.toList(growable: false);
  }

  // QUÉ HACE: Activa un modelo detectado en tarjeta SD o ruta externa.
  Future<void> useDetected(DetectedModel model) async {
    if (!model.usable) {
      state = state.copyWith(
        scanError: 'Archivo incompatible: se requiere cabecera GGUF válida.',
      );
      return;
    }
    if (state.loadingDetectedUri != null) return;
    if (model.path == null) {
      state = state.copyWith(loadingDetectedUri: model.uri);
    }
    try {
      await _lifecycle.useDetected(
        ref: _ref,
        model: model,
        openFd: _scanner.openFd,
      );
    } catch (e) {
      if (mounted) {
        state = state.copyWith(scanError: 'No se pudo abrir ${model.name}: $e');
      }
    } finally {
      if (mounted && model.path == null) {
        state = state.copyWith(loadingDetectedUri: null);
      }
    }
  }

  Future<bool> pickCustomModelFile() async {
    final model = await _picker.pickModel();
    if (model == null) return false;
    state = state.copyWith(
      detected: [
        model,
        for (final m in state.detected)
          if (m.path != model.path) m,
      ],
      scanError: null,
    );
    await useDetected(model);
    return true;
  }

  @override
  void dispose() {
    _downloader.dispose();
    super.dispose();
  }
}
