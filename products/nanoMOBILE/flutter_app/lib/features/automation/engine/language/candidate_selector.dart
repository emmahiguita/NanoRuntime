// candidate_selector.dart
//
// QUÉ HACE:
// Selecciona deterministamente respuestas candidatas en fast-path garantizando variedad
// conversacional, naturalidad y anti-repetición de mensajes salientes.
//
// CÓMO FUNCIONA:
// - Consulta los últimos mensajes salientes en `ConversationMemory` para esa conversación
//   y descarta del pool de candidatos las frases emitidas recientemente.
// - Combina en la semilla pseudoaleatoria el ID de la conversación, el timestamp y la
//   cantidad de turnos observados (`turnCount`), asegurando que múltiples mensajes en un
//   mismo minuto avancen secuencialmente de candidato en vez de estancarse en el mismo.
// - Provee hasta 3 sugerencias alternativas distintas para selección rápida.
//
// POR QUÉ:
// Resuelve el hallazgo AUT-P2-11 (repetición semántica y lenguaje estático entre turnos),
// evitando que el bot parezca un contestador automático repetitivo (< 200 líneas).

part of 'pragmatic_fast_path.dart';

extension _CandidateSelector on PragmaticFastPath {
  ({String reply, List<String> suggestions}) _selectCandidate(
    List<String> pool,
    String conversationId,
    String? lastOutboundText,
  ) {
    if (pool.isEmpty) {
      return (
        reply: 'Todo bien por acá.',
        suggestions: const ['Todo bien por acá.'],
      );
    }

    // Obtener los últimos textos salientes de la memoria de esta conversación
    final mem = conversationId.isNotEmpty ? memoryFor?.call(conversationId) : null;
    final recentOutbound = <String>{};
    if (lastOutboundText != null && lastOutboundText.trim().isNotEmpty) {
      recentOutbound.add(lastOutboundText.trim().toLowerCase());
    }

    if (mem != null && mem.entries.isNotEmpty) {
      for (final entry in mem.entries.reversed) {
        if (entry.kind == ConversationMemoryEntryKind.outboundVerified ||
            entry.kind == ConversationMemoryEntryKind.outboundDispatched ||
            entry.kind == ConversationMemoryEntryKind.outboundObservedManual) {
          recentOutbound.add(entry.text.trim().toLowerCase());
          if (recentOutbound.length >= 3) break;
        }
      }
    }

    // Filtrar candidatos que hayan sido emitidos recientemente en esta conversación
    final available = pool.where((c) {
      final norm = c.trim().toLowerCase();
      return !recentOutbound.contains(norm);
    }).toList();

    final listToUse = available.isNotEmpty ? available : pool;

    // Semilla dinámica que rota por minuto Y por conteo de turnos para no repetir en el mismo minuto
    final minuteBucket = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    final turnOffset = mem?.entries.length ?? 0;
    final seed = (conversationId.hashCode ^ (minuteBucket + turnOffset)).abs();

    final selected = listToUse[seed % listToUse.length];
    final suggestions = <String>[selected];
    for (final c in pool) {
      if (!suggestions.contains(c) && suggestions.length < 3) {
        suggestions.add(c);
      }
    }

    return (reply: selected, suggestions: suggestions);
  }
}
