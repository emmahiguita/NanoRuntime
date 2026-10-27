// nano_media_downloader.dart — Gestor de descargas organizadas para Nano Media.
// QUÉ: Descarga archivos multimedia individuales o en lote hacia almacenamiento local.
// CÓMO: Descarga vía streaming con archivo temporal '.part', reanudación segura y movimiento
//       atómico al destino final organizado por categoría (/Download/NanoAI/{Videos, Imagenes, Audios}).
// POR QUÉ: No satura RAM, previene archivos corruptos y cumple Scoped Storage de Android.
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'nano_ai_models.dart';
import 'nano_media_detector.dart';
part 'nano_media_download_transfer.dart';

class NanoMediaDownloader {
  NanoMediaDownloader({
    http.Client? client,
    String? basePath,
    MethodChannel? channel,
  }) : _ownsClient = client == null,
       _client = client ?? http.Client(),
       _basePath = basePath ?? '/storage/emulated/0/Download/NanoAI',
       _channel = channel ?? const MethodChannel('dev.nanoai/floating');

  final http.Client _client;
  final bool _ownsClient;
  final String _basePath;
  final MethodChannel _channel;
  final _operations = <_NanoDownloadOperation>{};
  bool _disposed = false;

  /// Detiene transferencias Dart y lotes; Android no ofrece cancelación aquí.
  /// La señal también impide iniciar un fallback tras un resultado incierto.
  void cancelActive() {
    for (final operation in _operations) {
      operation.cancel();
    }
  }

  /// Solo cierra el cliente construido aquí; el cliente inyectado tiene dueño.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancelActive();
    if (_ownsClient) _client.close();
  }

  /// Registra cada operación para cancelarla sin cerrar clientes compartidos.
  _NanoDownloadOperation _beginOperation() {
    if (_disposed) throw StateError('El descargador está cerrado.');
    final operation = _NanoDownloadOperation();
    _operations.add(operation);
    return operation;
  }

  /// Descarga [resource] hacia la subcarpeta correspondiente según su tipo.
  /// Si proviene de redes sociales (YouTube, FB, X, Instagram, TikTok),
  /// delega primero al DownloadManager nativo de Android e indexa en Galería.
  Future<File> download(
    NanoMediaResource resource, {
    void Function(double progress)? onProgress,
  }) async {
    final operation = _beginOperation();
    try {
      return await _download(resource, operation, onProgress: onProgress);
    } finally {
      _operations.remove(operation);
    }
  }

  /// Comparte cancelación con el lote y no reintenta una petición nativa enviada.
  Future<File> _download(
    NanoMediaResource resource,
    _NanoDownloadOperation operation, {
    void Function(double progress)? onProgress,
  }) async {
    operation.check();
    final sourceOrUrl = resource.sourceUrl ?? resource.url;
    if (NanoMediaDetector.isSocialMediaUrl(sourceOrUrl)) {
      try {
        final res = await operation.wait(
          _channel.invokeMethod<Map<Object?, Object?>>('downloadMedia', {
            'url': resource.url,
            'audioOnly': resource.type == NanoMediaType.audio,
          }),
        );
        operation.check();
        if (res != null && res['ok'] == true) {
          onProgress?.call(1.0);
          final nativePath =
              (res['path'] as String?) ??
              '$_basePath/${resource.type == NanoMediaType.audio ? "Audios" : "Videos"}/${_sanitizeFilename(resource.title, resource.url, resource.type)}';
          return File(nativePath);
        }
        throw StateError(
          'Android no confirmó la descarga; revisa su resultado.',
        );
      } on MissingPluginException {
        // No existe receptor nativo: ninguna descarga externa se inició.
        operation.check();
      }
    }
    return _downloadHttp(resource, operation, onProgress);
  }

  /// Ejecuta un lote secuencial; cancelar impide despachar los archivos restantes.
  Future<List<File>> downloadBatch(
    List<NanoMediaResource> items, {
    void Function(int current, int total)? onProgressItem,
  }) async {
    final operation = _beginOperation();
    final results = <File>[];
    try {
      for (int i = 0; i < items.length && !operation.cancelled; i++) {
        onProgressItem?.call(i + 1, items.length);
        try {
          final file = await _download(items[i], operation);
          operation.check();
          results.add(file);
        } catch (_) {
          if (operation.cancelled) break;
          // Un fallo individual no reintenta el mismo recurso.
        }
      }
      return results;
    } finally {
      _operations.remove(operation);
    }
  }

  /// Conserva nombres válidos y la extensión resuelta por el tipo del recurso.
  String _sanitizeFilename(String title, String url, NanoMediaType type) {
    var name = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    if (name.isEmpty || name.length > 50) {
      name = 'nano_${DateTime.now().millisecondsSinceEpoch}';
    }
    final ext = _resolveExtension(url, type);
    if (!name.toLowerCase().endsWith('.$ext')) {
      name = '$name.$ext';
    }
    return name;
  }

  /// Usa una extensión de URL acotada o el formato canónico del tipo detectado.
  String _resolveExtension(String url, NanoMediaType type) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.path.contains('.')) {
      final ext = uri.path.split('.').last.toLowerCase();
      if (ext.length >= 3 && ext.length <= 4) return ext;
    }
    return switch (type) {
      NanoMediaType.video => 'mp4',
      NanoMediaType.image => 'jpg',
      NanoMediaType.audio => 'mp3',
      NanoMediaType.document => 'pdf',
    };
  }
}
