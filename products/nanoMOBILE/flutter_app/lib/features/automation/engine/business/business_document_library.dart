// Biblioteca real: conserva la API pública y separa rutas, carpetas y metadatos.
import 'dart:io';
import 'dart:typed_data';
import 'business_document_models.dart';
import 'business_document_paths.dart';
import 'business_folder_library.dart';
export 'business_document_models.dart';

/// Archivos del negocio; no mueve datos existentes ni simula importaciones.
final class BusinessDocumentLibrary {
  const BusinessDocumentLibrary();
  static const allCategory = 'Todas';
  static const defaultCategories = BusinessFolderLibrary.defaults;
  static const _folders = BusinessFolderLibrary();

  /// Conserva visible la biblioteca existente aunque el usuario cambie el
  /// nombre comercial después de haber importado sus documentos.
  Future<String> resolveStorageBusiness(String preferredBusiness) async {
    final preferred = safeBusinessSegment(preferredBusiness);
    final root = await businessLibraryRoot();
    final candidates = <({String name, DateTime modified})>[];
    await for (final entity in root.list(followLinks: false)) {
      if (entity is! Directory) continue;
      var hasDocuments = false;
      DateTime newest = DateTime.fromMillisecondsSinceEpoch(0);
      await for (final child in entity.list(
        recursive: true,
        followLinks: false,
      )) {
        if (child is! File || child.path.endsWith('.DS_Store')) continue;
        hasDocuments = true;
        final modified = (await child.stat()).modified;
        if (modified.isAfter(newest)) newest = modified;
      }
      if (!hasDocuments) continue;
      final name = entity.uri.pathSegments
          .where((part) => part.isNotEmpty)
          .last;
      if (name == preferred) return preferred;
      candidates.add((name: name, modified: newest));
    }
    if (candidates.isEmpty) return preferredBusiness;
    candidates.sort((a, b) => b.modified.compareTo(a.modified));
    return candidates.first.name;
  }

  Future<Directory> folder(String business, String category) =>
      _folders.folder(business, category);
  Future<List<BusinessFolderInfo>> listFolders(String business) =>
      _folders.list(business);
  Future<Directory> createFolder(String business, String name) =>
      folder(business, name);
  Future<void> renameFolder(String business, String oldName, String newName) =>
      _folders.rename(business, oldName, newName);
  Future<void> deleteFolder(String business, String name) =>
      _folders.delete(business, name);

  /// Guarda un PDF generado con nombre propio, sin sobrescribir archivos.
  Future<File> saveBytes(
    Uint8List bytes,
    String business,
    String category,
    String baseName,
  ) async {
    final directory = await folder(business, destinationCategory(category));
    final name =
        '${safeBusinessSegment(baseName)}_${DateTime.now().microsecondsSinceEpoch}.pdf';
    final target = await checkedBusinessChild(directory, name);
    return File(target).writeAsBytes(bytes, flush: true);
  }

  /// Copia el archivo seleccionado; la ruta origen no se borra ni renombra.
  Future<File> importFile(
    String source,
    String business,
    String category,
  ) async {
    final directory = await folder(business, destinationCategory(category));
    final name = source.split(RegExp(r'[/\\]')).last;
    final targetName =
        '${DateTime.now().microsecondsSinceEpoch}_${safeBusinessSegment(name)}';
    return File(source).copy(await checkedBusinessChild(directory, targetName));
  }

  /// Comprueba pertenencia y colisión antes de renombrar un archivo.
  Future<BusinessDocument> renameDocument(
    BusinessDocument document,
    String newName,
  ) async {
    await requireBusinessFile(document.file);
    final target = await checkedBusinessChild(document.file.parent, newName);
    if (target == document.file.path) return document;
    if (await FileSystemEntity.type(target) != FileSystemEntityType.notFound) {
      throw ArgumentError('Ya existe un archivo con ese nombre.');
    }
    final renamed = await document.file.rename(target);
    final stat = await renamed.stat();
    return BusinessDocument(
      renamed,
      stat.size,
      stat.modified,
      document.category,
    );
  }

  /// Une categorías existentes y ordena por fecha real, sin seguir enlaces.
  Future<List<BusinessDocument>> list(String business, String category) async {
    if (category != allCategory) return _listCategory(business, category);
    final folders = await listFolders(business);
    final groups = await Future.wait(
      folders.map((item) => _listCategory(business, item.name)),
    );
    final documents = groups.expand((items) => items).toList();
    documents.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return documents;
  }

  Future<List<BusinessDocument>> _listCategory(
    String business,
    String category,
  ) async {
    final directory = await folder(business, category);
    final paths = await directory
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

  /// El caller aporta metadatos, pero la pertenencia se verifica contra el disco.
  Future<void> delete(BusinessDocument document) async {
    if (!await document.file.exists()) return;
    await requireBusinessFile(document.file);
    await document.file.delete();
  }

  String destinationCategory(String selected) =>
      selected == allCategory ? defaultCategories.first : selected;
}
