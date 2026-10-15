import 'dart:io';
import 'business_document_models.dart';
import 'business_document_paths.dart';

/// Operaciones de carpetas; todas validan alcance antes de mutar el disco.
final class BusinessFolderLibrary {
  const BusinessFolderLibrary();
  static const defaults = [
    'Catálogos',
    'Servicios',
    'Clientes',
    'Imágenes',
    'Cotizaciones',
    'Otros',
  ];

  /// Mantiene la ruta existente sin migrar ni renombrar documentos del usuario.
  Future<Directory> root(String business) async {
    final base = await businessLibraryRoot();
    final path = await checkedBusinessChild(base, business);
    return Directory(path).create(recursive: true);
  }

  Future<Directory> folder(String business, String category) async {
    final base = await root(business);
    final path = await checkedBusinessChild(base, category);
    return Directory(path).create(recursive: true);
  }

  /// Cuenta archivos reales sin seguir enlaces de subdirectorios.
  Future<List<BusinessFolderInfo>> list(String business) async {
    final base = await root(business);
    for (final name in defaults) {
      await folder(business, name);
    }
    final result = <BusinessFolderInfo>[];
    await for (final entity in base.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final name = entity.uri.pathSegments
          .where((part) => part.isNotEmpty)
          .last;
      final count = await entity
          .list(followLinks: false)
          .where((entry) => entry is File && !entry.path.endsWith('.DS_Store'))
          .length;
      result.add(
        BusinessFolderInfo(
          name: name,
          itemCount: count,
          modifiedAt: (await entity.stat()).modified,
        ),
      );
    }
    return result;
  }

  /// No permite sobrescribir una carpeta destino existente.
  Future<void> rename(String business, String oldName, String newName) async {
    final base = await root(business);
    final oldPath = await checkedBusinessChild(base, oldName);
    final newPath = await checkedBusinessChild(base, newName);
    if (oldPath == newPath) return;
    if (await FileSystemEntity.type(newPath) != FileSystemEntityType.notFound) {
      throw ArgumentError('Ya existe una carpeta con ese nombre.');
    }
    final oldDirectory = Directory(oldPath);
    if (await oldDirectory.exists()) await oldDirectory.rename(newPath);
  }

  /// El borrado queda limitado a un hijo validado, nunca al negocio ni a su padre.
  Future<void> delete(String business, String name) async {
    final base = await root(business);
    final target = Directory(await checkedBusinessChild(base, name));
    if (await target.exists()) await target.delete(recursive: true);
  }
}
