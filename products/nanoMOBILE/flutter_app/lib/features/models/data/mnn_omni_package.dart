// Verifica el paquete oficial por revisión inmutable y publica la carpeta al final.
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'model_downloader.dart';

class MnnArtifact {
  final String path, oid;
  final int size;
  final bool isLfs;
  const MnnArtifact(this.path, this.oid, this.size, this.isLfs);
}

class MnnOmniPackage {
  static const repo = 'taobao-mnn/Qwen2.5-Omni-3B-MNN';
  static const revision = '0377bda';
  static const folder = 'Qwen2.5-Omni-3B-MNN';
  static const manifestName = '.nanoai-mnn-package.json';
  static const _progressName = '.nanoai-mnn-progress.json';

  // Estos archivos cubren el LLM, visión, audio y la salida de voz requerida por config.json.
  static const requiredFiles = <String>{
    'audio.mnn',
    'audio.mnn.weight',
    'bigvgan.mnn',
    'bigvgan.mnn.weight',
    'config.json',
    'dit.mnn',
    'dit.mnn.weight',
    'embeddings_bf16.bin',
    'llm.mnn',
    'llm.mnn.json',
    'llm.mnn.weight',
    'llm_config.json',
    'predit.mnn',
    'predit.mnn.weight',
    'spk_dict.mnn',
    'talker.mnn',
    'talker.mnn.weight',
    'talker_embeddings_bf16.bin',
    'tokenizer.txt',
    'visual.mnn',
    'visual.mnn.weight',
  };

  static Uri get _treeUri => Uri.https(
    'huggingface.co',
    '/api/models/$repo/tree/$revision',
    {'recursive': 'true', 'expand': 'true'},
  );

  // La API entrega SHA-256 LFS o Git blob ID; ambos se contrastan con bytes descargados.
  static Future<List<MnnArtifact>> _manifest(http.Client client) async {
    final response = await client
        .get(_treeUri)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw DownloadException(
        'No se pudo leer la revisión MNN (${'HTTP ${response.statusCode}'}).',
      );
    }
    final rows = (jsonDecode(response.body) as List)
        .whereType<Map<String, dynamic>>();
    final found = <String, MnnArtifact>{};
    for (final row in rows) {
      final path = row['path'] as String?;
      if (path == null || !requiredFiles.contains(path)) continue;
      final lfs = row['lfs'];
      final oidText = lfs is Map
          ? lfs['oid']?.toString()
          : row['oid']?.toString();
      final oid = oidText?.replaceFirst('sha256:', '');
      final size = lfs is Map ? lfs['size'] : row['size'];
      final isLfs = lfs is Map;
      final validHash =
          oid != null &&
          RegExp(
            isLfs ? r'^[0-9a-fA-F]{64}$' : r'^[0-9a-fA-F]{40}$',
          ).hasMatch(oid);
      if (!validHash || size is! int || size <= 0) {
        throw DownloadException(
          'Metadatos de integridad incompletos para $path.',
        );
      }
      found[path] = MnnArtifact(path, oid, size, isLfs);
    }
    if (found.keys.toSet().length != requiredFiles.length) {
      throw DownloadException(
        'La revisión oficial no contiene el paquete multimedia completo.',
      );
    }
    return [for (final name in requiredFiles) found[name]!];
  }

  // La carpeta solo cuenta como instalada tras renombrar el paquete íntegro.
  static Future<bool> isInstalled(Directory directory) async {
    try {
      final marker = File('${directory.path}/$manifestName');
      final data =
          jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
      if (data['revision'] != revision || data['files'] is! List) return false;
      final files = (data['files'] as List).whereType<Map<String, dynamic>>();
      if (files.length != requiredFiles.length ||
          files.map((f) => f['path']).toSet().length != requiredFiles.length) {
        return false;
      }
      for (final item in files) {
        final name = item['path'] as String?;
        final size = item['size'] as int?;
        if (name == null ||
            !requiredFiles.contains(name) ||
            size == null ||
            await File('${directory.path}/$name').length() != size) {
          return false;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> download({
    required String destination,
    required ModelDownloader downloader,
    required bool Function() cancelled,
    required void Function(double) onProgress,
    required void Function() onVerifying,
  }) async {
    final client = http.Client();
    final finalDir = Directory(destination);
    final stage = Directory(
      '${finalDir.parent.path}/.${finalDir.uri.pathSegments.last}.installing',
    );
    try {
      final artifacts = await _manifest(client);
      if (await finalDir.exists()) {
        throw DownloadException(
          'El paquete ya existe; elimínalo antes de reinstalar.',
        );
      }
      await stage.create(recursive: true);
      final progressFile = File('${stage.path}/$_progressName');
      final prior = await progressFile.exists()
          ? (jsonDecode(await progressFile.readAsString())
                as Map<String, dynamic>)
          : <String, dynamic>{};
      final complete = Map<String, dynamic>.from(
        prior['verified'] as Map? ?? const {},
      );
      final total = artifacts.fold<int>(0, (sum, file) => sum + file.size);
      var done = 0;
      for (final artifact in artifacts) {
        if (cancelled()) throw DownloadException.cancelled();
        final target = File('${stage.path}/${artifact.path}');
        final verifiedSize =
            complete[artifact.path] == artifact.oid &&
            await target.exists() &&
            await target.length() == artifact.size;
        if (!verifiedSize) {
          final url =
              'https://huggingface.co/$repo/resolve/$revision/${Uri.encodeComponent(artifact.path)}?download=true';
          await downloader.download(
            url: url,
            destPath: target.path,
            expectedSha256: artifact.isLfs ? artifact.oid : null,
            expectedGitBlobSha1: artifact.isLfs ? null : artifact.oid,
            cancelToken: () async => cancelled(),
            onProgress: (part) => onProgress(
              ((done + part * artifact.size) / total).clamp(0.0, 1.0),
            ),
            onVerifying: onVerifying,
          );
          complete[artifact.path] = artifact.oid;
          await progressFile.writeAsString(
            jsonEncode({'verified': complete}),
            flush: true,
          );
        }
        done += artifact.size;
      }
      if (complete.length != requiredFiles.length) {
        throw DownloadException(
          'Faltan archivos verificados en el paquete MNN.',
        );
      }
      final packageManifest = {
        'repo': repo,
        'revision': revision,
        'files': [
          for (final a in artifacts)
            {'path': a.path, 'oid': a.oid, 'size': a.size, 'lfs': a.isLfs},
        ],
      };
      await File(
        '${stage.path}/$manifestName',
      ).writeAsString(jsonEncode(packageManifest), flush: true);
      await progressFile.delete();
      await stage.rename(finalDir.path);
      onProgress(1);
    } finally {
      client.close();
    }
  }
}
