import 'dart:io';

import 'model_integrity.dart';

/// Instala un modelo externo sin publicar archivos parciales.
///
/// Copia a `.part`, compara tamaño y SHA-256, y solo entonces sustituye el
/// destino. El respaldo permite restaurar el modelo anterior si falla el rename.
class ModelFileInstaller {
  const ModelFileInstaller(this._modelsDir);

  final Future<String?> Function() _modelsDir;

  Future<String?> install(String sourcePath, String fallbackName) async {
    final directory = await _modelsDir();
    if (directory == null || directory.isEmpty) return null;

    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('El modelo de origen no existe', sourcePath);
    }

    final sourceName = source.uri.pathSegments.isEmpty
        ? fallbackName
        : source.uri.pathSegments.last;
    final safeName = sourceName.replaceAll(RegExp(r'[\\/]'), '_');
    final destination = File('$directory${Platform.pathSeparator}$safeName');
    final temporary = File('${destination.path}.part');
    final backup = File('${destination.path}.bak');
    await destination.parent.create(recursive: true);

    final sourceSize = await source.length();
    final sourceHash = await ModelIntegrity.sha256Of(source);
    if (await destination.exists() &&
        await destination.length() == sourceSize &&
        await ModelIntegrity.sha256Of(destination) == sourceHash) {
      await ModelIntegrity.writeManifest(destination, sourceHash);
      return destination.path;
    }

    if (await temporary.exists()) await temporary.delete();
    await source.openRead().pipe(temporary.openWrite());
    final validCopy =
        await temporary.length() == sourceSize &&
        await ModelIntegrity.sha256Of(temporary) == sourceHash;
    if (!validCopy) {
      await temporary.delete();
      throw const FileSystemException('La copia del modelo no superó SHA-256');
    }

    if (await backup.exists()) await backup.delete();
    if (await destination.exists()) await destination.rename(backup.path);
    try {
      await temporary.rename(destination.path);
      await ModelIntegrity.writeManifest(destination, sourceHash);
      if (await backup.exists()) await backup.delete();
      return destination.path;
    } on Object {
      if (await destination.exists()) await destination.delete();
      if (await backup.exists()) await backup.rename(destination.path);
      rethrow;
    }
  }
}
