/// PERSONA-DATASET-06 — ejemplo de estilo del dueño (dataset de retrieval).
///
/// Cada ejemplo es un mensaje tal como lo escribiría el dueño. El retriever
/// (PERSONA-RETRIEVAL-07) lo busca por similitud textual con FTS4 y
/// COMPOSE-08 muestra los más parecidos al contexto como guía de estilo —
/// sin embeddings: FTS4 puro en SQLite v3.
library;

import 'dart:convert';

final class PersonaExample {
  final int id;
  final String personaKey;
  final String body;

  /// R5-03 — entrada del cliente a la que responde [body] (par condicionado,
  /// invariante PAST INPUT → PAST OWNER OUTPUT). Vacío = ejemplo legacy de
  /// estilo sin condicionar (jamás matchea el input entrante).
  final String incomingText;

  /// Datos de tono opcionales del ejemplo (ej. {"warmth": "cercano"}).
  final Map<String, String> tone;
  final String source;

  const PersonaExample({
    required this.id,
    required this.personaKey,
    required this.body,
    this.incomingText = '',
    this.tone = const {},
    this.source = '',
  });

  bool get enabled => tone['enabled'] != 'false';
  bool get isTemplate => tone['kind'] == 'template';
  String get importBatch => tone['importBatch'] ?? '';
  bool get ownerVerified =>
      source == 'manual' || tone['ownerVerified'] == 'true';

  /// R5-03 — ¿par condicionado (trae entrada de cliente)?
  bool get isPaired => incomingText.trim().isNotEmpty;

  factory PersonaExample.fromRow(Map<dynamic, dynamic> row) {
    final tone = <String, String>{};
    final toneRaw = row['toneJson'];
    if (toneRaw is String && toneRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(toneRaw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.key is String && entry.value is String) {
              tone[entry.key as String] = entry.value as String;
            }
          }
        }
      } on Object {
        // tone corrupto: se descarta.
      }
    }
    return PersonaExample(
      id: int.tryParse('${row['id'] ?? ''}') ?? -1,
      personaKey: row['personaKey'] as String? ?? '',
      body: row['body'] as String? ?? '',
      incomingText: row['incomingText'] as String? ?? '',
      tone: tone,
      source: row['source'] as String? ?? '',
    );
  }
}
