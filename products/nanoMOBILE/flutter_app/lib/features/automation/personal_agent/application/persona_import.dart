import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../domain/personal_memory.dart';

/// One local import pipeline. Parsers produce reviewable candidates, never
/// mutate repositories, generate text, or infer present facts from chat history.
final class PersonaImportCandidate {
  const PersonaImportCandidate({
    required this.kind,
    required this.title,
    required this.preview,
    this.example,
    this.memory,
  });
  final String kind, title, preview;
  final Map<String, Object?>? example;
  final PersonalMemory? memory;
}

final class PersonaImportPreview {
  const PersonaImportPreview({
    required this.batchId,
    required this.fileName,
    required this.scopeKey,
    required this.history,
    required this.candidates,
    required this.warnings,
  });
  final String batchId, fileName, scopeKey, history;
  final List<PersonaImportCandidate> candidates;
  final List<String> warnings;
  Map<String, Object?> accepted(
    Set<int> indices, {
    required bool ownerVerified,
  }) {
    final examples = <Map<String, Object?>>[];
    final memories = <Map<String, Object?>>[];
    for (final index in indices.toList()..sort()) {
      if (index < 0 || index >= candidates.length) {
        throw StateError('La selección de revisión ya no es válida.');
      }
      final candidate = candidates[index];
      if (candidate.example case final example?) {
        if (candidate.kind != 'template' && !ownerVerified) {
          throw StateError(
            'Confirma qué respuestas escribiste tú antes de guardar.',
          );
        }
        final tone = Map<String, String>.from(example['tone'] as Map);
        tone['ownerVerified'] =
            '${candidate.kind != 'template' && ownerVerified}';
        examples.add({...example, 'tone': tone});
      }
      if (candidate.memory case final memory?) {
        memories.add(
          memory
              .copyWith(metadata: {...memory.metadata, 'ownerVerified': 'true'})
              .toJson(),
        );
      }
    }
    if (examples.isEmpty && memories.isEmpty) {
      throw StateError('Selecciona datos para guardar.');
    }
    return {
      'batchId': batchId,
      'fileName': fileName,
      'scopeKey': scopeKey,
      'history': history,
      'examples': examples,
      'memories': memories,
    };
  }
}

final class PersonaImportPipeline {
  const PersonaImportPipeline();
  static const maxBytes = 2000000;
  static const maxCandidates = 1000;
  PersonaImportPreview parse({
    required String content,
    required String fileName,
    required String scopeKey,
    String ownerName = '',
  }) {
    if (utf8.encode(content).length > maxBytes) {
      throw const FormatException(
        'Máximo 2 MB por importación. Divide el historial.',
      );
    }
    // BOM and platform line endings are transport details, not message content.
    final normalizedContent = content
        .replaceFirst(RegExp(r'^\uFEFF'), '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final warnings = <String>[];
    final candidates = <PersonaImportCandidate>[];
    final messages = <_Message>[];
    final extension = fileName.split('.').last.toLowerCase();
    void example(
      String incoming,
      String body,
      String kind,
      int at, {
      String source = 'owner_import',
      Object? originalTimestamp,
    }) {
      incoming = incoming.trim();
      body = body.trim();
      if (body.isEmpty) return;
      if (_excludedBody(body) ||
          (incoming.isNotEmpty && _excludedBody(incoming))) {
        warnings.add('Contenido omitido, eliminado o multimedia excluido.');
        return;
      }
      if (incoming.length > 2000 || body.length > 2000) {
        warnings.add(
          'Un par supera 2000 caracteres por mensaje y necesita revisión manual.',
        );
        return;
      }
      if (_generatedSource(source)) {
        warnings.add('Salida generada excluida del aprendizaje del dueño.');
        return;
      }
      final fingerprint = _hash(
        jsonEncode([kind, incoming.trim(), body.trim()]),
      );
      candidates.add(
        PersonaImportCandidate(
          kind: kind,
          title: kind == 'template'
              ? 'Plantilla de orientación'
              : kind == 'style'
              ? 'Solo estilo: sin entrada original'
              : 'Par real recibido → dueño',
          preview: incoming.isEmpty ? body : '$incoming\n→ $body',
          example: {
            'personaKey': scopeKey,
            'incomingText': incoming.trim(),
            'body': body.trim(),
            'source': kind == 'template' ? 'template' : 'owner_import',
            'tone': <String, String>{
              'kind': kind,
              'fingerprint': fingerprint,
              'sourceContact': scopeKey,
              'observedAt': '$at',
              if (originalTimestamp != null &&
                  '$originalTimestamp'.trim().isNotEmpty)
                'originalTimestamp': '$originalTimestamp',
              'sourceName': fileName,
              'ownerVerified': 'false',
              'enabled': 'true',
            },
          },
        ),
      );
    }

    void message(String role, String text, int at) {
      if (text.length > 2000) {
        messages.add(const _Message('break', '', 0));
        warnings.add(
          'Mensaje de más de 2000 caracteres excluido; se separaron sus pares.',
        );
      } else if (text.trim().isEmpty || _excludedBody(text)) {
        messages.add(const _Message('break', '', 0));
        warnings.add(
          'Mensaje vacío, eliminado o multimedia excluido; se separaron sus pares.',
        );
      } else {
        messages.add(_Message(role, text.trim(), at));
      }
    }

    if (extension == 'json') {
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
        if (_generatedRow(row)) {
          // Break pairing around generated/system output: no accidental owner target.
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
        message(role, row['text'] as String, _timestamp(row['timestamp']));
      }
      for (final row in _list(decoded, 'examples')) {
        if (_generatedRow(row)) {
          warnings.add('Ejemplo generado por Nano/asistente excluido.');
          continue;
        }
        final source = '${row['source'] ?? 'owner_import'}';
        final incoming = _text(
          row['incoming'] ?? row['incomingText'],
          'incoming',
        ).trim();
        example(
          incoming,
          _text(row['ownerReply'] ?? row['body'], 'ownerReply/body'),
          incoming.isEmpty ? 'style' : 'paired',
          _timestamp(row['timestamp']),
          source: source,
          originalTimestamp: row['timestamp'],
        );
      }
      for (final row in _list(decoded, 'templates')) {
        if (_generatedRow(row)) {
          warnings.add('Plantilla generada marcada como asistente excluida.');
          continue;
        }
        example(
          _text(row['incoming'], 'incoming'),
          _text(row['reply'] ?? row['body'], 'reply/body'),
          'template',
          _timestamp(row['timestamp']),
          originalTimestamp: row['timestamp'],
        );
      }
      for (final row in _list(decoded, 'memories')) {
        if (_generatedRow(row)) {
          warnings.add('Memoria generada por Nano/asistente excluida.');
          continue;
        }
        final kind = '${row['type'] ?? row['kind'] ?? ''}';
        if (!personalMemoryKinds.containsKey(kind)) {
          throw FormatException('Tipo de memoria no reconocido: $kind.');
        }
        final key = _text(row['key'], 'key').trim(),
            value = _text(row['value'], 'value').trim();
        if (key.isEmpty ||
            key.length > 120 ||
            value.isEmpty ||
            value.length > 2000) {
          throw const FormatException(
            'Memoria: key de 1–120 y value de 1–2000 caracteres.',
          );
        }
        final observed = _timestamp(row['observedAt'] ?? row['timestamp']);
        if (observed <= 0) {
          throw const FormatException(
            'Cada memoria importada necesita observedAt o timestamp original; no se inventa la fecha del hecho.',
          );
        }
        final expires = _timestamp(row['expiresAt']);
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
            'fingerprint': _hash(
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
    } else if (extension == 'csv') {
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
        if (_generatedRow(Map.fromIterables(header, row))) {
          messages.add(const _Message('break', '', 0));
          warnings.add('Salida generada excluida.');
          continue;
        }
        if (role != 'owner' && role != 'contact') {
          throw const FormatException('CSV: role debe ser owner o contact.');
        }
        message(
          role,
          row[textIndex],
          timeIndex < 0 ? 0 : _timestamp(row[timeIndex]),
        );
      }
    } else if (extension == 'txt') {
      if (ownerName.trim().isEmpty) {
        throw const FormatException(
          'Escribe tu nombre exactamente como aparece en la exportación TXT.',
        );
      }
      final pattern = RegExp(
        r'^\[?(\d{1,2})[/-](\d{1,2})[/-](\d{2,4}),?\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([ap]\.?(?:\s*m)\.?)?\]?\s*(?:-\s*)?(.*)$',
        caseSensitive: false,
      );
      final datePrefix = RegExp(r'^\[?\d{1,2}[/-]\d{1,2}[/-]\d{2,4}(?:,|\s)');
      final authors = <String>{};
      final expectedOwner = _author(ownerName);
      var ownerSeen = false;
      for (final raw in normalizedContent.split('\n')) {
        final line = raw
            .replaceAll('\u200e', '')
            .replaceAll('\u200f', '')
            .replaceAll('\u202f', ' ')
            .replaceAll('\u00a0', ' ');
        final match = pattern.firstMatch(line);
        if (match == null) {
          if (datePrefix.hasMatch(line)) {
            messages.add(const _Message('break', '', 0));
            warnings.add(
              'Línea con fecha no reconocida; se separaron sus pares.',
            );
          } else if (messages.isNotEmpty &&
              messages.last.role != 'break' &&
              line.isNotEmpty) {
            final previous = messages.removeLast();
            message(previous.role, '${previous.text}\n$line', previous.at);
          } else if (line.trim().isNotEmpty) {
            warnings.add('Línea sin mensaje anterior reconocible excluida.');
          }
          continue;
        }
        var year = int.parse(match[3]!);
        if (year < 100) year += 2000;
        final day = int.parse(match[1]!), month = int.parse(match[2]!);
        var hour = int.parse(match[4]!);
        final minute = int.parse(match[5]!),
            second = int.parse(match[6] ?? '0');
        final meridiem = (match[7] ?? '').toLowerCase();
        if (minute > 59 ||
            second > 59 ||
            (meridiem.isEmpty ? hour > 23 : hour < 1 || hour > 12) ||
            !_validDate(year, month, day)) {
          throw const FormatException(
            'TXT requiere fechas día/mes/año y horas válidas.',
          );
        }
        if (meridiem.isNotEmpty) {
          hour %= 12;
          if (meridiem.startsWith('p')) hour += 12;
        }
        final time = DateTime(year, month, day, hour, minute, second);
        final payload = match[8]!;
        final separator = payload.indexOf(': ');
        if (separator <= 0 || _systemNotice(payload)) {
          messages.add(const _Message('break', '', 0));
          warnings.add(
            'Aviso del sistema sin autor excluido; se separaron sus pares.',
          );
          continue;
        }
        final author = _author(payload.substring(0, separator));
        final isOwner = author == expectedOwner;
        if (isOwner) {
          ownerSeen = true;
        } else {
          authors.add(author);
          if (authors.length > 1) {
            throw const FormatException(
              'El TXT contiene varios interlocutores o un grupo. Importa un contacto por archivo para no mezclar su identidad ni sus respuestas.',
            );
          }
        }
        message(
          isOwner ? 'owner' : 'contact',
          payload.substring(separator + 2),
          time.millisecondsSinceEpoch,
        );
      }
      if (messages.isEmpty) {
        throw const FormatException(
          'No se reconocieron mensajes de exportación WhatsApp TXT.',
        );
      }
      if (!ownerSeen) {
        throw const FormatException(
          'Tu nombre no coincide con ningún autor del TXT. Escríbelo exactamente como aparece en la exportación.',
        );
      }
    } else {
      throw const FormatException(
        'Formatos disponibles: JSON v1, CSV y TXT exportado de WhatsApp.',
      );
    }
    if (messages.length > 5000) {
      throw const FormatException(
        'Máximo 5000 mensajes por archivo. Divide el historial.',
      );
    }
    // Preserve source order. Contiguous incoming/owner fragments form one pair.
    final incoming = <String>[], owner = <String>[];
    var stamp = 0;
    void flush() {
      if (owner.isNotEmpty) {
        example(
          incoming.join('\n'),
          owner.join('\n'),
          incoming.isEmpty ? 'style' : 'paired',
          stamp,
        );
      }
      incoming.clear();
      owner.clear();
    }

    for (final message in messages) {
      if (message.role == 'break') {
        flush();
        continue;
      }
      if (message.role == 'contact') {
        if (owner.isNotEmpty) flush();
        incoming.add(message.text);
      } else {
        owner.add(message.text);
        stamp = message.at;
      }
    }
    flush();
    final unique = <String, PersonaImportCandidate>{};
    for (final c in candidates) {
      final key = c.example != null
          ? (c.example!['tone'] as Map)['fingerprint'] as String
          : c.memory!.metadata['fingerprint']!;
      unique.putIfAbsent(key, () => c);
    }
    if (unique.length > maxCandidates) {
      throw const FormatException(
        'Máximo 1000 candidatos por lote. Divide el historial.',
      );
    }
    if (unique.isEmpty) {
      throw const FormatException(
        'No hay pares, estilos, plantillas o memorias importables.',
      );
    }
    return PersonaImportPreview(
      batchId: _hash('$scopeKey\u0000$normalizedContent'),
      fileName: fileName,
      scopeKey: scopeKey,
      history: content,
      candidates: unique.values.toList(),
      warnings: warnings.toSet().toList(),
    );
  }

  static Iterable<Map> _list(Map map, String key) sync* {
    final rows = map[key] ?? const [];
    if (rows is! List) throw FormatException('$key debe ser una lista.');
    for (final row in rows) {
      if (row is! Map) throw FormatException('Registro inválido en $key.');
      yield row;
    }
  }

  static String _text(Object? value, String field) {
    if (value == null) return '';
    if (value is! String) {
      throw FormatException('$field debe ser texto.');
    }
    return value;
  }

  static bool _generatedSource(Object? value) {
    final source = '$value'.trim().toLowerCase();
    return source.contains('nano') ||
        source.contains('assistant') ||
        source.contains('generated') ||
        source == 'system' ||
        source == 'ai' ||
        source == 'llm' ||
        source == 'model';
  }

  static bool _generatedRow(Map row) {
    final fields = row.map(
      (key, value) => MapEntry('$key'.toLowerCase(), value),
    );
    final marker = '${fields['generatedbynano'] ?? ''}'.trim().toLowerCase();
    return marker == 'true' ||
        marker == '1' ||
        _generatedSource(fields['role']) ||
        _generatedSource(fields['source']) ||
        _generatedSource(fields['generatedby']);
  }

  static String _author(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static bool _excludedBody(String value) {
    final omitted = RegExp(
      r'^(?:<?(?:multimedia|media|image|imagen|video|vídeo|audio|sticker|gif|document|documento|contact card|tarjeta de contacto)\s+(?:omiti(?:do|da)s?|omitted)>?|\[?(?:this message was deleted|you deleted this message|se eliminó este mensaje|eliminaste este mensaje|mensaje eliminado)\]?|<attached:.*>|.*\(archivo adjunto\))$',
      caseSensitive: false,
    );
    return value.split('\n').any((line) => omitted.hasMatch(line.trim()));
  }

  static bool _systemNotice(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.startsWith(
          'messages and calls are end-to-end encrypted',
        ) ||
        normalized.startsWith('los mensajes y las llamadas están cifrados') ||
        normalized.startsWith('your security code with ') ||
        normalized.startsWith('cambió tu código de seguridad con ') ||
        normalized.startsWith('cambió el código de seguridad con ') ||
        normalized.startsWith('you turned on disappearing messages') ||
        normalized.startsWith('you turned off disappearing messages');
  }

  static bool _validDate(int year, int month, int day) {
    if (year < 1970 ||
        year > 9999 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      return false;
    }
    final parsed = DateTime.utc(year, month, day);
    return parsed.year == year && parsed.month == month && parsed.day == day;
  }

  static int _timestamp(Object? value) {
    final text = value == null ? '' : '$value'.trim();
    if (text.isEmpty) return 0;
    // Keep dates representable in Dart, native SQLite metadata and the UI.
    const maximum = 253402300799999; // 9999-12-31T23:59:59.999Z.
    if (value is num &&
        (!value.isFinite || value != value.truncateToDouble())) {
      throw const FormatException(
        'Unix debe ser un número entero de milisegundos.',
      );
    }
    final numeric = value is num ? value.toInt() : int.tryParse(text);
    if (numeric != null) {
      if (numeric < 0 || numeric > maximum) {
        throw const FormatException('Timestamp fuera del rango 1970–9999.');
      }
      return numeric;
    }
    final iso = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:[Tt ](\d{2}):(\d{2})(?::(\d{2})(?:[.,]\d{1,6})?)?(?:[Zz]|[+-](\d{2}):?(\d{2}))?)?$',
    ).firstMatch(text);
    if (iso == null ||
        !_validDate(
          int.parse(iso[1]!),
          int.parse(iso[2]!),
          int.parse(iso[3]!),
        ) ||
        int.parse(iso[4] ?? '0') > 23 ||
        int.parse(iso[5] ?? '0') > 59 ||
        int.parse(iso[6] ?? '0') > 59 ||
        int.parse(iso[7] ?? '0') > 23 ||
        int.parse(iso[8] ?? '0') > 59) {
      throw const FormatException(
        'Fecha inválida; usa ISO 8601 o Unix en milisegundos.',
      );
    }
    final parsed = DateTime.tryParse(text);
    if (parsed == null ||
        parsed.millisecondsSinceEpoch < 0 ||
        parsed.millisecondsSinceEpoch > maximum) {
      throw const FormatException('Fecha fuera del rango 1970–9999.');
    }
    return parsed.millisecondsSinceEpoch;
  }

  static String _hash(String value) =>
      sha256.convert(utf8.encode(value)).toString();

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

final class _Message {
  const _Message(this.role, this.text, this.at);
  final String role, text;
  final int at;
}
