import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'package:json_schema/json_schema.dart';

/// Valida JSON Schema antes de llamar al servidor. No resuelve URLs ni registra datos.
/// El isolate se mata al vencer el plazo para no bloquear la interfaz con un esquema.
abstract final class McpSchemaValidator {
  static Future<List<String>> validate(
    Map<String, Object?> schema,
    Map<String, Object?> arguments,
  ) async {
    if (utf8.encode(jsonEncode(schema)).length > 64 * 1024 ||
        utf8.encode(jsonEncode(arguments)).length > 1024 * 1024) {
      return ['El esquema o los argumentos superan el tamaño permitido.'];
    }
    final missing =
        (schema['required'] is List ? schema['required'] as List : [])
            .whereType<String>()
            .where((key) => !arguments.containsKey(key))
            .toList();
    if (missing.isNotEmpty) {
      return ['Faltan argumentos: ${missing.join(", ")}.'];
    }
    final port = ReceivePort();
    Isolate? worker;
    try {
      worker = await Isolate.spawn(_validateMcpSchema, [
        port.sendPort,
        schema,
        arguments,
      ], onError: port.sendPort);
      final reply = await port.first.timeout(const Duration(seconds: 1));
      return reply is List<String>
          ? reply
          : ['No se pudo validar el esquema de la herramienta.'];
    } on TimeoutException {
      return [
        'La validación excedió su presupuesto; no se ejecutó la herramienta.',
      ];
    } on Object {
      return [
        'Esquema no válido o no compatible; no se ejecutó la herramienta.',
      ];
    } finally {
      worker?.kill(priority: Isolate.immediate);
      port.close();
    }
  }
}

/// Recibe solo datos JSON. Las referencias externas se rechazan explícitamente.
void _validateMcpSchema(List<Object?> request) {
  final send = request[0] as SendPort;
  try {
    final schema = Map<String, dynamic>.from(request[1] as Map);
    final pending = <Object?>[schema];
    var count = 0;
    while (pending.isNotEmpty) {
      if (++count > 8192) throw const FormatException('schema_too_complex');
      final node = pending.removeLast();
      if (node is Map) {
        for (final key in [r'$ref', r'$dynamicRef']) {
          final ref = node[key];
          if (ref is String && !ref.startsWith('#')) {
            throw const FormatException('external_schema_reference');
          }
        }
        pending.addAll(node.values);
      } else if (node is List) {
        pending.addAll(node);
      }
    }
    final declaration = schema[r'$schema']?.toString();
    final version = declaration == null || declaration.contains('2020-12')
        ? SchemaVersion.draft2020_12
        : declaration.contains('2019-09')
        ? SchemaVersion.draft2019_09
        : declaration.contains('draft-07')
        ? SchemaVersion.draft7
        : declaration.contains('draft-06')
        ? SchemaVersion.draft6
        : declaration.contains('draft-04')
        ? SchemaVersion.draft4
        : throw const FormatException('unsupported_schema_version');
    final validator = JsonSchema.create(
      schema,
      schemaVersion: version,
      refProvider: RefProvider.sync((_) => null),
    );
    final result = validator.validate(request[2]);
    send.send(
      result.errors
          .take(8)
          .map(
            (error) =>
                '${error.instancePath.isNotEmpty ? error.instancePath : "/"}: '
                'no cumple ${error.schemaPath}.',
          )
          .toList(),
    );
  } on Object {
    send.send(<String>[
      'Esquema inválido, referencia sin resolver o versión no compatible.',
    ]);
  }
}
