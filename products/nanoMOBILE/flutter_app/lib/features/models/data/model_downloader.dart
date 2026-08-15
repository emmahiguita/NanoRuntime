import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;

/// Descargador de GGUF con integridad obligatoria.
///
/// Garantías:
///  - Streaming a `.part` (nunca se materializa el archivo completo en RAM).
///  - Reanudable: si existe un `.part`, se reanuda con `Range: bytes=<n>-`
///    cuando el servidor responde 206. En caso contrario, se reinicia.
///  - SHA256 obligatorio: el archivo final se verifica contra [expectedSha256]
///    antes del rename atómico `.part` → destino. Sin coincidencia, el
///    archivo se descarta y se lanza [DownloadException.hashMismatch].
///  - Cancelación cooperativa vía [cancelToken]: cerrar el [http.Client]
///    aborta el stream en curso.
class ModelDownloader {
  final http.Client _client;

  ModelDownloader({http.Client? client}) : _client = client ?? http.Client();

  /// Descarga [url] hacia [destPath]. [onProgress] recibe 0..1.
  ///
  /// Devuelve el archivo final verificado. Lanza [DownloadException] con
  /// mensaje honesto ante cualquier fallo (red, HTTP, hash).
  Future<File> download({
    required String url,
    required String destPath,
    required String expectedSha256,
    void Function(double progress)? onProgress,
    void Function()? onVerifying,
    Future<bool> Function()? cancelToken,
  }) async {
    final dest = File(destPath);
    final part = File('$destPath.part');
    await dest.parent.create(recursive: true);

    var resumeFrom = 0;
    if (await part.exists()) resumeFrom = await part.length();

    final request = http.Request('GET', Uri.parse(url));
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
    final actual = await _sha256Of(part);
    if (actual.toLowerCase() != expectedSha256.toLowerCase()) {
      await part.delete();
      throw DownloadException.hashMismatch(actual, expectedSha256);
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
    return dest;
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

  int? _contentRangeTotal(http.StreamedResponse response) {
    final value = response.headers[HttpHeaders.contentRangeHeader];
    if (value == null) return null;
    final slash = value.lastIndexOf('/');
    if (slash < 0 || slash == value.length - 1) return null;
    return int.tryParse(value.substring(slash + 1));
  }

  void dispose() => _client.close();
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
