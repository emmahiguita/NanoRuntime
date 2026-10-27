part of 'nano_media_downloader.dart';

/// Señal por operación: aborta HTTP sin cerrar el cliente de otro propietario.
class _NanoDownloadOperation {
  final _abort = Completer<void>();
  bool get cancelled => _abort.isCompleted;

  /// La cancelación es idempotente y también despierta esperas nativas pendientes.
  void cancel() {
    if (!cancelled) _abort.complete();
  }

  /// Evita escribir, renombrar o iniciar otro recurso después de detener el lote.
  void check() {
    if (cancelled) throw const _NanoDownloadCancelled();
  }

  /// Descarta un resultado tardío; cancelar no revierte lo ya aceptado por Android.
  Future<T> wait<T>(Future<T> pending) => Future.any([
    pending,
    _abort.future.then<T>((_) => throw const _NanoDownloadCancelled()),
  ]);
}

/// Error interno que permite terminar el lote sin anunciar un éxito tardío.
class _NanoDownloadCancelled implements Exception {
  const _NanoDownloadCancelled();
}

/// Transferencia HTTP separada del despacho nativo y de la propiedad del cliente.
extension _NanoMediaDownloadTransfer on NanoMediaDownloader {
  /// Conserva el parcial al cancelar y cierra siempre el stream y el archivo.
  Future<File> _downloadHttp(
    NanoMediaResource resource,
    _NanoDownloadOperation operation,
    void Function(double progress)? onProgress,
  ) async {
    final subfolder = switch (resource.type) {
      NanoMediaType.video => 'Videos',
      NanoMediaType.image => 'Imagenes',
      NanoMediaType.audio => 'Audios',
      NanoMediaType.document => 'Documentos',
    };
    final directory = Directory('$_basePath/$subfolder');
    await directory.create(recursive: true);
    operation.check();
    final name = _sanitizeFilename(resource.title, resource.url, resource.type);
    final target = File('${directory.path}/$name');
    final partial = File('${target.path}.part');
    var downloaded = await partial.exists() ? await partial.length() : 0;
    operation.check();
    final request = http.AbortableRequest(
      'GET',
      Uri.parse(resource.url),
      abortTrigger: operation._abort.future,
    );
    if (downloaded > 0) request.headers['Range'] = 'bytes=$downloaded-';
    final response = await operation.wait(_client.send(request));
    if (response.statusCode != 200 && response.statusCode != 206) {
      await response.stream.listen(null).cancel();
      throw HttpException('Error HTTP ${response.statusCode} al descargar.');
    }
    if (response.statusCode == 200) downloaded = 0;
    final total = response.contentLength == null
        ? null
        : response.contentLength! + downloaded;
    final sink = partial.openWrite(
      mode: response.statusCode == 206 ? FileMode.append : FileMode.write,
    );
    final chunks = StreamIterator(response.stream);
    try {
      while (await operation.wait(chunks.moveNext())) {
        operation.check();
        sink.add(chunks.current);
        downloaded += chunks.current.length;
        if (total != null && total > 0) onProgress?.call(downloaded / total);
      }
      await sink.flush();
    } finally {
      await chunks.cancel();
      await sink.close();
    }
    operation.check();
    if (await target.exists()) await target.delete();
    operation.check();
    return partial.rename(target.path);
  }
}
