import 'dart:io';

/// Normaliza una ruta local o URL antes de entregarla a visores multimedia.
final class ConversationMediaSource {
  final String raw;

  const ConversationMediaSource(String value) : raw = value;

  String get value => raw.trim();

  bool get isRemote {
    final scheme = Uri.tryParse(value)?.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  bool get isLocal => !isRemote;

  String get localPath {
    if (!value.toLowerCase().startsWith('file://')) return value;
    final uri = Uri.tryParse(value);
    if (uri != null && uri.scheme == 'file') {
      try {
        return uri.toFilePath(windows: Platform.isWindows);
      } on UnsupportedError {
        // Conserva el fallback para URIs provenientes de otra plataforma.
      }
    }
    return value.substring('file://'.length);
  }

  File? get localFile => isLocal ? File(localPath) : null;

  bool get existsSync => localFile?.existsSync() ?? false;

  Uri? get launchUri {
    if (isRemote) return Uri.tryParse(value);
    if (localPath.isEmpty) return null;
    return Uri.file(localPath);
  }

  String get playbackUrl => launchUri?.toString() ?? value;

  String get displayName {
    final uri = isRemote ? Uri.tryParse(value) : Uri.file(localPath);
    final segment = uri?.pathSegments.where((part) => part.isNotEmpty).lastOrNull;
    if (segment == null || segment.isEmpty) return 'Archivo multimedia';
    try {
      return Uri.decodeComponent(segment);
    } on FormatException {
      return segment;
    }
  }
}
