import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/models/data/model_downloader.dart';

void main() {
  test('cancel aborta un stream detenido sin esperar otro chunk', () async {
    final releaseServer = Completer<void>();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.contentLength = 64;
      request.response.add(const [1]);
      await request.response.flush();
      await releaseServer.future;
      await request.response.close();
    });

    final sandbox = await Directory.systemTemp.createTemp('nano-download-');
    final downloader = ModelDownloader();
    final download = downloader.download(
      url: 'http://127.0.0.1:${server.port}/model.gguf',
      destPath: '${sandbox.path}/model.gguf',
      expectedSha256: '0' * 64,
    );

    await Future<void>.delayed(const Duration(milliseconds: 100));
    downloader.cancel();

    await expectLater(
      download.timeout(const Duration(seconds: 2)),
      throwsA(
        isA<DownloadException>().having(
          (error) => error.message,
          'message',
          'descarga cancelada',
        ),
      ),
    );

    downloader.dispose();
    releaseServer.complete();
    await server.close(force: true);
    await sandbox.delete(recursive: true);
  });
}
