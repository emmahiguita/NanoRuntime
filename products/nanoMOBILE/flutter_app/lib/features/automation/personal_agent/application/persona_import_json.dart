part of 'persona_import.dart';

/// Parser especializado para importación de dataset de persona en JSON v1 y CSV.
/// Cumple SOLID y límite de < 300 líneas.
extension _PersonaImportJson on PersonaImportPipeline {
  void _parseJson({
    required String normalizedContent,
    required String scopeKey,
    required String fileName,
    required List<_Message> messages,
    required List<PersonaImportCandidate> candidates,
    required List<String> warnings,
    required void Function(String role, String text, int at) addMessage,
    required void Function(String incoming, String body, String kind, int at, {String source, Object? originalTimestamp}) addExample,
  }) {
    final decoded = jsonDecode(normalizedContent);
    if (decoded is! Map || decoded['version'] != 1) {
      throw const FormatException(
        'Se requiere JSON de personalización version: 1.',
      );
    }
    if (decoded['conversations'] != null) {
      throw const FormatException(
        'Importa un contacto por archivo para revisar su identidad y estilo.',
      );
    }
    final rawMessages = decoded['messages'] ?? const [];
    if (rawMessages is! List) {
      throw const FormatException('messages debe ser una lista.');
    }
    for (final row in rawMessages) {
      if (row is! Map) throw const FormatException('Mensaje JSON inválido.');
      final role = '${row['role'] ?? ''}'.trim().toLowerCase();
      if (_PersonaImportUtils._generatedRow(row)) {
        messages.add(const _Message('break', '', 0));
        warnings.add('Mensaje de Nano/asistente/sistema excluido.');
        continue;
      }
      if (role != 'owner' && role != 'contact') {
        throw const FormatException(
          'role debe ser owner o contact; no se adivina la autoría.',
        );
      }
      if (row['text'] is! String) {
        throw const FormatException('text debe ser texto.');
      }
      addMessage(role, row['text'] as String, _PersonaImportUtils._timestamp(row['timestamp']));
    }
    for (final row in _PersonaImportUtils._list(decoded, 'examples')) {
      if (_PersonaImportUtils._generatedRow(row)) {
        warnings.add('Ejemplo generado por Nano/asistente excluido.');
        continue;
      }
      final source = '${row['source'] ?? 'owner_import'}';
      final incoming = _PersonaImportUtils._text(
        row['incoming'] ?? row['incomingText'],
        'incoming',
      ).trim();
      addExample(
        incoming,
        _PersonaImportUtils._text(row['ownerReply'] ?? row['body'], 'ownerReply/body'),
        incoming.isEmpty ? 'style' : 'paired',
        _PersonaImportUtils._timestamp(row['timestamp']),
        source: source,
        originalTimestamp: row['timestamp'],
      );
    }
    for (final row in _PersonaImportUtils._list(decoded, 'templates')) {
      if (_PersonaImportUtils._generatedRow(row)) {
        warnings.add('Plantilla generada marcada como asistente excluida.');
        continue;
      }
      addExample(
        _PersonaImportUtils._text(row['incoming'], 'incoming'),
        _PersonaImportUtils._text(row['reply'] ?? row['body'], 'reply/body'),
        'template',
        _PersonaImportUtils._timestamp(row['timestamp']),
        originalTimestamp: row['timestamp'],
      );
    }
    for (final row in _PersonaImportUtils._list(decoded, 'memories')) {
      if (_PersonaImportUtils._generatedRow(row)) {
        warnings.add('Memoria generada por Nano/asistente excluida.');
        continue;
      }
      final kind = '${row['type'] ?? row['kind'] ?? ''}';
      if (!personalMemoryKinds.containsKey(kind)) {
        throw FormatException('Tipo de memoria no reconocido: $kind.');
      }
      final key = _PersonaImportUtils._text(row['key'], 'key').trim(),
          value = _PersonaImportUtils._text(row['value'], 'value').trim();
      if (key.isEmpty ||
          key.length > 120 ||
          value.isEmpty ||
          value.length > 2000) {
        throw const FormatException(
          'Memoria: key de 1–120 y value de 1–2000 caracteres.',
        );
      }
      final observed = _PersonaImportUtils._timestamp(row['observedAt'] ?? row['timestamp']);
      if (observed <= 0) {
        throw const FormatException(
          'Cada memoria importada necesita observedAt o timestamp original; no se inventa la fecha del hecho.',
        );
      }
      final expires = _PersonaImportUtils._timestamp(row['expiresAt']);
      if (expires > 0 && expires <= observed) {
        throw const FormatException(
          'expiresAt debe ser posterior a observedAt.',
        );
      }
      if (kind == 'temporaryFact' && (observed <= 0 || expires <= observed)) {
        throw const FormatException(
          'Un dato temporal necesita observedAt y expiresAt válidos.',
        );
      }
      final memory = PersonalMemory(
        scopeKey: scopeKey,
        key: key,
        value: value,
        kind: kind,
        observedAt: observed,
        metadata: {
          'enabled': 'true',
          'source': 'owner_import',
          'sourceName': fileName,
          'sourceContact': scopeKey,
          'observedAt': '$observed',
          'originalTimestamp': '${row['observedAt'] ?? row['timestamp']}',
          'ownerVerified': 'false',
          'fingerprint': _PersonaImportUtils._hash(
            jsonEncode([kind, key, value, observed, expires]),
          ),
          if (expires > 0) 'expiresAt': '$expires',
        },
      );
      candidates.add(
        PersonaImportCandidate(
          kind: 'memory',
          title: personalMemoryKinds[kind]!,
          preview: '$key: $value',
          memory: memory,
        ),
      );
    }
  }

  void _parseCsv({
    required String normalizedContent,
    required List<_Message> messages,
    required List<String> warnings,
    required void Function(String role, String text, int at) addMessage,
  }) {
    final table = _csv(normalizedContent);
    if (table.isEmpty) throw const FormatException('CSV vacío.');
    final header = table.first.map((s) => s.trim().toLowerCase()).toList();
    final roleIndex = header.indexOf('role'),
        textIndex = header.indexOf('text'),
        timeIndex = header.indexOf('timestamp');
    if (header.toSet().length != header.length) {
      throw const FormatException('CSV con nombres de columna duplicados.');
    }
    if (roleIndex < 0 || textIndex < 0) {
      throw const FormatException(
        'CSV requiere columnas role,text y timestamp opcional.',
      );
    }
    for (final row in table.skip(1)) {
      if (row.every((v) => v.trim().isEmpty)) continue;
      if (row.length != header.length) {
        throw const FormatException('CSV con columnas incompletas.');
      }
      final role = row[roleIndex].trim().toLowerCase();
      if (_PersonaImportUtils._generatedRow(Map.fromIterables(header, row))) {
        messages.add(const _Message('break', '', 0));
        warnings.add('Salida generada excluida.');
        continue;
      }
      if (role != 'owner' && role != 'contact') {
        throw const FormatException('CSV: role debe ser owner o contact.');
      }
      addMessage(
        role,
        row[textIndex],
        timeIndex < 0 ? 0 : _PersonaImportUtils._timestamp(row[timeIndex]),
      );
    }
  }

  static List<List<String>> _csv(String source) {
    final header = source.split('\n').first;
    var inQuotes = false, commas = 0, semicolons = 0;
    for (var i = 0; i < header.length; i++) {
      if (header[i] == '"') {
        if (inQuotes && i + 1 < header.length && header[i + 1] == '"') {
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (!inQuotes) {
        if (header[i] == ',') commas++;
        if (header[i] == ';') semicolons++;
      }
    }
    final delimiter = semicolons > commas ? ';' : ',';
    final result = <List<String>>[];
    var row = <String>[], cell = StringBuffer(), quoted = false, closed = false;
    for (var i = 0; i < source.length; i++) {
      final c = source[i];
      if (quoted) {
        if (c == '"') {
          if (i + 1 < source.length && source[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            quoted = false;
            closed = true;
          }
        } else {
          cell.write(c);
        }
      } else if (c == delimiter || c == '\n') {
        row.add(cell.toString());
        cell = StringBuffer();
        closed = false;
        if (c == '\n') {
          result.add(row);
          row = [];
        }
      } else if (c == '"') {
        if (closed || cell.isNotEmpty) {
          throw const FormatException(
            'CSV: una celda con comillas debe estar entre comillas dobles; escapa las interiores duplicándolas.',
          );
        }
        quoted = true;
      } else if (closed) {
        if (c != ' ' && c != '\t') {
          throw const FormatException(
            'CSV: contenido después de cerrar una celda con comillas.',
          );
        }
      } else {
        cell.write(c);
      }
    }
    if (quoted) throw const FormatException('Comillas CSV sin cerrar.');
    if (cell.isNotEmpty || row.isNotEmpty || closed) {
      row.add(cell.toString());
      result.add(row);
    }
    return result;
  }
}
