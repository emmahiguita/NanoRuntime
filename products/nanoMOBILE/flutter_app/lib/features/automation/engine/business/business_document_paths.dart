import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Conserva nombres históricos seguros, pero nunca acepta directorio actual/padre.
String safeBusinessSegment(String value) {
  final result = value
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
  if (result.isEmpty || result == '.' || result == '..') {
    throw ArgumentError(
      'Usa un nombre válido para el negocio, carpeta o archivo.',
    );
  }
  return result;
}

/// URI canónica con separador final evita confundir /negocio y /negocio_otro.
bool _inside(String parent, String target) {
  var base = Directory(parent).absolute.uri.normalizePath().toString();
  var child = File(target).absolute.uri.normalizePath().toString();
  if (Platform.isWindows) {
    base = base.toLowerCase();
    child = child.toLowerCase();
  }
  if (!base.endsWith('/')) base += '/';
  return child.startsWith(base) && child != base;
}

/// Valida destino y enlaces existentes antes de borrar, mover o crear un hijo.
Future<String> checkedBusinessChild(Directory parent, String name) async {
  final base = await parent.resolveSymbolicLinks();
  // Android expone la misma carpeta privada mediante /data/data y
  // /data/user/0. Construir el hijo desde la ruta canónica evita rechazar
  // archivos legítimos sin relajar la comprobación de pertenencia.
  final target = '$base/${safeBusinessSegment(name)}';
  if (!_inside(base, target)) {
    throw ArgumentError('La ruta sale de la biblioteca.');
  }
  final type = await FileSystemEntity.type(target, followLinks: false);
  if (type != FileSystemEntityType.notFound) {
    final resolved = await File(target).resolveSymbolicLinks();
    if (!_inside(base, resolved)) {
      throw ArgumentError('El enlace sale de la biblioteca.');
    }
  }
  return target;
}

/// Ubicación histórica, aislada bajo documentos de la aplicación.
Future<Directory> businessLibraryRoot() async {
  final documents = await getApplicationDocumentsDirectory();
  final root = Directory('${documents.path}/NanoDocumentos');
  // Tampoco acepta que la raíz histórica se sustituya por un enlace externo.
  if (await FileSystemEntity.type(root.path, followLinks: false) ==
      FileSystemEntityType.link) {
    throw ArgumentError('La biblioteca no puede ser un enlace simbólico.');
  }
  await root.create(recursive: true);
  if (!_inside(
    await documents.resolveSymbolicLinks(),
    await root.resolveSymbolicLinks(),
  )) {
    throw ArgumentError(
      'La biblioteca sale de los documentos de la aplicación.',
    );
  }
  return root;
}

/// Comprueba archivos recibidos por un caller antes de cualquier mutación.
Future<void> requireBusinessFile(File file) async {
  final root = await businessLibraryRoot();
  final base = await root.resolveSymbolicLinks();
  final resolved = await file.resolveSymbolicLinks();
  if (!_inside(base, resolved)) {
    throw ArgumentError('El archivo no pertenece a NanoDocumentos.');
  }
}
