import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;

import 'model_integrity.dart';

/// Descargador de GGUF con integridad obligatoria.
///
/// Garantías:
///  - Streaming a `.part` (nunca se materializa el archivo completo en RAM).
///  - Reanudable: si existe un `.part`, se reanuda con `Range: bytes=<n>-`
///    cuando el servidor responde 206. En caso contrario, se reinicia.
///  - SHA256 obligatorio: el archivo final se verifica contra [expectedSha256]
///    antes del rename atómico `.part` → destino. Sin coincidencia, el
///    archivo se descarta y se lanza [DownloadException.hashMismatch].
///  - Cancelación inmediata: [cancel] resuelve el trigger de
///    [http.AbortableRequest], incluso si el servidor deja de enviar chunks.
class ModelDownloader {
  final http.Client _client;
  Completer<void>? _activeAbort;

  ModelDownloader({http.Client? client}) : _client = client ?? http.Client();

  /// Descarga [url] hacia [destPath]. [onProgress] recibe 0..1.
  ///
  /// Devuelve el archivo final verificado. Lanza [DownloadException] con
  /// mensaje honesto ante cualquier fallo (red, HTTP, hash).
  Future<File> download({
    required String url,
    required String destPath,
    String? expectedSha256,
    String? expectedGitBlobSha1,
    void Function(double progress)? onProgress,
    void Function()? onVerifying,
    Future<bool> Function()? cancelToken,
  }) async {
    final abort = Completer<void>();
    _activeAbort = abort;
    try {
      final dest = File(destPath);
      final part = File('$destPath.part');
      await dest.parent.create(recursive: true);

      var resumeFrom = 0;
      if (await part.exists()) resumeFrom = await part.length();

      // AbortableRequest corta también una conexión sin chunks; el token
      // cooperativo por sí solo podía dejar una descarga colgada indefinidamente.
      final request = http.AbortableRequest(
        'GET',
        Uri.parse(url),
        abortTrigger: abort.future,
      );
      if (resumeFrom > 0) request.headers['Range'] = 'bytes=$resumeFrom-';
      final response = await _client.send(request);
      final status = response.statusCode;

      if (status == 200) {
        // Server ignora el Range: descarga completa desde cero.
        resumeFrom = 0;
        await _pump(
          response,
          part.openWrite(mode: FileMode.write),
          offset: 0,
          expectedLength: response.contentLength,
          progressTotalLength: response.contentLength,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
      } else if (status == 206 && resumeFrom > 0) {
        final totalLength =
            _contentRangeTotal(response) ??
            (response.contentLength == null
                ? null
                : resumeFrom + response.contentLength!);
        await _pump(
          response,
          part.openWrite(mode: FileMode.writeOnlyAppend),
          offset: resumeFrom,
          expectedLength: response.contentLength,
          progressTotalLength: totalLength,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
      } else if (status == 416 && resumeFrom > 0) {
        // Range más allá del final: el .part ya está completo. La verificación
        // SHA256 de abajo decide si sirve o hay que reiniciar.
      } else {
        throw DownloadException('HTTP $status al descargar $url');
      }

      // Verificación SHA256 obligatoria — sin hash correcto no hay instalación.
      // Notifica el estado "verifying" ANTES del hash: hasta ahora el callback
      // estaba cableado en el notifier pero nunca se invocaba (estado muerto).
      if (cancelToken != null && await cancelToken()) {
        throw DownloadException.cancelled();
      }
      onVerifying?.call();
      if ((expectedSha256 == null) == (expectedGitBlobSha1 == null)) {
        throw ArgumentError('Indica exactamente un hash SHA-256 o Git blob SHA-1.');
      }
      final matches = expectedSha256 != null
          ? (await _sha256Of(part)).toLowerCase() == expectedSha256.toLowerCase()
          : (await _gitBlobSha1Of(part)).toLowerCase() == expectedGitBlobSha1!.toLowerCase();
      if (!matches) {
        await part.delete();
        throw DownloadException('El checksum del archivo no coincide con la revisión fijada.');
      }

      // Rename atómico: nadie ve un GGUF a medio escribir.
      if (await dest.exists()) await dest.delete();
      try {
        await part.rename(dest.path);
      } on FileSystemException catch (e) {
        throw DownloadException(
          'rename atómico falló para ${dest.path}: ${e.message}',
        );
      }
      if (expectedSha256 != null) {
        await ModelIntegrity.writeManifest(dest, expectedSha256);
      }
      return dest;
    } on http.RequestAbortedException {
      throw DownloadException.cancelled();
    } finally {
      if (identical(_activeAbort, abort)) _activeAbort = null;
    }
  }

  Future<void> _pump(
    http.StreamedResponse response,
    IOSink sink, {
    required int offset,
    required int? expectedLength,
    required int? progressTotalLength,
    required void Function(double)? onProgress,
    required Future<bool> Function()? cancelToken,
  }) async {
    try {
      var written = 0;
      await for (final chunk in response.stream) {
        if (cancelToken != null && await cancelToken()) {
          throw DownloadException.cancelled();
        }
        sink.add(chunk);
        written += chunk.length;
        if (onProgress != null &&
            progressTotalLength != null &&
            progressTotalLength > 0) {
          onProgress(
            ((offset + written) / progressTotalLength).clamp(0.0, 1.0),
          );
        }
      }
      if (expectedLength != null && written != expectedLength) {
        throw DownloadException(
          'descarga truncada: $written de $expectedLength bytes',
        );
      }
    } finally {
      await sink.close();
    }
  }

  Future<String> _sha256Of(File f) async {
    final digest = await crypto.sha256.bind(f.openRead()).first;
    return digest.toString();
  }

  /// Verifica archivos pequeños no-LFS contra el Git blob del commit fijado.
  Future<String> _gitBlobSha1Of(File file) async {
    final length = await file.length();
    final header = utf8.encode('blob $length\u0000');
    Stream<List<int>> combinedStream() async* {
      yield header;
      yield* file.openRead();
    }
    final digest = await crypto.sha1.bind(combinedStream()).first;
    return digest.toString();
  }

  int? _contentRangeTotal(http.StreamedResponse response) {
    final value = response.headers[HttpHeaders.contentRangeHeader];
    if (value == null) return null;
    final slash = value.lastIndexOf('/');
    if (slash < 0 || slash == value.length - 1) return null;
    return int.tryParse(value.substring(slash + 1));
  }

  /// Aborta la petición/stream activo de inmediato; es idempotente.
  void cancel() {
    final abort = _activeAbort;
    if (abort != null && !abort.isCompleted) abort.complete();
  }

  void dispose() {
    cancel();
    _client.close();
  }
}

class DownloadException implements Exception {
  final String message;
  DownloadException(this.message);

  factory DownloadException.hashMismatch(String actual, String expected) =>
      DownloadException(
        'SHA256 no coincide: esperado $expected, recibido $actual',
      );

  factory DownloadException.cancelled() =>
      DownloadException('descarga cancelada');

  @override
  String toString() => 'DownloadException: $message';
}
