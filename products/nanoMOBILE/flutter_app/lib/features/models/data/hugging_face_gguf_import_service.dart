import 'dart:convert';

import 'package:http/http.dart' as http;

import 'model_downloader.dart';

/// A single verified GGUF artifact from a Hugging Face model repository.
class HuggingFaceGgufArtifact {
  final String repoId;
  final String revision;
  final String filePath;
  final int sizeBytes;
  final String downloadUrl;
  final String? sha256;
  final String? gitBlobSha1;

  const HuggingFaceGgufArtifact({
    required this.repoId,
    required this.revision,
    required this.filePath,
    required this.sizeBytes,
    required this.downloadUrl,
    this.sha256,
    this.gitBlobSha1,
  });

  String get fileName => filePath.split('/').last;
}

/// Imports only individual GGUF files, the format Nano can route to llama.cpp.
/// Repository links are resolved through Hub metadata so a repo is never
/// downloaded as a guessed archive or presented as a supported runtime model.
class HuggingFaceGgufImportService {
  const HuggingFaceGgufImportService();

  Future<List<HuggingFaceGgufArtifact>> inspect(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        !(uri.host == 'huggingface.co' || uri.host == 'www.huggingface.co') ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException(
        'Pega un enlace HTTPS de un repositorio o archivo de Hugging Face.',
      );
    }

    final parts = uri.pathSegments.map(Uri.decodeComponent).toList();
    if (parts.length < 2 || parts[0].isEmpty || parts[1].isEmpty) {
      throw const FormatException(
        'El enlace no identifica un modelo de Hugging Face.',
      );
    }
    final repoId = '${parts[0]}/${parts[1]}';
    var revision = 'main';
    String? requestedPath;
    String? folderPrefix;
    if (parts.length > 2) {
      final kind = parts[2];
      if ((kind == 'resolve' || kind == 'blob') && parts.length >= 5) {
        revision = parts[3];
        requestedPath = parts.skip(4).join('/');
      } else if (kind == 'tree' && parts.length >= 4) {
        revision = parts[3];
        if (parts.length > 4) folderPrefix = '${parts.skip(4).join('/')}/';
      } else if (kind != 'settings' &&
          kind != 'discussions' &&
          kind != 'commit') {
        throw const FormatException(
          'Usa el enlace del repositorio, de una carpeta, o de un archivo GGUF.',
        );
      }
    }

    // Lee el hash en la misma revisión solicitada, no en main por accidente.
    final apiUri = Uri.https(
      'huggingface.co',
      '/api/models/$repoId/revision/${Uri.encodeComponent(revision)}',
      {'blobs': 'true'},
    );
    final response = await http
        .get(apiUri)
        .timeout(const Duration(seconds: 25));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const FormatException(
        'Este repositorio requiere acceso aprobado o autenticación de Hugging Face.',
      );
    }
    if (response.statusCode != 200) {
      throw FormatException(
        'Hugging Face no pudo consultar el repositorio (HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> || decoded['siblings'] is! List) {
      throw const FormatException(
        'Hugging Face devolvió metadatos incompletos.',
      );
    }
    final resolvedRevision = decoded['sha']?.toString() ?? revision;
    final candidates = <HuggingFaceGgufArtifact>[];
    for (final raw in decoded['siblings'] as List) {
      if (raw is! Map) continue;
      final name = raw['rfilename']?.toString() ?? '';
      if (!name.toLowerCase().endsWith('.gguf') ||
          (requestedPath != null && name != requestedPath) ||
          (folderPrefix != null && !name.startsWith(folderPrefix))) {
        continue;
      }
      final lfs = raw['lfs'];
      final lfsMap = lfs is Map ? lfs : const <dynamic, dynamic>{};
      final lfsSha =
          _sha256(lfsMap['sha256']?.toString()) ??
          _sha256(lfsMap['oid']?.toString());
      final blobId = raw['blobId']?.toString();
      final gitSha =
          lfsSha == null &&
              blobId != null &&
              RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(blobId)
          ? blobId
          : null;
      if (lfsSha == null && gitSha == null) continue;

      final encodedPath = name.split('/').map(Uri.encodeComponent).join('/');
      final downloadUrl = Uri.https(
        'huggingface.co',
        '/$repoId/resolve/${Uri.encodeComponent(resolvedRevision)}/$encodedPath',
        {'download': 'true'},
      ).toString();
      candidates.add(
        HuggingFaceGgufArtifact(
          repoId: repoId,
          revision: resolvedRevision,
          filePath: name,
          sizeBytes: _size(raw, lfsMap),
          downloadUrl: downloadUrl,
          sha256: lfsSha,
          gitBlobSha1: gitSha,
        ),
      );
    }
    if (candidates.isEmpty) {
      throw const FormatException(
        'No hay archivos GGUF descargables con checksum verificable en ese enlace. La importación por enlace acepta GGUF; usa las entradas del catálogo para LiteRT y MNN.',
      );
    }
    return candidates;
  }

  Future<String> download({
    required HuggingFaceGgufArtifact artifact,
    required String destinationPath,
    void Function(double progress)? onProgress,
  }) async {
    final downloader = ModelDownloader();
    try {
      final file = await downloader.download(
        url: artifact.downloadUrl,
        destPath: destinationPath,
        expectedSha256: artifact.sha256,
        expectedGitBlobSha1: artifact.gitBlobSha1,
        onProgress: onProgress,
      );
      return file.path;
    } finally {
      downloader.dispose();
    }
  }

  static String? _sha256(String? value) {
    if (value == null) return null;
    final normalized = value.toLowerCase().startsWith('sha256:')
        ? value.substring(7)
        : value;
    return RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(normalized)
        ? normalized.toLowerCase()
        : null;
  }

  static int _size(Map<dynamic, dynamic> file, Map<dynamic, dynamic> lfs) {
    final size = file['size'] ?? lfs['size'];
    return size is num ? size.toInt() : -1;
  }
}
