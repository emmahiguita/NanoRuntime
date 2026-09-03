/// WA-MIRROR-01 — ConversationSearch: búsqueda local determinista sobre la
/// memoria de conversación. Sin LLM: barata, reproducible y honesta — no
/// "semántica" fingida, sino matching por tokens normalizados con ranking
/// transparente.
///
/// Reglas duras:
/// - Solo lectura: recibe un [ConversationMemory] (snapshot inmutable) y
///   devuelve entradas del mismo snapshot. Cero escritura, cero canales.
/// - El ranking se explica solo: coincidencia en texto pesa más que en
///   remitente; empates se resuelven por recencia.
library;

import 'package:nanoai/features/automation/engine/messaging/conversation_memory.dart';

/// Entrada encontrada con la razón de su coincidencia: el consumidor puede
/// mostrar POR QUÉ apareció, no un score opaco.
final class ConversationSearchHit {
  const ConversationSearchHit({required this.entry, required this.score});

  final ConversationMemoryEntry entry;
  final int score;
}

/// Buscador local puro. Normaliza query y entradas (lowercase), parte la
/// query en tokens y puntúa: +2 por token hallado en el texto, +1 por token
/// en el remitente. Solo entradas con score > 0, ordenadas por score y
/// recencia (la más reciente desempata).
final class ConversationSearch {
  const ConversationSearch();

  static const int maxResults = 20;

  List<ConversationSearchHit> search(ConversationMemory memory, String query) {
    final tokens = _tokens(query);
    if (tokens.isEmpty || memory.isEmpty) return const [];

    final hits = <ConversationSearchHit>[];
    for (final entry in memory.entries) {
      final text = entry.text.toLowerCase();
      final sender = entry.sender.toLowerCase();
      var score = 0;
      for (final token in tokens) {
        if (text.contains(token)) score += 2;
        if (sender.isNotEmpty && sender.contains(token)) score += 1;
      }
      if (score > 0) {
        hits.add(ConversationSearchHit(entry: entry, score: score));
      }
    }
    hits.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : b.entry.atMs.compareTo(a.entry.atMs);
    });
    return hits.take(maxResults).toList(growable: false);
  }

  static List<String> _tokens(String query) => query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList(growable: false);
}
