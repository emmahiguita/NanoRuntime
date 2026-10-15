import 'dart:io';

/// Metadatos reales de un archivo; no contiene operaciones de almacenamiento.
final class BusinessDocument {
  const BusinessDocument(
    this.file,
    this.sizeBytes,
    this.modifiedAt,
    this.category,
  );
  final File file;
  final int sizeBytes;
  final DateTime modifiedAt;
  final String category;
  String get name => file.uri.pathSegments.last;
  String get extension =>
      name.contains('.') ? name.split('.').last.toLowerCase() : '';
  bool get isPdf => extension == 'pdf';
  bool get isImage => ['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(extension);
  bool get isVideo => ['mp4', 'mov', 'avi', 'mkv'].contains(extension);
  bool get isSheet => ['xlsx', 'xls', 'csv'].contains(extension);
}

/// Una carpeta se presenta con su conteo y fecha observados en disco.
final class BusinessFolderInfo {
  const BusinessFolderInfo({
    required this.name,
    required this.itemCount,
    required this.modifiedAt,
  });
  final String name;
  final int itemCount;
  final DateTime modifiedAt;
}
