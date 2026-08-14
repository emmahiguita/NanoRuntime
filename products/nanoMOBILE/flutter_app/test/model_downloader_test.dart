import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/models/data/model_downloader.dart';

/// Tests del descargador GGUF contra un HttpServer local REAL:
/// verificación SHA256 obligatoria, rename atómico, reanudación con Range,
/// cancelación cooperativa y error honesto ante HTTP no-2xx.
void main() {
  late HttpServer server;
  late String baseUrl;
  late Directory tmp;

  // 1MB: suficiente para que el stream llegue en varios chunks — el test de
  // cancelación depende de poder abortar entre chunk y chunk.
  final payload = List<int>.generate(1024 * 1024, (i) => i % 251);
  late String payloadSha;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('model_dl_test_');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${server.port}';
    payloadSha =
        (await crypto.sha256.bind(Stream.value(payload)).first).toString();
    server.listen((req) async {
      if (req.uri.path == '/missing') {
        req.response.statusCode = HttpStatus.notFound;
        await req.response.close();
        return;
      }
      // Soporte Range real: el test de reanudación depende de 206.
      var start = 0;
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (range != null && range.startsWith('bytes=')) {
        start = int.parse(range.substring(6).split('-').first);
      }
      final bytes = payload.sublist(start);
      req.response.statusCode =
          start > 0 ? HttpStatus.partialContent : HttpStatus.ok;
      if (start > 0) {
        req.response.headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-${payload.length - 1}/${payload.length}',
        );
      }
      req.response.headers.set(HttpHeaders.contentLengthHeader, bytes.length);
      req.response.add(bytes);
      await req.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await tmp.delete(recursive: true);
  });

  test('descarga completa + SHA256 correcto = archivo instalado, sin .part',
      () async {
    final dl = ModelDownloader();
    final dest = '${tmp.path}/model.gguf';
    final progress = <double>[];
    final file = await dl.download(
      url: '$baseUrl/model.gguf',
      destPath: dest,
      expectedSha256: payloadSha,
      onProgress: progress.add,
    );
    expect(file.path, dest);
    expect(await file.readAsBytes(), payload);
    expect(File('$dest.part').existsSync(), isFalse);
    expect(progress, isNotEmpty);
    expect(progress.last, closeTo(1.0, 0.001));
    dl.dispose();
  });

  test('SHA256 incorrecto = DownloadException.hashMismatch y .part borrado',
      () async {
    final dl = ModelDownloader();
    final dest = '${tmp.path}/model.gguf';
    await expectLater(
      dl.download(
        url: '$baseUrl/model.gguf',
        destPath: dest,
        expectedSha256: 'f' * 64,
      ),
      throwsA(isA<DownloadException>().having(
        (e) => e.message,
        'message',
        contains('SHA256 no coincide'),
      )),
    );
    expect(File(dest).existsSync(), isFalse);
    expect(File('$dest.part').existsSync(), isFalse);
    dl.dispose();
  });

  test('reanuda con Range si existe .part', () async {
    // Primera mitad escrita simulando una descarga interrumpida.
    final dest = '${tmp.path}/model.gguf';
    await File('$dest.part').writeAsBytes(payload.sublist(0, payload.length ~/ 2));

    final dl = ModelDownloader();
    final file = await dl.download(
      url: '$baseUrl/model.gguf',
      destPath: dest,
      expectedSha256: payloadSha,
    );
    expect(await file.readAsBytes(), payload);
    expect(File('$dest.part').existsSync(), isFalse);
    dl.dispose();
  });

  test('cancelación cooperativa lanza DownloadException.cancelled', () async {
    final dl = ModelDownloader();
    final dest = '${tmp.path}/model.gguf';
    var cancel = false;
    await expectLater(
      dl.download(
        url: '$baseUrl/model.gguf',
        destPath: dest,
        expectedSha256: payloadSha,
        // Se activa al primer chunk (vía onProgress) → aborta el stream.
        cancelToken: () async => cancel,
        onProgress: (_) => cancel = true,
      ),
      throwsA(isA<DownloadException>().having(
        (e) => e.message,
        'message',
        contains('cancelada'),
      )),
    );
    expect(File(dest).existsSync(), isFalse);
    dl.dispose();
  });

  test('HTTP 404 = DownloadException honesta, sin archivos parciales',
      () async {
    final dl = ModelDownloader();
    final dest = '${tmp.path}/missing.gguf';
    await expectLater(
      dl.download(
        url: '$baseUrl/missing',
        destPath: dest,
        expectedSha256: payloadSha,
      ),
      throwsA(isA<DownloadException>().having(
        (e) => e.message,
        'message',
        contains('HTTP 404'),
      )),
    );
    expect(File(dest).existsSync(), isFalse);
    expect(File('$dest.part').existsSync(), isFalse);
    dl.dispose();
  });
}
