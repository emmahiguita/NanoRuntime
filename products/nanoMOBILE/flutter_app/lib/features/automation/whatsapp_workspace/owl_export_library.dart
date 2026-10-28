import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'owl_workspace_store.dart';
import 'whatsapp_export_document.dart';

/// Biblioteca privada de exportaciones oficiales; el índice usa el SQLite de
/// Nano y el texto completo queda en archivos propios, fuera del prompt visible.
class OwlExportLibrary {
  OwlExportLibrary(this.store);
  final OwlWorkspaceStore store;
  static const section = 'owl_exports_v1';

  /// Selección explícita; no busca carpetas privadas ni descarga historiales.
  Future<String> pickAndImport() async {
    final choice = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['txt', 'zip'],
      allowMultiple: false,
    );
    if (choice == null)
      return 'Importación cancelada; no se modificó el historial.';
    final source = choice.files.single;
    if (source.path == null)
      throw const FormatException('El proveedor no entregó un archivo local.');
    return importFile(source.path!, source.name);
  }

  /// Guarda original, JSON normalizado e índice. El parseo/ZIP corre en isolate;
  /// una escritura fallida no aparece como importación terminada.
  Future<String> importFile(String path, String name) async {
    if (!RegExp(r'\.(txt|zip)$', caseSensitive: false).hasMatch(name)) {
      throw const FormatException(
        'Selecciona TXT o ZIP exportado por WhatsApp.',
      );
    }
    final source = File(path);
    if (await source.length() > 16 * 1024 * 1024)
      throw const FormatException('Archivo mayor de 16 MB.');
    final parsed = await compute(decodeWhatsAppExport, {
      'path': path,
      'name': name,
    });
    final bytes = await source.readAsBytes();
    final hash = sha256.convert(bytes).toString();
    final id = 'chat_${hash.substring(0, 24)}';
    final directory = await store.folder('exports', id);
    final original = File(
      '${directory.path}/original.${name.toLowerCase().endsWith('.zip') ? 'zip' : 'txt'}',
    );
    await original.writeAsBytes(bytes, flush: true);
    await store.jsonFile(directory, 'conversation.json', parsed);
    final messages = parsed['messages'] as List;
    final senders = messages
        .cast<Map>()
        .map((m) => m['sender'])
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    await store.record(section, id, {
      'id': id,
      'name': name,
      'sha256': hash,
      'count': messages.length,
      'senders': senders,
      'importedAt': DateTime.now().millisecondsSinceEpoch,
      'identityVerified': false,
      'source': 'whatsapp_official_export',
    });
    return 'Historial guardado: $name\n${messages.length} mensajes; ${senders.length} autores del archivo. '
        'Original y texto normalizado conservados. No acredita la identidad de una cuenta. '
        'Para analizarlo: «Analiza el historial completo importado».';
  }

  /// Solo accede a un ID del índice; no acepta rutas pedidas por una página/chat.
  Future<
    ({
      Map<String, dynamic> meta,
      List<Map<String, dynamic>> messages,
      Directory folder,
      String preamble,
    })
  >
  latest() async {
    final rows = await store.index(section);
    final all =
        rows.values
            .whereType<Map>()
            .map((v) => Map<String, dynamic>.from(v))
            .toList()
          ..sort(
            (a, b) =>
                (b['importedAt'] as num).compareTo(a['importedAt'] as num),
          );
    if (all.isEmpty)
      throw const FormatException(
        'Importa primero un TXT o ZIP oficial de WhatsApp.',
      );
    final meta = all.first;
    final directory = await store.folder('exports', meta['id'] as String);
    final data =
        jsonDecode(
              await File('${directory.path}/conversation.json').readAsString(),
            )
            as Map;
    return (
      meta: meta,
      preamble: data['preamble'] as String? ?? '',
      messages: (data['messages'] as List)
          .cast<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(),
      folder: directory,
    );
  }
}
