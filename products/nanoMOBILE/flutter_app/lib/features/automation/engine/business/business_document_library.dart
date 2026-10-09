// QUÉ HACE: mantiene documentos, imágenes y catálogos en carpetas persistentes de Nano.
// CÓMO: soporte completo CRUD para carpetas y archivos con almacenamiento local real.
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Archivo persistido con metadatos reales de tipo, tamaño, fecha y carpeta.
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
  String get extension => name.contains('.') ? name.split('.').last.toLowerCase() : '';
  bool get isPdf => extension == 'pdf';
  bool get isImage => ['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(extension);
  bool get isVideo => ['mp4', 'mov', 'avi', 'mkv'].contains(extension);
  bool get isSheet => ['xlsx', 'xls', 'csv'].contains(extension);
}

/// Metadatos de una carpeta de la biblioteca
final class BusinessFolderInfo {
  final String name;
  final int itemCount;
  final DateTime modifiedAt;

  const BusinessFolderInfo({
    required this.name,
    required this.itemCount,
    required this.modifiedAt,
  });
}

/// Encapsula el almacenamiento y operaciones de carpetas y archivos de la biblioteca.
final class BusinessDocumentLibrary {
  const BusinessDocumentLibrary();

  static const allCategory = 'Todas';
  static const defaultCategories = [
    'Catálogos',
    'Servicios',
    'Clientes',
    'Imágenes',
    'Cotizaciones',
    'Otros',
  ];

  Future<Directory> _rootDir(String business) async {
    final root = await getApplicationDocumentsDirectory();
    return Directory(
      '${root.path}/NanoDocumentos/${_safe(business)}',
    ).create(recursive: true);
  }

  /// Carpeta física para una categoría
  Future<Directory> folder(String business, String category) async {
    final root = await _rootDir(business);
    return Directory('${root.path}/${_safe(category)}').create(recursive: true);
  }

  /// Lista todas las carpetas (por defecto + creadas por el usuario)
  Future<List<BusinessFolderInfo>> listFolders(String business) async {
    final root = await _rootDir(business);
    // Asegurar que las carpetas por defecto existan
    for (final cat in defaultCategories) {
      await Directory('${root.path}/${_safe(cat)}').create(recursive: true);
    }

    final entities = await root.list(followLinks: false).toList();
    final folders = <BusinessFolderInfo>[];

    for (final entity in entities) {
      if (entity is Directory) {
        final folderName = entity.uri.pathSegments
            .where((s) => s.isNotEmpty)
            .last;
        final files = await entity
            .list(followLinks: false)
            .where((e) => e is File && !e.path.endsWith('.DS_Store'))
            .length;
        final stat = await entity.stat();
        folders.add(
          BusinessFolderInfo(
            name: folderName,
            itemCount: files,
            modifiedAt: stat.modified,
          ),
        );
      }
    }
    return folders;
  }

  /// Crea una nueva carpeta
  Future<Directory> createFolder(String business, String folderName) async {
    final safeName = _safe(folderName);
    if (safeName.isEmpty) throw ArgumentError('El nombre de la carpeta no es válido');
    return folder(business, safeName);
  }

  /// Renombra una carpeta existente
  Future<void> renameFolder(
    String business,
    String oldName,
    String newName,
  ) async {
    final safeOld = _safe(oldName);
    final safeNew = _safe(newName);
    if (safeOld == safeNew || safeNew.isEmpty) return;

    final root = await _rootDir(business);
    final oldDir = Directory('${root.path}/$safeOld');
    final newDir = Directory('${root.path}/$safeNew');

    if (await oldDir.exists()) {
      await oldDir.rename(newDir.path);
    }
  }

  /// Elimina una carpeta completa
  Future<void> deleteFolder(String business, String folderName) async {
    final safeName = _safe(folderName);
    final root = await _rootDir(business);
    final dir = Directory('${root.path}/$safeName');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  /// Guarda bytes generados (ej. catálogo)
  Future<File> saveBytes(
    Uint8List bytes,
    String business,
    String category,
    String baseName,
  ) async {
    final dir = await folder(business, destinationCategory(category));
    final file = File(
      '${dir.path}/${_safe(baseName)}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    return file.writeAsBytes(bytes, flush: true);
  }

  /// Importa cualquier archivo al directorio de la biblioteca
  Future<File> importFile(
    String source,
    String business,
    String category,
  ) async {
    final targetCategory = destinationCategory(category);
    final dir = await folder(business, targetCategory);
    final name = source.split(RegExp(r'[/\\]')).last;
    final target = File(
      '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${_safe(name)}',
    );
    return File(source).copy(target.path);
  }

  /// Renombra un archivo
  Future<BusinessDocument> renameDocument(
    BusinessDocument document,
    String newName,
  ) async {
    final cleanName = _safe(newName);
    if (cleanName.isEmpty) return document;

    final parent = document.file.parent.path;
    final newPath = '$parent/$cleanName';
    final renamedFile = await document.file.rename(newPath);
    final stat = await renamedFile.stat();

    return BusinessDocument(
      renamedFile,
      stat.size,
      stat.modified,
      document.category,
    );
  }

  /// Lista archivos de una o todas las categorías
  Future<List<BusinessDocument>> list(String business, String category) async {
    if (category == allCategory) {
      final folders = await listFolders(business);
      final groups = await Future.wait(
        folders.map((f) => _listCategory(business, f.name)),
      );
      final documents = groups.expand((items) => items).toList();
      documents.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      return documents;
    }
    return _listCategory(business, category);
  }

  Future<List<BusinessDocument>> _listCategory(
    String business,
    String category,
  ) async {
    final dir = await folder(business, category);
    if (!await dir.exists()) return const [];

    final paths = await dir
        .list(followLinks: false)
        .where((entry) => entry is File && !entry.path.endsWith('.DS_Store'))
        .cast<File>()
        .toList();

    final documents = await Future.wait(
      paths.map((file) async {
        final stat = await file.stat();
        return BusinessDocument(file, stat.size, stat.modified, category);
      }),
    );
    documents.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return documents;
  }

  /// Elimina un archivo
  Future<void> delete(BusinessDocument document) async {
    if (await document.file.exists()) await document.file.delete();
  }

  String destinationCategory(String selected) =>
      selected == allCategory ? defaultCategories.first : selected;

  String _safe(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9._-]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}
