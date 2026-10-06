// QUÉ HACE: mantiene PDFs comerciales en carpetas persistentes privadas de Nano.
// CÓMO: cada negocio tiene categorías; todos los archivos se guardan con nombre seguro.
// POR QUÉ: los PDF temporales desaparecen y no sirven como biblioteca reutilizable.
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Archivo persistido que la interfaz puede previsualizar, compartir o borrar.
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
}

/// Encapsula la estructura de carpetas para mantener I/O fuera de la vista.
final class BusinessDocumentLibrary {
  const BusinessDocumentLibrary();

  static const allCategory = 'Todas';
  static const categories = ['Catálogos', 'Servicios', 'Cotizaciones', 'Otros'];

  // Escribe en la carpeta real más segura cuando la búsqueda está en "Todas".
  String destinationCategory(String selected) =>
      selected == allCategory ? categories.first : selected;

  /// Crea la carpeta elegida bajo documentos persistentes de la app.
  Future<Directory> folder(String business, String category) async {
    final root = await getApplicationDocumentsDirectory();
    return Directory(
      '${root.path}/NanoDocumentos/${_safe(business)}/${_safe(category)}',
    ).create(recursive: true);
  }

  /// Copia bytes generados sin dejar el documento en cache temporal.
  Future<File> saveBytes(
    Uint8List bytes,
    String business,
    String category,
    String baseName,
  ) async {
    final dir = await folder(business, category);
    final file = File(
      '${dir.path}/${_safe(baseName)}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    return file.writeAsBytes(bytes, flush: true);
  }

  /// Importa un PDF del selector Android a la carpeta administrada por Nano.
  Future<File> importPdf(
    String source,
    String business,
    String category,
  ) async {
    final dir = await folder(business, category);
    final name = source.split(RegExp(r'[/\\]')).last;
    final target = File(
      '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${_safe(name)}',
    );
    return File(source).copy(target.path);
  }

  /// Lista solo PDFs de la categoría abierta y los ordena del más reciente.
  Future<List<BusinessDocument>> list(String business, String category) async {
    if (category == allCategory) {
      final groups = await Future.wait(
        categories.map((folder) => _listCategory(business, folder)),
      );
      final documents = groups.expand((items) => items).toList();
      documents.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      return documents;
    }
    return _listCategory(business, category);
  }

  // "Todas" agrega las carpetas físicas sin crear una categoría ficticia.
  Future<List<BusinessDocument>> _listCategory(
    String business,
    String category,
  ) async {
    final dir = await folder(business, category);
    final paths = await dir
        .list(followLinks: false)
        .where(
          (entry) => entry is File && entry.path.toLowerCase().endsWith('.pdf'),
        )
        .cast<File>()
        .toList();
    // Lee cada metadato una vez en async; statSync dentro del comparador
    // bloqueaba el hilo de interfaz varias veces por archivo al ordenar.
    final documents = await Future.wait(
      paths.map((file) async {
        final stat = await file.stat();
        return BusinessDocument(file, stat.size, stat.modified, category);
      }),
    );
    documents.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return documents;
  }

  /// Elimina solamente el documento que el usuario quitó desde la biblioteca.
  Future<void> delete(BusinessDocument document) async {
    if (await document.file.exists()) await document.file.delete();
  }

  /// Normaliza nombres de carpetas y archivos para evitar separadores de ruta.
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
