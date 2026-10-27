import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../engine/language/conversation_semantic_tag.dart';
import '../domain/personal_memory.dart';
import 'personal_learning_text.dart';

part 'persona_import_utils.dart';
part 'persona_import_models.dart';
part 'persona_import_candidate_builder.dart';
part 'persona_import_whatsapp.dart';
part 'persona_import_json.dart';
part 'persona_import_csv.dart';

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
    }) => _addExampleCandidate(
      incoming: incoming,
      body: body,
      kind: kind,
      at: at,
      source: source,
      originalTimestamp: originalTimestamp,
      scopeKey: scopeKey,
      fileName: fileName,
      candidates: candidates,
      warnings: warnings,
    );

    void message(String role, String text, int at) => _addMessage(
      role: role,
      text: text,
      at: at,
      messages: messages,
      warnings: warnings,
    );

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
