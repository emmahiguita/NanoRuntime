import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nanoai/core/models/catalog_models.dart';
import 'package:nanoai/core/providers/chat_provider.dart';
import 'package:nanoai/features/models/application/models_state.dart';
import 'package:nanoai/features/models/data/catalog_local_model_repository.dart';
import 'package:nanoai/features/models/data/channel_model_storage_repository.dart';
import 'package:nanoai/features/models/data/model_downloader.dart';
import 'package:nanoai/features/models/data/model_integrity.dart';
import 'package:nanoai/features/models/domain/detected_model.dart';
import 'package:nanoai/features/models/domain/local_model.dart';
import 'package:nanoai/features/models/domain/local_model_repository.dart';
import 'package:nanoai/features/models/domain/model_storage_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nanoai/core/services/whisper_stt_service.dart';

/// MODELS-CAT-01 — pref de la carpeta de descarga elegida por el usuario.
/// Las descargas quedan en el almacenamiento del dispositivo (externo) y
/// sobreviven reinstalaciones del APK, a diferencia del storage interno.
const _downloadDirPrefKey = 'nanoai_model_download_dir';

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
      final downloadDir = await _loadDownloadDirPref();
      var models = await _repository.listModels();
      if (downloadDir != null) {
        final verified = <LocalModel>[];
        for (final model in models) {
          final file = File('$downloadDir/${model.fileName}');
          final installed =
              !model.installed &&
              await ModelIntegrity.verify(file, model.sha256);
          verified.add(
            installed
                ? model.copyWith(
                    downloadState: ModelDownloadState.installed,
                    progress: 1,
                    localPath: file.path,
                    clearError: true,
                  )
                : model,
          );
        }
        models = verified;
      }
      if (!mounted) return;
      final lastDetected = _lastDetected;
      // Si el escaneo terminó primero, reconcilia de inmediato: sin esto el
      // catálogo sobrescribiría la lista con modelos sin reconciliar.
      state = lastDetected != null && !state.scanning
          ? _applyScan(
              lastDetected,
              models: models,
            ).copyWith(downloadDir: downloadDir)
          : state.copyWith(models: models, downloadDir: downloadDir);
    } catch (e) {
      debugPrint('[models] listModels falló: $e');
    }
  }

  Future<String?> _loadDownloadDirPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_downloadDirPrefKey);
    } catch (e) {
      debugPrint('[models] leer downloadDir falló: $e');
      return null;
    }
  }

  /// MODELS-CAT-01 — fija la carpeta de descarga elegida en el picker y la
  /// persiste: las descargas permanecen en el almacenamiento del dispositivo
  /// tras reiniciar la app. Null vuelve al destino interno por defecto.
  Future<void> setDownloadDir(String? path) async {
    state = state.copyWith(downloadDir: path);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (path == null) {
        await prefs.remove(_downloadDirPrefKey);
      } else {
        await prefs.setString(_downloadDirPrefKey, path);
      }
    } catch (e) {
      debugPrint('[models] persistir downloadDir falló: $e');
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
      final destPath = await _destPathFor(item);

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

  /// MODELS-CAT-01 — destino de descarga: la carpeta elegida por el usuario
  /// (storage externo permanente) si está configurada; si no, el interno de
  /// la app (comportamiento original). Si la carpeta elegida desapareció
  /// (SD expulsada, carpeta borrada), el error es honesto: sin fallback
  /// silencioso que dejaría el archivo en un lugar distinto al que el
  /// usuario eligió.
  Future<String> _destPathFor(LocalModel item) async {
    final chosen = state.downloadDir;
    if (chosen != null) {
      if (!await Directory(chosen).exists()) {
        throw DownloadException(
          'La carpeta elegida ya no existe: $chosen. Elige otra carpeta.',
        );
      }
      return '$chosen/${item.fileName}';
    }
    final dir = await _modelsDir();
    if (dir == null) {
      throw DownloadException(
        'getFilesDir no disponible — no se puede descargar',
      );
    }
    return '$dir/${item.fileName}';
  }

  /// Cancela la descarga en curso (token de cancelación cierra el stream).
  void cancelDownload() {
    final id = _downloadingId;
    if (id == null) return;
    _downloader.cancel();
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
  Future<void> loadModel(String id, {bool confirmedExtreme = false}) async {
    LocalModel? item;
    for (final model in state.models) {
      if (model.id == id) {
        item = model;
        break;
      }
    }
    // Permite cargar LLMs, modelos de visión multimodal y modelos de voz Whisper
    if (item == null ||
        (item.kind != ModelKind.llm &&
            item.kind != ModelKind.multimodalVision &&
            item.kind != ModelKind.voiceStt) ||
        !item.installed ||
        item.localPath == null) {
      return;
    }

    // Los modelos de voz Whisper (GGML) se activan en WhisperSttService,
    // separando el motor de audio del motor conversacional LLM (nanortime/llama.cpp)
    if (item.kind == ModelKind.voiceStt) {
      await WhisperSttService.instance.setActiveModel(
        item.fileName,
        item.localPath!,
      );
      state = state.copyWith(models: List.from(state.models));
      return;
    }

    // La selección empieza aquí, pero "activo" solo lo confirma el estado
    // ready del chat. No se publica éxito antes de que responda el motor.
    _ref
        .read(chatProvider.notifier)
        .selectModel(
          item.name,
          path: item.localPath,
          confirmedExtreme: confirmedExtreme,
        );
  }

  /// Desconecta el modelo activo del motor sin borrarlo del disco.
  /// Simétrico a loadModel: permite al usuario cambiar de modelo o liberar RAM.
  void unloadModel() {
    _ref.read(chatProvider.notifier).selectModel('', path: null);
  }

  /// Desactiva el modelo de voz Whisper activo sin borrar el archivo.
  Future<void> unloadVoiceModel() async {
    await WhisperSttService.instance.clearActiveModel();
    state = state.copyWith(models: List.from(state.models));
  }

  /// Elimina el archivo GGUF descargado del disco y resetea el estado del catálogo.
  /// Solo actúa si el modelo tiene path local conocido y no está en descarga activa.
  /// Simétrico a downloadModel: da al usuario control total del almacenamiento.
  Future<void> deleteModel(String id) async {
    LocalModel? item;
    for (final model in state.models) {
      if (model.id == id) {
        item = model;
        break;
      }
    }
    if (item == null || !item.installed || item.localPath == null) return;
    if (_downloadingId == id) return; // no borrar mientras descarga
    try {
      final file = File(item.localPath!);
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('[models] deleteModel falló: $e');
    }
    // Reseta al estado sin instalar independientemente del resultado del delete
    _update(
      id,
      downloadState: ModelDownloadState.notInstalled,
      progress: 0,
      clearError: true,
    );
    // Si el modelo eliminado era el activo, lo desconecta del motor
    final active = _ref.read(chatProvider).activeModel;
    if (active.toLowerCase().contains(item.name.toLowerCase())) unloadModel();
    if (WhisperSttService.instance.activeModelFile == item.fileName) {
      await WhisperSttService.instance.clearActiveModel();
    }
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
  /// Un modelo del catálogo solo queda instalado si el archivo directo tiene
  /// tamaño plausible y un manifiesto SHA-256 todavía válido. Nombre y tamaño
  /// por sí solos no constituyen evidencia de integridad.
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
    if (delta > expectedBytes * 0.10 || found.path == null) return false;
    return ModelIntegrity.hasTrustedManifest(File(found.path!), catalog.sha256);
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
  /// La UI solo llama esta ruta para un GGUF cuya cabecera validó el escáner.
  Future<void> useDetected(DetectedModel model) async {
    // La regla también vive en aplicación: otro caller no puede saltarse la UI
    // y enviar ONNX/TFLite o un GGUF inválido al runtime llama.cpp.
    if (!model.usable) {
      state = state.copyWith(
        scanError:
            'Archivo incompatible: Nano requiere una cabecera GGUF válida.',
      );
      return;
    }
    if (state.loadingDetectedUri != null) return; // una apertura a la vez
    final directPath = model.path;
    state = state.copyWith(loadingDetectedUri: directPath ?? model.uri);
    if (directPath != null) {
      // RENDIMIENTO ZERO-COPY: Ejecución honesta directa desde SD card o storage externo.
      // Elimina la copia de 4GB-8GB que causaba saturación de disco, timeouts y bloqueos.
      // nanortime y llama.cpp operan con acceso directo a la ruta física.
      try {
        state = state.copyWith(loadingDetectedUri: null, scanError: null);
        _ref
            .read(chatProvider.notifier)
            .selectModel(model.name, path: directPath);
      } catch (e) {
        if (!mounted) return;
        state = state.copyWith(
          loadingDetectedUri: null,
          scanError: 'No se pudo activar ${model.name}: $e',
        );
      }
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

  /// Copia un GGUF del storage externo al directorio canónico
  /// SD & EXTERNAL STORAGE: Permite al usuario elegir directamente cualquier archivo
  /// de modelo (.gguf) desde su tarjeta SD, descargas o USB OTG.
  /// Valida cabecera GGUF, crea el DetectedModel honesto y lo activa sin copias.
  Future<bool> pickCustomModelFile() async {
    try {
      final result = await FilePicker.pickFiles(type: FileType.any);
      if (result == null || result.files.isEmpty) return false;
      final pickedPath = result.files.single.path;
      if (pickedPath == null || pickedPath.isEmpty) return false;

      final file = File(pickedPath);
      if (!await file.exists()) return false;

      final len = await file.length();
      if (len < 24) {
        if (mounted) {
          state = state.copyWith(
            scanError:
                'El archivo es demasiado pequeño para ser un modelo GGUF válido.',
          );
        }
        return false;
      }

      // Valida cabecera GGUF (0x47, 0x47, 0x55, 0x46)
      final headerBytes = await file.openRead(0, 4).first;
      final isGguf =
          headerBytes.length >= 4 &&
          headerBytes[0] == 0x47 &&
          headerBytes[1] == 0x47 &&
          headerBytes[2] == 0x55 &&
          headerBytes[3] == 0x46;

      if (!isGguf) {
        if (mounted) {
          state = state.copyWith(
            scanError:
                'El archivo seleccionado no contiene una cabecera GGUF válida.',
          );
        }
        return false;
      }

      final fileName = file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : 'modelo_externo.gguf';

      final customModel = DetectedModel(
        name: fileName,
        sizeBytes: len,
        uri: file.uri.toString(),
        format: DetectedModelFormat.gguf,
        magicOk: true,
        path: file.path,
      );

      final updatedDetected = [
        customModel,
        for (final m in state.detected)
          if (m.path != customModel.path) m,
      ];

      state = state.copyWith(detected: updatedDetected, scanError: null);

      await useDetected(customModel);
      return true;
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          scanError: 'Error al abrir modelo desde almacenamiento: $e',
        );
      }
      return false;
    }
  }

  @override
  void dispose() {
    _downloader.dispose();
    super.dispose();
  }
}
