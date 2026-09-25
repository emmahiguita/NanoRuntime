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
    required void Function(
      String incoming,
      String body,
      String kind,
      int at, {
      String source,
      Object? originalTimestamp,
    })
    addExample,
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
      addMessage(
        role,
        row['text'] as String,
        _PersonaImportUtils._timestamp(row['timestamp']),
      );
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
        _PersonaImportUtils._text(
          row['ownerReply'] ?? row['body'],
          'ownerReply/body',
        ),
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
      final observed = _PersonaImportUtils._timestamp(
        row['observedAt'] ?? row['timestamp'],
      );
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
}
