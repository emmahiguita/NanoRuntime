// models_download_service.dart — Coordinador de descargas y verificación de integridad.
// QUÉ HACE: Descarga archivos GGUF en streaming con progreso, verificación SHA-256 y destino configurable.
// CÓMO FUNCIONA: Conecta con ModelDownloader, valida paths y maneja tokens de cancelación únicos.
// POR QUÉ: Evita saturación de hilos y cuellos de botella de I/O manteniendo < 200 líneas.
library;

import 'dart:io';
import '../data/model_downloader.dart';
import '../domain/local_model.dart';

typedef DownloadUpdateCallback = void Function(
  ModelDownloadState state,
  double progress, {
  String? path,
  String? error,
});

class ModelsDownloadService {
  final ModelDownloader _downloader;
  bool _isCancelled = false;

  ModelsDownloadService({ModelDownloader? downloader})
      : _downloader = downloader ?? ModelDownloader();

  Future<void> startDownload({
    required LocalModel item,
    required String? configuredDir,
    required Future<String?> Function() defaultDirGetter,
    required DownloadUpdateCallback onUpdate,
  }) async {
    _isCancelled = false;
    onUpdate(ModelDownloadState.downloading, 0);

    try {
      final destPath = await resolveDestinationPath(
        item,
        configuredDir: configuredDir,
        defaultDirGetter: defaultDirGetter,
      );

      final file = await _downloader.download(
        url: item.url,
        destPath: destPath,
        expectedSha256: item.sha256,
        onProgress: (p) => onUpdate(ModelDownloadState.downloading, p),
        onVerifying: () => onUpdate(ModelDownloadState.verifying, 1.0),
        cancelToken: () async => _isCancelled,
      );

      onUpdate(ModelDownloadState.installed, 1.0, path: file.path);
    } catch (e) {
      onUpdate(ModelDownloadState.failed, 0, error: '$e');
    }
  }

  Future<String> resolveDestinationPath(
    LocalModel item, {
    required String? configuredDir,
    required Future<String?> Function() defaultDirGetter,
  }) async {
    if (configuredDir != null) {
      if (!await Directory(configuredDir).exists()) {
        throw DownloadException(
          'La carpeta elegida ya no existe: $configuredDir. Elige otra carpeta.',
        );
      }
      return '$configuredDir/${item.fileName}';
    }
    final dir = await defaultDirGetter();
    if (dir == null) {
      throw DownloadException(
        'getFilesDir no disponible — no se puede descargar',
      );
    }
    return '$dir/${item.fileName}';
  }

  void cancel() {
    _isCancelled = true;
    _downloader.cancel();
  }

  void dispose() {
    _downloader.dispose();
  }
}
