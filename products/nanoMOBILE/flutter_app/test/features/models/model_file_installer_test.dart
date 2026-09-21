import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nanoai/features/models/data/model_file_installer.dart';
import 'package:nanoai/features/models/data/model_integrity.dart';

void main() {
  late Directory sandbox;
  late Directory sourceDir;
  late Directory modelsDir;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp('nano-model-installer-');
    sourceDir = await Directory('${sandbox.path}/external').create();
    modelsDir = await Directory(
      '${sandbox.path}/files/nano/models',
    ).create(recursive: true);
  });

  tearDown(() async {
    if (await sandbox.exists()) await sandbox.delete(recursive: true);
  });

  test('publica una copia verificada sin dejar .part', () async {
    final source = File('${sourceDir.path}/model.gguf');
    await source.writeAsBytes(List<int>.generate(128, (i) => i));
    final installer = ModelFileInstaller(() async => modelsDir.path);

    final installedPath = await installer.install(source.path, 'model.gguf');
    final installed = File(installedPath!);
    final digest = await ModelIntegrity.sha256Of(source);

    expect(await installed.readAsBytes(), await source.readAsBytes());
    expect(await File('$installedPath.part').exists(), isFalse);
    expect(ModelIntegrity.hasTrustedManifest(installed, digest), isTrue);
  });

  test('repara un destino corrupto aunque conserve el mismo tamaño', () async {
    final source = File('${sourceDir.path}/model.gguf');
    await source.writeAsBytes(List<int>.filled(64, 7));
    final installer = ModelFileInstaller(() async => modelsDir.path);
    final installedPath = await installer.install(source.path, 'model.gguf');

    await File(installedPath!).writeAsBytes(List<int>.filled(64, 9));
    await installer.install(source.path, 'model.gguf');

    expect(await File(installedPath).readAsBytes(), await source.readAsBytes());
  });
}
