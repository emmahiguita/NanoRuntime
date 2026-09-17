import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../domain/personal_memory.dart';

part 'persona_import_utils.dart';
part 'persona_import_whatsapp.dart';
part 'persona_import_json.dart';

/// Candidato a importación para revisión del usuario antes de persistir.
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

/// Vista previa y aceptación selectiva de un lote importado.
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

/// Pipeline modular de importación de estilos, chats y memorias de persona.
/// Cumple Clean Architecture, SOLID y límite de < 200 líneas.
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
      if (_PersonaImportUtils._excludedBody(body) ||
          (incoming.isNotEmpty && _PersonaImportUtils._excludedBody(incoming))) {
        warnings.add('Contenido omitido, eliminado o multimedia excluido.');
        return;
      }
      if (incoming.length > 2000 || body.length > 2000) {
        warnings.add(
          'Un par supera 2000 caracteres por mensaje y necesita revisión manual.',
        );
        return;
      }
      if (_PersonaImportUtils._generatedSource(source)) {
        warnings.add('Salida generada excluida del aprendizaje del dueño.');
        return;
      }
      final fingerprint = _PersonaImportUtils._hash(
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
      } else if (text.trim().isEmpty || _PersonaImportUtils._excludedBody(text)) {
        messages.add(const _Message('break', '', 0));
        warnings.add(
          'Mensaje vacío, eliminado o multimedia excluido; se separaron sus pares.',
        );
      } else {
        messages.add(_Message(role, text.trim(), at));
      }
    }

    if (extension == 'json') {
      _parseJson(
        normalizedContent: normalizedContent,
        scopeKey: scopeKey,
        fileName: fileName,
        messages: messages,
        candidates: candidates,
        warnings: warnings,
        addMessage: message,
        addExample: example,
      );
    } else if (extension == 'csv') {
      _parseCsv(
        normalizedContent: normalizedContent,
        messages: messages,
        warnings: warnings,
        addMessage: message,
      );
    } else if (extension == 'txt') {
      _parseWhatsAppTxt(
        normalizedContent: normalizedContent,
        ownerName: ownerName,
        messages: messages,
        warnings: warnings,
        addMessage: message,
      );
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

    // Unir fragmentos continuos en pares entrante → respuesta del dueño
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

    for (final m in messages) {
      if (m.role == 'break') {
        flush();
        continue;
      }
      if (m.role == 'contact') {
        if (owner.isNotEmpty) flush();
        incoming.add(m.text);
      } else {
        owner.add(m.text);
        stamp = m.at;
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
      batchId: _PersonaImportUtils._hash('$scopeKey\u0000$normalizedContent'),
      fileName: fileName,
      scopeKey: scopeKey,
      history: content,
      candidates: unique.values.toList(),
      warnings: warnings.toSet().toList(),
    );
  }
}
