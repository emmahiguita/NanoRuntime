import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../engine/storage/automation_db_store_client.dart';

/// Guarda índices en el SQLite existente y evidencias/documentos en el
/// directorio privado. No crea otra base ni almacena historiales en preferencias.
class OwlWorkspaceStore {
  static Future<void> _writes = Future<void>.value();
  final db = AutomationDbStoreClient.instance;

  /// IDs son nombres internos, nunca rutas aportadas por una conversación.
  Future<Directory> folder(String category, String id) async {
    if (!const {'exports', 'qa'}.contains(category) ||
        !RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(id)) {
      throw const FormatException('Identificador de almacenamiento inválido.');
    }
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/owl/$category/$id').create(recursive: true);
  }

  Future<Map<String, dynamic>> index(String section) async {
    final raw = await db.section(section, strict: true);
    return raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  /// Serializa read-modify-write de esta UI. Un error de persistencia se
  /// devuelve al llamador; no se presenta un documento en memoria como guardado.
  Future<void> record(String section, String id, Map<String, dynamic> value) {
    final next = _writes.then((_) async {
      final rows = await index(section);
      if (!rows.containsKey(id) && rows.length >= 200) {
        throw StateError(
          'El índice está lleno. Conserva/exporta tus registros antes de importar más.',
        );
      }
      rows[id] = value;
      if (!await db.putSection(section, jsonEncode(rows))) {
        throw StateError(
          'SQLite rechazó el registro; no se confirmó su persistencia.',
        );
      }
    });
    _writes = next.catchError((Object _) {});
    return next;
  }

  /// Escribe un artefacto completo mediante rename, sin dejar JSON parcial
  /// visible si falla la operación o Android cierra el proceso.
  Future<File> jsonFile(Directory directory, String name, Object data) async {
    if (!RegExp(r'^[a-z_]+\.json$').hasMatch(name)) {
      throw const FormatException('Nombre inválido.');
    }
    final target = File('${directory.path}/$name');
    final temp = File('${target.path}.writing');
    await temp.writeAsString(jsonEncode(data), flush: true);
    return temp.rename(target.path);
  }
}
