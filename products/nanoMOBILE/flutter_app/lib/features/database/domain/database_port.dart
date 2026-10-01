// QUÉ: puerto de base de datos local utilizado por Data Studio y chat.
// CÓMO: define operaciones sin conocer MethodChannel, SQLite CLI ni Android.
// POR QUÉ: permite sustituir infraestructura y probar la aplicación sin dispositivo.

import 'data_models.dart';

abstract interface class DatabasePort {
  Future<String> ensureDefaultDatabase();
  Future<String> ensureDemoDatabase();
  Future<String> createDatabase(String name);
  Future<List<String>> listTables(String path);
  Future<QueryResult> execute({required String path, required String query});
  Future<void> createTable({
    required String path,
    required String table,
    required List<DatabaseColumnDefinition> columns,
  });
}

class DatabaseColumnDefinition {
  final String name;
  final String type;

  const DatabaseColumnDefinition(this.name, {this.type = 'TEXT'});

  Map<String, String> toMap() => {'name': name, 'type': type};
}
