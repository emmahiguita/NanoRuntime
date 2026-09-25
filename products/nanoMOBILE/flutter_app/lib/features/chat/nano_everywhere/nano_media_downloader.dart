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

class NanoMediaDownloader {
  NanoMediaDownloader({
    http.Client? client,
    String? basePath,
    MethodChannel? channel,
  })  : _client = client ?? http.Client(),
        _basePath = basePath ?? '/storage/emulated/0/Download/NanoAI',
        _channel = channel ?? const MethodChannel('dev.nanoai/floating');

  final http.Client _client;
  final String _basePath;
  final MethodChannel _channel;

  /// Descarga [resource] hacia la subcarpeta correspondiente según su tipo.
  /// Si proviene de redes sociales (YouTube, FB, X, Instagram, TikTok),
  /// delega primero al DownloadManager nativo de Android e indexa en Galería.
  Future<File> download(
    NanoMediaResource resource, {
    void Function(double progress)? onProgress,
  }) async {
    final sourceOrUrl = resource.sourceUrl ?? resource.url;
    if (NanoMediaDetector.isSocialMediaUrl(sourceOrUrl)) {
      try {
        final res = await _channel.invokeMethod<Map<Object?, Object?>>('downloadMedia', {
          'url': resource.url,
          'audioOnly': resource.type == NanoMediaType.audio,
        });
        if (res != null && res['ok'] == true) {
          onProgress?.call(1.0);
          final nativePath = (res['path'] as String?) ??
              '$_basePath/${resource.type == NanoMediaType.audio ? "Audios" : "Videos"}/${_sanitizeFilename(resource.title, resource.url, resource.type)}';
          return File(nativePath);
        }
      } catch (_) {
        // Si no está disponible el canal nativo, continúa con descarga HTTP por streaming
      }
    }

    final subfolder = switch (resource.type) {
      NanoMediaType.video => 'Videos',
      NanoMediaType.image => 'Imagenes',
      NanoMediaType.audio => 'Audios',
      NanoMediaType.document => 'Documentos',
    };

    final targetDir = Directory('$_basePath/$subfolder');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final filename = _sanitizeFilename(resource.title, resource.url, resource.type);
    final finalFile = File('${targetDir.path}/$filename');
    final partFile = File('${finalFile.path}.part');

    int downloaded = 0;
    if (await partFile.exists()) {
      downloaded = await partFile.length();
    }

    final req = http.Request('GET', Uri.parse(resource.url));
    if (downloaded > 0) {
      req.headers['Range'] = 'bytes=$downloaded-';
    }

    final response = await _client.send(req);
    if (response.statusCode != 200 && response.statusCode != 206) {
      throw HttpException('Error HTTP ${response.statusCode} al descargar.');
    }

    final total = response.contentLength != null
        ? response.contentLength! + (response.statusCode == 206 ? downloaded : 0)
        : null;

    final sink = partFile.openWrite(
      mode: response.statusCode == 206 ? FileMode.append : FileMode.write,
    );

    await response.stream.listen((chunk) {
      sink.add(chunk);
      downloaded += chunk.length;
      if (total != null && total > 0 && onProgress != null) {
        onProgress(downloaded / total);
      }
    }).asFuture<void>();

    await sink.flush();
    await sink.close();

    // Renombrado atómico: de .part a nombre final
    if (await finalFile.exists()) {
      await finalFile.delete();
    }
    return await partFile.rename(finalFile.path);
  }

  /// Descarga una lista de recursos secuencialmente o con concurrencia controlada.
  Future<List<File>> downloadBatch(
    List<NanoMediaResource> items, {
    void Function(int current, int total)? onProgressItem,
  }) async {
    final results = <File>[];
    for (int i = 0; i < items.length; i++) {
      onProgressItem?.call(i + 1, items.length);
      try {
        final file = await download(items[i]);
        results.add(file);
      } catch (_) {
        // Continúa con los demás elementos en caso de fallo individual
      }
    }
    return results;
  }

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
